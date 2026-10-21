import XCTest
@testable import SousApp

/// The shade's state machine and its pull curve — the two pieces of the window
/// shade that are pure logic rather than gesture plumbing.
final class ShadePresentationTests: XCTestCase {

    // MARK: - Interactive open

    @MainActor func test_pullCommits_endsOpen() async {
        let shade = ShadePresentation()
        XCTAssertTrue(shade.isClosed)

        shade.beginOpening()
        shade.driveOpening(progress: 0.3)
        XCTAssertEqual(shade.progress, 0.3, accuracy: 0.0001)
        XCTAssertTrue(shade.isVisible)
        XCTAssertTrue(shade.isInteractive)

        shade.finishOpening(commit: true)
        XCTAssertTrue(shade.isOpen)
        XCTAssertEqual(shade.progress, 1)
    }

    @MainActor func test_pullCancels_endsClosed() async {
        let shade = ShadePresentation()
        shade.beginOpening()
        shade.driveOpening(progress: 0.4)
        shade.finishOpening(commit: false)
        XCTAssertTrue(shade.isClosed)
        XCTAssertEqual(shade.progress, 0)
    }

    @MainActor func test_driveClampsToUnitRange() async {
        let shade = ShadePresentation()
        shade.beginOpening()
        shade.driveOpening(progress: 4)
        XCTAssertEqual(shade.progress, 1)
        shade.driveOpening(progress: -2)
        XCTAssertEqual(shade.progress, 0)
    }

    /// A second gesture cannot restart an open shade — only a dismissal moves it.
    @MainActor func test_beginOpeningIsIgnoredWhileOpen() async {
        let shade = ShadePresentation()
        shade.open()
        shade.beginOpening()
        XCTAssertTrue(shade.isOpen)
    }

    // MARK: - Interactive close

    @MainActor func test_dismissCommits_endsClosed() async {
        let shade = ShadePresentation()
        shade.open()

        shade.beginClosing()
        shade.driveClosing(progress: 0.6)
        XCTAssertTrue(shade.isClosing)
        XCTAssertEqual(shade.progress, 0.6, accuracy: 0.0001)

        shade.finishClosing(commit: true)
        XCTAssertTrue(shade.isClosed)
    }

    @MainActor func test_dismissCancels_returnsToOpen() async {
        let shade = ShadePresentation()
        shade.open()
        shade.beginClosing()
        shade.driveClosing(progress: 0.8)
        shade.finishClosing(commit: false)
        XCTAssertTrue(shade.isOpen)
        XCTAssertEqual(shade.progress, 1)
    }

    @MainActor func test_driveClosingIsIgnoredUnlessClosing() async {
        let shade = ShadePresentation()
        shade.open()
        shade.driveClosing(progress: 0.2)
        XCTAssertEqual(shade.progress, 1)
    }

    // MARK: - Programmatic

    /// Choosing a recipe closes the shade first, then acts — the order the
    /// history drawer has always used.
    @MainActor func test_closeRunsCompletionAfterRetracting() async {
        let shade = ShadePresentation()
        shade.open()

        let acted = expectation(description: "completion runs")
        shade.close {
            XCTAssertTrue(shade.isClosed)
            acted.fulfill()
        }
        await fulfillment(of: [acted], timeout: 2)
    }

    @MainActor func test_closeOnAnAlreadyClosedShadeStillRunsItsCompletion() async {
        let shade = ShadePresentation()
        let acted = expectation(description: "completion runs")
        shade.close { acted.fulfill() }
        await fulfillment(of: [acted], timeout: 2)
    }

    // MARK: - The blank sheet while it is being pulled

    /// A pull should reveal one burgundy sheet, not a glimpse of the panel's own
    /// footer and hem stacked as two burgundy bars with a seam between them.
    @MainActor func test_aPullBlanksThePanelBeforeAnyOfItIsOnScreen() async {
        let shade = ShadePresentation()
        XCTAssertTrue(shade.showsContent)

        shade.beginOpening()
        XCTAssertFalse(shade.showsContent)
        shade.driveOpening(progress: 0.2)
        XCTAssertFalse(shade.showsContent)
    }

    @MainActor func test_committingAPullBringsTheContentBack() async {
        let shade = ShadePresentation()
        shade.beginOpening()
        shade.finishOpening(commit: true)
        XCTAssertTrue(shade.showsContent)
    }

    /// Cancelling leaves it blank, so the shade stays a plain sheet on the way back
    /// up rather than fading its contents in as it leaves.
    @MainActor func test_cancellingAPullLeavesTheSheetBlank() async {
        let shade = ShadePresentation()
        shade.beginOpening()
        shade.driveOpening(progress: 0.2)
        shade.finishOpening(commit: false)
        XCTAssertFalse(shade.showsContent)
    }

    /// A dismissal is the mirror image: the panel keeps its contents the whole way,
    /// which is why this cannot simply be derived from `phase` — `.closed` has to
    /// mean one thing after a cancelled pull and another after a dismissal.
    @MainActor func test_aDismissalKeepsTheContentAllTheWayOut() async {
        let shade = ShadePresentation()
        shade.open()
        shade.beginClosing()
        shade.driveClosing(progress: 0.3)
        XCTAssertTrue(shade.showsContent)
        shade.finishClosing(commit: true)
        XCTAssertTrue(shade.showsContent)
    }

    // MARK: - Who owns the bottom of the screen

    /// Regression. The bottom bar used to be torn down the instant a pull began,
    /// which also removed its ThumbDrop recognizer from the window — so a swipe
    /// down on the Talk to Sous bar, with the canvas at the top, did nothing at
    /// all. The bar only goes away once the shade is genuinely over it.
    @MainActor func test_anOpeningPullDoesNotTakeTheBottomBarAway() async {
        let shade = ShadePresentation()
        XCTAssertFalse(shade.coversBottomZone)

        shade.beginOpening()
        XCTAssertFalse(shade.coversBottomZone, "the shade is only at the top during a pull")
        shade.driveOpening(progress: 0.9)
        XCTAssertFalse(shade.coversBottomZone, "still only at the top, however far the pull got")

        shade.finishOpening(commit: false)
        XCTAssertFalse(shade.coversBottomZone)
    }

    @MainActor func test_theShadeOwnsTheBottomOnceItIsOpenAndWhileItRetracts() async {
        let shade = ShadePresentation()
        shade.open()
        XCTAssertTrue(shade.coversBottomZone)

        shade.beginClosing()
        XCTAssertTrue(shade.coversBottomZone, "still covering it on the way back up")
        shade.driveClosing(progress: 0.1)
        XCTAssertTrue(shade.coversBottomZone)

        shade.finishClosing(commit: true)
        XCTAssertFalse(shade.coversBottomZone)
    }

    // MARK: - The pull curve

    /// Two segments: the peek eases fully out over `peekAppearDistance`, then
    /// further pull is followed at `pullResistance`.
    @MainActor func test_peekIsFullyOutAtTheAppearDistance() async {
        let tuning = ShadeTuningValues()
        let peek: CGFloat = 145

        XCTAssertEqual(tuning.travel(forPull: 0, peekTravel: peek), 0, accuracy: 0.001)
        XCTAssertEqual(
            tuning.travel(forPull: tuning.peekAppearDistance, peekTravel: peek),
            peek, accuracy: 0.001
        )
    }

    @MainActor func test_pullBeyondThePeekIsResisted() async {
        let tuning = ShadeTuningValues()
        let peek: CGFloat = 145
        let extra: CGFloat = 100

        let travel = tuning.travel(forPull: tuning.peekAppearDistance + extra, peekTravel: peek)
        XCTAssertEqual(travel, peek + extra * tuning.pullResistance, accuracy: 0.001)
    }

    /// An upward drag must never push the shade above its rest position.
    @MainActor func test_upwardPullProducesNoTravel() async {
        let tuning = ShadeTuningValues()
        XCTAssertEqual(tuning.travel(forPull: -200, peekTravel: 145), 0, accuracy: 0.001)
    }

    @MainActor func test_travelIsMonotonic() async {
        let tuning = ShadeTuningValues()
        var previous: CGFloat = -1
        for pull in stride(from: CGFloat(0), through: 400, by: 5) {
            let travel = tuning.travel(forPull: pull, peekTravel: 145)
            XCTAssertGreaterThanOrEqual(travel, previous, "travel went backwards at \(pull)pt")
            previous = travel
        }
    }

    // MARK: - The bar pull's own distances

    /// The bottom bar's pull swaps in three shorter distances and nothing else —
    /// resistance, both springs and the dismiss values stay shared. If this drifts,
    /// the two entry points quietly stop feeling like the same gesture.
    @MainActor func test_forBarPullSwapsTheThreeDistancesAndLeavesTheRestAlone() async {
        let canvas = ShadeTuningValues()
        let bar = canvas.forBarPull

        XCTAssertEqual(bar.pullCommitDistance, canvas.barPullCommitDistance)
        XCTAssertEqual(bar.pullCommitVelocity, canvas.barPullCommitVelocity)
        XCTAssertEqual(bar.peekAppearDistance, canvas.barPeekAppearDistance)

        XCTAssertEqual(bar.pullResistance, canvas.pullResistance)
        XCTAssertEqual(bar.openResponse, canvas.openResponse)
        XCTAssertEqual(bar.openDamping, canvas.openDamping)
        XCTAssertEqual(bar.closeResponse, canvas.closeResponse)
        XCTAssertEqual(bar.closeDamping, canvas.closeDamping)
        XCTAssertEqual(bar.dismissZoneHeight, canvas.dismissZoneHeight)
        XCTAssertEqual(bar.dismissCommitDistance, canvas.dismissCommitDistance)
        XCTAssertEqual(bar.dismissCommitVelocity, canvas.dismissCommitVelocity)
    }

    /// A thumb starting on the bar has roughly 90pt of glass beneath it, so the
    /// gesture has to finish inside that. The canvas pull's distance does not.
    @MainActor func test_theBarPullFitsInTheRoomAThumbActuallyHas() async {
        let bar = ShadeTuningValues().forBarPull
        let roomBeneathTheBar: CGFloat = 90

        XCTAssertLessThan(bar.pullCommitDistance, roomBeneathTheBar)
        XCTAssertLessThan(bar.peekAppearDistance, bar.pullCommitDistance,
                          "the peek has to be readable before the pull can commit")
    }

    /// The peek is fully out at the appear distance for the bar too, however much
    /// faster it has to get there.
    @MainActor func test_theBarPeekIsFullyOutBeforeTheCommit() async {
        let bar = ShadeTuningValues().forBarPull
        let peek: CGFloat = 145

        XCTAssertEqual(bar.travel(forPull: bar.peekAppearDistance, peekTravel: peek),
                       peek, accuracy: 0.001)
        XCTAssertGreaterThan(bar.travel(forPull: bar.pullCommitDistance, peekTravel: peek), peek)
    }

    // MARK: - Tunables

    @MainActor func test_resetRestoresEveryDefault() async {
        let defaults = UserDefaults.standard
        for slider in ShadeTuning.sliders {
            defaults.set(slider.range.upperBound, forKey: slider.key)
        }
        ShadeTuning.resetToDefaults()
        for slider in ShadeTuning.sliders {
            XCTAssertNil(defaults.object(forKey: slider.key),
                         "\(slider.key) still has a stored value after reset")
        }
    }

    /// Every default has to sit inside the range its slider offers, or the slider
    /// silently clamps it the first time it is touched.
    @MainActor func test_everyDefaultSitsInsideItsSliderRange() async {
        for slider in ShadeTuning.sliders {
            XCTAssertTrue(slider.range.contains(slider.value),
                          "\(slider.key) default \(slider.value) is outside \(slider.range)")
        }
    }
}

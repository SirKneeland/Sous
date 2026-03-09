import XCTest
import SousCore
@testable import SousApp

// MARK: - PhotoSendStateTests
//
// Tests the PhotoSendState lifecycle and the consumption/reset contract.
// PhotoSendState lives in SousApp; these tests live in SousAppTests.

final class PhotoSendStateTests: XCTestCase {

    // MARK: - Test 1: Success lifecycle transitions, done consumed and reset to idle

    func test_successLifecycle_doneConsumedAndReset() {
        let outcome = MultimodalSendOutcome.success(
            .suggestionsOnly(assistantMessage: "Looks good!", suggestions: [])
        )

        var state: PhotoSendState = .idle
        XCTAssertEqual(state, .idle)

        state = .preparing
        XCTAssertEqual(state, .preparing)

        state = .sending
        XCTAssertEqual(state, .sending)

        state = .done(outcome)
        XCTAssertEqual(state, .done(outcome))

        // Consume once, then reset to idle per the consumption contract.
        var consumed: MultimodalSendOutcome? = nil
        if case .done(let o) = state {
            consumed = o
            state = .idle   // mandatory reset after dispatch
        }

        XCTAssertEqual(state, .idle)
        XCTAssertEqual(consumed, outcome)
    }

    // MARK: - Test 2: Failure lifecycle transitions, done consumed and reset to idle

    func test_failureLifecycle_doneConsumedAndReset() {
        let outcome = MultimodalSendOutcome.failure(.terminal(.auth))

        var state: PhotoSendState = .idle
        state = .preparing
        state = .sending
        state = .done(outcome)
        XCTAssertEqual(state, .done(outcome))

        var consumed: MultimodalSendOutcome? = nil
        if case .done(let o) = state {
            consumed = o
            state = .idle
        }

        XCTAssertEqual(state, .idle)
        XCTAssertEqual(consumed, outcome)
    }

    // MARK: - Test 3: done holds no image data (only MultimodalSendOutcome)

    func test_doneState_holdsNoImageData() {
        // .done only carries MultimodalSendOutcome — by type construction,
        // there is no ImageAsset or PreparedImage reference in the terminal state.
        let successOutcome = MultimodalSendOutcome.success(
            .suggestionsOnly(assistantMessage: "All clear.", suggestions: [])
        )
        let failureOutcome = MultimodalSendOutcome.failure(.retryable(.timeout))

        let successState = PhotoSendState.done(successOutcome)
        let failureState = PhotoSendState.done(failureOutcome)

        // Both done states carry only an outcome — no image bytes retained.
        if case .done(let o) = successState {
            XCTAssertEqual(o, successOutcome)
        } else {
            XCTFail("Expected .done")
        }

        if case .done(let o) = failureState {
            XCTAssertEqual(o, failureOutcome)
        } else {
            XCTFail("Expected .done")
        }
    }

    // MARK: - Test 4: Consuming done does not replay on second observation

    func test_doneIsConsumedOnce_noReplay() {
        let outcome = MultimodalSendOutcome.success(
            .patchProposal(
                assistantMessage: "Here's a suggestion.",
                patchSet: PatchSet(
                    baseRecipeId: UUID(),
                    baseRecipeVersion: 1,
                    patches: []
                )
            )
        )

        var state: PhotoSendState = .done(outcome)
        var dispatchCount = 0

        // First observation: consume and reset.
        if case .done = state {
            dispatchCount += 1
            state = .idle
        }

        // Second observation: state is now idle — no replay.
        if case .done = state {
            dispatchCount += 1
        }

        XCTAssertEqual(dispatchCount, 1, "outcome must be dispatched exactly once")
        XCTAssertEqual(state, .idle)
    }
}

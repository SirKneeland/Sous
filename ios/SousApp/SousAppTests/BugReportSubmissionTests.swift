import XCTest
@testable import SousApp

// MARK: - StubReportBackend

/// Records submissions and returns a canned result. Kept separate from MockBackend
/// so a test can make one send fail and the next succeed.
@MainActor
private final class StubReportBackend: DebugReportSubmitting {
    var result: Result<BugReportReceipt, Error> = .success(
        BugReportReceipt(id: "bug-uuid", seq: 1, status: "new", alreadySubmitted: false)
    )
    private(set) var submissions: [BugReportSubmission] = []

    func submitBugReport(_ report: BugReportSubmission) async throws -> BugReportReceipt {
        submissions.append(report)
        return try result.get()
    }
}

// MARK: - BugReportSubmissionTests

@MainActor
final class BugReportSubmissionTests: XCTestCase {

    private let diagnostic = "# Sous Debug Diagnostic\n\n## 6. Recipe State\n\nCarbonara"

    private func metadata() -> DebugReportMetadata {
        DebugReportMetadata(
            appVersion: "1.2.0",
            buildNumber: "142",
            iosVersion: "18.2",
            deviceModel: "iPhone16,1",
            appState: "cooking (recipe canvas active)"
        )
    }

    private func makeModel(
        backend: StubReportBackend
    ) -> DebugReportSheetModel {
        DebugReportSheetModel(diagnostic: diagnostic, metadata: metadata(), backend: backend)
    }

    // MARK: Validation

    func testCannotSendWithoutADescription() async {
        let backend = StubReportBackend()
        let model = makeModel(backend: backend)

        XCTAssertFalse(model.canSend, "an untouched sheet should not be sendable")

        model.description = "   \n  "
        XCTAssertFalse(model.canSend, "whitespace is not a bug report")

        model.description = "Steps reordered themselves"
        XCTAssertTrue(model.canSend)
    }

    func testSendDoesNothingWhileDescriptionIsEmpty() async {
        let backend = StubReportBackend()
        let model = makeModel(backend: backend)

        await model.send()

        XCTAssertTrue(backend.submissions.isEmpty, "an empty report must not reach the backend")
        XCTAssertEqual(model.sendState, .editing)
    }

    // MARK: Payload

    func testSubmissionCarriesDescriptionDiagnosticAndBuildMetadata() async {
        let backend = StubReportBackend()
        let model = makeModel(backend: backend)
        model.description = "  Steps reordered themselves after I accepted a patch  "
        model.expectedBehavior = "  Order should stay put  "

        await model.send()

        XCTAssertEqual(backend.submissions.count, 1)
        let sent = try? XCTUnwrap(backend.submissions.first)
        XCTAssertEqual(sent?.description, "Steps reordered themselves after I accepted a patch")
        XCTAssertEqual(sent?.expectedBehavior, "Order should stay put")
        XCTAssertEqual(sent?.diagnostic, diagnostic)
        XCTAssertEqual(sent?.appVersion, "1.2.0")
        XCTAssertEqual(sent?.buildNumber, "142")
        XCTAssertEqual(sent?.iosVersion, "18.2")
        XCTAssertEqual(sent?.deviceModel, "iPhone16,1")
        XCTAssertEqual(sent?.appState, "cooking (recipe canvas active)")
    }

    func testBlankExpectedBehaviorIsSentAsNilRatherThanEmptyString() async {
        let backend = StubReportBackend()
        let model = makeModel(backend: backend)
        model.description = "Import dropped the last ingredient"
        model.expectedBehavior = "   "

        await model.send()

        XCTAssertNil(backend.submissions.first?.expectedBehavior)
    }

    // MARK: Success

    func testSuccessfulSendReportsTheShortBugNumber() async {
        let backend = StubReportBackend()
        backend.result = .success(
            BugReportReceipt(id: "uuid", seq: 17, status: "new", alreadySubmitted: false)
        )
        let model = makeModel(backend: backend)
        model.description = "Mise en place group collapsed on its own"

        await model.send()

        XCTAssertEqual(model.sendState, .sent(seq: 17, alreadySubmitted: false))
    }

    func testAServerSideDuplicateIsReportedAsAlreadySubmitted() async {
        let backend = StubReportBackend()
        backend.result = .success(
            BugReportReceipt(id: "uuid", seq: 4, status: "triaged", alreadySubmitted: true)
        )
        let model = makeModel(backend: backend)
        model.description = "Same report, sent twice"

        await model.send()

        XCTAssertEqual(model.sendState, .sent(seq: 4, alreadySubmitted: true))
    }

    // MARK: Failure

    func testAFailedSendSurfacesAMessageAndLeavesTheReportRecoverable() async {
        let backend = StubReportBackend()
        backend.result = .failure(URLError(.notConnectedToInternet))
        let model = makeModel(backend: backend)
        model.description = "Patch banner never appeared"

        await model.send()

        guard case .failed(let message) = model.sendState else {
            return XCTFail("expected a failed state, got \(model.sendState)")
        }
        XCTAssertTrue(message.contains("Share file"), "the fallback must be offered: \(message)")
        // The typed text and the captured diagnostic survive, so Try Again and
        // Share File… both still work.
        XCTAssertEqual(model.description, "Patch banner never appeared")
        XCTAssertEqual(model.diagnostic, diagnostic)
        XCTAssertTrue(model.canSend, "a failed send must be retryable")
    }

    func testRetryAfterAFailureReusesTheSameReportId() async {
        let backend = StubReportBackend()
        backend.result = .failure(URLError(.timedOut))
        let model = makeModel(backend: backend)
        model.description = "Timer fired twice"

        await model.send()
        backend.result = .success(
            BugReportReceipt(id: "uuid", seq: 9, status: "new", alreadySubmitted: false)
        )
        await model.send()

        XCTAssertEqual(backend.submissions.count, 2)
        XCTAssertEqual(
            backend.submissions[0].clientReportId,
            backend.submissions[1].clientReportId,
            "a retry must reuse the id so the backend can dedupe it"
        )
        XCTAssertEqual(model.sendState, .sent(seq: 9, alreadySubmitted: false))
    }

    func testEachSheetGetsItsOwnReportId() async {
        let backend = StubReportBackend()

        let first = makeModel(backend: backend)
        first.description = "First problem"
        await first.send()

        let second = makeModel(backend: backend)
        second.description = "Unrelated second problem"
        await second.send()

        XCTAssertNotEqual(
            backend.submissions[0].clientReportId,
            backend.submissions[1].clientReportId,
            "two separate reports must not collapse into one"
        )
    }

    // MARK: Error messages

    func testErrorMessagesDistinguishWhatTheUserShouldDo() {
        XCTAssertTrue(
            DebugReportSheetModel.message(for: SousAPIError.notAuthenticated).contains("signed out")
        )
        XCTAssertTrue(
            DebugReportSheetModel.message(for: SousAPIError.http(status: 413)).contains("too large")
        )
        XCTAssertTrue(
            DebugReportSheetModel.message(for: SousAPIError.http(status: 429)).contains("Too many")
        )
    }

    // MARK: Metadata

    func testHardwareIdentifierIsMoreSpecificThanTheGenericModelName() {
        let identifier = DebugReportMetadata.hardwareIdentifier()
        XCTAssertFalse(identifier.isEmpty)
        XCTAssertNotEqual(identifier, "iPhone", "UIDevice.model is too coarse to be useful")
    }
}

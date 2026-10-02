import XCTest
import SousCore
@testable import SousApp

// MARK: - RetryOrchestrator

/// Records every request and returns results from a sequence, so a retry can be
/// asserted to have re-sent the *same* turn the first call carried.
private actor RetryOrchestrator: LLMOrchestrator {
    private let results: [LLMResult]
    private(set) var requests: [LLMRequest] = []
    private(set) var callCount = 0

    init(results: [LLMResult]) { self.results = results }

    func run(_ request: LLMRequest) async -> LLMResult {
        requests.append(request)
        let index = min(callCount, results.count - 1)
        callCount += 1
        return results[index]
    }
}

/// Suspends inside run(_:) so a retry can be attempted while a call is in flight.
private actor BlockingOrchestrator: LLMOrchestrator {
    private(set) var callCount = 0
    private var continuation: CheckedContinuation<LLMResult, Never>?

    func run(_ request: LLMRequest) async -> LLMResult {
        callCount += 1
        return await withCheckedContinuation { self.continuation = $0 }
    }

    func resume(with result: LLMResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

// MARK: - ChatRetryTests

/// Milestone 30: a failed turn is recoverable in one tap, and a wall is not
/// retried into a second time.
@MainActor
final class ChatRetryTests: XCTestCase {

    // MARK: Helpers

    private func debugBundle() -> LLMDebugBundle {
        LLMDebugBundle(
            status: .failed, attemptCount: 2, maxAttempts: 2,
            requestId: "test-fail", extractionUsed: false, repairUsed: false,
            timingTotalMs: 0
        )
    }

    private func failure(_ error: LLMError) -> LLMResult {
        .failure(
            fallbackPatchSet: nil,
            assistantMessage: ChatFailure.classify(error).message,
            raw: nil,
            debug: debugBundle(),
            error: error
        )
    }

    private func success() -> LLMResult {
        .noPatches(
            assistantMessage: "Olive oil works well here.",
            raw: nil,
            debug: LLMDebugBundle(
                status: .succeeded, attemptCount: 1, maxAttempts: 2,
                requestId: "test-ok", extractionUsed: false, repairUsed: false,
                timingTotalMs: 0
            ),
            proposedMemory: nil,
            suggestGenerate: nil
        )
    }

    private func drainMain() async {
        for _ in 0..<10 { await Task.yield() }
    }

    private func lastFailureMessage(_ store: AppStore) -> ChatMessage? {
        store.chatTranscript.last { $0.failure != nil }
    }

    // MARK: A transient failure offers RETRY, carrying the original turn

    func test_transientFailure_attachesRetryableRecordWithOriginalText() async {
        let mock = RetryOrchestrator(results: [failure(.network)])
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("Can I swap the butter for olive oil?")
        await drainMain()

        guard let message = lastFailureMessage(store), let record = message.failure else {
            return XCTFail("Failed turn must attach a failure record")
        }
        XCTAssertTrue(record.canRetry, "A dropped connection is worth retrying")
        XCTAssertEqual(record.retry?.userText, "Can I swap the butter for olive oil?",
                       "RETRY must re-send what the user actually asked")
        XCTAssertEqual(message.text, ChatFailure.classify(.network).message)
    }

    // MARK: A wall offers no RETRY

    func test_capReached_isAWallWithNoRetry() async {
        let mock = RetryOrchestrator(results: [failure(.capReached)])
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("Make me a risotto")
        await drainMain()

        guard let record = lastFailureMessage(store)?.failure else {
            return XCTFail("Failed turn must attach a failure record")
        }
        XCTAssertFalse(record.canRetry, "A 402 must not offer a retry into the same wall")
        XCTAssertEqual(record.failure.wall, .cap)
    }

    func test_wallTap_requestsBillingRatherThanResending() async {
        let mock = RetryOrchestrator(results: [failure(.capReached)])
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("Make me a risotto")
        await drainMain()

        store.handleFailureWallTap(.cap)
        XCTAssertTrue(store.billingWallRequested)

        let calls = await mock.callCount
        XCTAssertEqual(calls, 1, "Tapping a wall CTA must not fire another LLM call")
    }

    // MARK: Retry re-sends the same turn

    func test_retry_removesFailureBubbleAndResendsSameText() async {
        let mock = RetryOrchestrator(results: [failure(.network), success()])
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("Can I swap the butter for olive oil?")
        await drainMain()
        guard let failedID = lastFailureMessage(store)?.id else {
            return XCTFail("Expected a failed turn")
        }

        store.retryFailedTurn(messageID: failedID)
        await drainMain()

        XCTAssertNil(lastFailureMessage(store), "The failure bubble is replaced, not stacked")
        XCTAssertEqual(store.chatTranscript.last?.text, "Olive oil works well here.")

        let requests = await mock.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[1].userMessage.contains("Can I swap the butter for olive oil?"),
                      "The retry must carry the original turn, not a rebuilt approximation")

        // Exactly one user bubble: the retry reuses the existing one.
        let userBubbles = store.chatTranscript.filter { $0.role == .user }
        XCTAssertEqual(userBubbles.count, 1)
    }

    func test_retry_isBlockedWhileAnotherCallIsInFlight() async {
        let failing = RetryOrchestrator(results: [failure(.network)])
        let store = AppStore(testOrchestrator: failing)
        store.sendUserMessage("first")
        await drainMain()
        guard let failedID = lastFailureMessage(store)?.id else {
            return XCTFail("Expected a failed turn")
        }

        // A new send occupies the single flight slot; the retry must not jump it.
        store.sendUserMessage("second")
        store.retryFailedTurn(messageID: failedID)

        XCTAssertEqual(store.llmDebugStatus, "blocked_inflight_llm")
        XCTAssertNotNil(lastFailureMessage(store),
                        "A blocked retry must leave the failure bubble in place")
        await drainMain()
    }

    func test_retry_onANonRetryableFailureDoesNothing() async {
        let mock = RetryOrchestrator(results: [failure(.capReached)])
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("Make me a risotto")
        await drainMain()
        guard let failedID = lastFailureMessage(store)?.id else {
            return XCTFail("Expected a failed turn")
        }

        store.retryFailedTurn(messageID: failedID)
        await drainMain()

        XCTAssertNotNil(lastFailureMessage(store))
        let calls = await mock.callCount
        XCTAssertEqual(calls, 1)
    }

    // MARK: Failure chrome never reaches the model

    func test_failureBubblesAreExcludedFromConversationHistory() async {
        let mock = RetryOrchestrator(results: [failure(.network), success()])
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("Can I swap the butter for olive oil?")
        await drainMain()

        let history = store.buildConversationHistory(dropLastEntry: false)
        let errorCopy = ChatFailure.classify(.network).message
        XCTAssertFalse(history.contains { $0.content == errorCopy },
                       "Replaying error chrome would teach the model to apologise")
        XCTAssertTrue(history.contains { $0.content.contains("olive oil") })
    }

    // MARK: The offer survives a relaunch

    func test_failureRecordRoundTripsThroughPersistence() throws {
        let record = ChatFailureRecord(
            failure: ChatFailure.classify(.timeout),
            retry: ChatFailureRecord.RetryPayload(
                userText: "double the garlic",
                referencedItem: ReferencedItem(type: .ingredient, text: "2 cloves garlic"),
                isNewRecipe: false
            )
        )
        let message = ChatMessage(role: .assistant, text: "That took too long.", failure: record)

        let data = try JSONEncoder().encode([message])
        let decoded = try JSONDecoder().decode([ChatMessage].self, from: data)

        XCTAssertEqual(decoded.first?.failure, record)
        XCTAssertEqual(decoded.first?.failure?.retry?.referencedItem?.text, "2 cloves garlic")
    }

    func test_messagesWrittenBeforeMilestone30StillDecode() throws {
        // A transcript entry from an older snapshot has no `failure` key at all.
        let legacy = """
        [{"id":"\(UUID().uuidString)","role":"assistant","text":"Hello","timestamp":0}]
        """
        let decoded = try JSONDecoder().decode([ChatMessage].self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.first?.text, "Hello")
        XCTAssertNil(decoded.first?.failure)
    }
}

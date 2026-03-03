import XCTest
import SousCore
@testable import SousApp

// MARK: - ControlledOrchestrator

/// Actor-based mock that suspends inside run(_:) until resume(with:) is called.
/// Enables tests to assert state while an LLM call is "in flight".
private actor ControlledOrchestrator: LLMOrchestrator {
    private(set) var callCount = 0
    private var continuation: CheckedContinuation<LLMResult, Never>?

    func run(_ request: LLMRequest) async -> LLMResult {
        callCount += 1
        return await withCheckedContinuation { cont in
            continuation = cont
        }
    }

    func resume(with result: LLMResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

// MARK: - SyncOrchestrator

/// Actor-based mock that immediately returns a fixed LLMResult (no suspension needed by tests).
private actor SyncOrchestrator: LLMOrchestrator {
    let fixedResult: LLMResult
    init(result: LLMResult) { fixedResult = result }
    func run(_ request: LLMRequest) async -> LLMResult { fixedResult }
}

// MARK: - Helpers

private extension AppStoreTests {

    func minimalDebug() -> LLMDebugBundle {
        LLMDebugBundle(
            status: .succeeded,
            attemptCount: 1, maxAttempts: 2,
            requestId: "test",
            extractionUsed: false, repairUsed: false,
            timingTotalMs: 0
        )
    }

    /// A valid PatchSet targeting the AppStore seed recipe at version 1.
    func seedPatchSet() -> PatchSet {
        PatchSet(
            baseRecipeId: AppStore.recipeId,
            baseRecipeVersion: 1,
            patches: [.addNote(text: "test note")]
        )
    }

    func validResult(patchSet: PatchSet) -> LLMResult {
        .valid(patchSet: patchSet, assistantMessage: "Done.", raw: nil, debug: minimalDebug())
    }

    /// Yields to the MainActor scheduler multiple times so enqueued tasks can complete.
    func drainMain() async {
        for _ in 0..<5 { await Task.yield() }
    }
}

// MARK: - AppStoreTests

@MainActor
final class AppStoreTests: XCTestCase {

    // MARK: (a) Single-flight: second send is blocked while first is in flight

    func test_singleFlight_blocksSecondCall() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)

        // First send: llmTask is set synchronously before the task body runs.
        store.sendUserMessage("first")
        // Second send on the same MainActor turn: llmTask is already non-nil → blocked.
        store.sendUserMessage("second")

        XCTAssertEqual(store.llmDebugStatus, "blocked_inflight_llm",
                       "Second send must be blocked while first is in flight")

        // Allow the first task to start and reach await orchestrator.run.
        await Task.yield()
        let count = await mock.callCount
        XCTAssertEqual(count, 1, "Orchestrator must be called exactly once")

        // Drain: resume the mock to prevent a leaked continuation, then let the task clean up.
        await mock.resume(with: validResult(patchSet: seedPatchSet()))
        await drainMain()
    }

    // MARK: (b) Cancellation: task cancelled before result; state must not change

    func test_cancellation_preventsStateUpdates() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)
        let initialTranscriptCount = store.chatTranscript.count

        store.sendUserMessage("hello")              // starts task; user bubble appended
        await Task.yield()                          // task reaches await orchestrator.run

        store.cancelLiveLLM()                       // cancel + clear llmTask reference
        await mock.resume(with: validResult(patchSet: seedPatchSet())) // unblock the awaiting task
        await drainMain()                           // task resumes, sees isCancelled, returns

        XCTAssertEqual(store.llmDebugStatus, "cancelled")
        XCTAssertFalse(store.uiState.isPatchProposed, "No patch must be proposed after cancellation")
        XCTAssertFalse(store.uiState.isPatchReview,   "No patch review must open after cancellation")
        // Only the user bubble was appended; the assistant message must NOT appear.
        XCTAssertEqual(store.chatTranscript.count, initialTranscriptCount + 1,
                       "Only the user bubble should have been added; no assistant message after cancel")
    }

    // MARK: (c) Stale version: expired handling — must not enter patch review

    func test_staleVersion_expiredHandling() async {
        let stalePatchSet = PatchSet(
            baseRecipeId: AppStore.recipeId,
            baseRecipeVersion: 99,          // store recipe is at version 1
            patches: [.addNote(text: "stale")]
        )
        let mock = SyncOrchestrator(result: validResult(patchSet: stalePatchSet))
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("make it better")
        await drainMain()

        XCTAssertEqual(store.llmDebugStatus, "expired_recipeVersionMismatch",
                       "Stale version must produce expired status")
        XCTAssertFalse(store.uiState.isPatchProposed,
                       "Stale version must not enter patch review")
    }

    // MARK: (d) Stale recipeId: fatal handling — must not enter patch review

    func test_staleRecipeId_fatalHandling() async {
        let wrongId = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000000")!
        let stalePatchSet = PatchSet(
            baseRecipeId: wrongId,          // does not match store's recipeId
            baseRecipeVersion: 1,
            patches: [.addNote(text: "wrong recipe")]
        )
        let mock = SyncOrchestrator(result: validResult(patchSet: stalePatchSet))
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("make it better")
        await drainMain()

        XCTAssertEqual(store.llmDebugStatus, "fatal_recipeIdMismatch",
                       "Wrong recipeId must produce fatal status")
        XCTAssertFalse(store.uiState.isPatchProposed,
                       "Wrong recipeId must not enter patch review")
    }
}

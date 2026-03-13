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

// MARK: - CapturingOrchestrator

/// Actor-based mock that records every LLMRequest it receives and returns results from a
/// pre-configured sequence (last result repeats if exhausted). Used to assert on what
/// context the store passes to the orchestrator without exposing private AppStore state.
private actor CapturingOrchestrator: LLMOrchestrator {
    private let results: [LLMResult]
    private(set) var requests: [LLMRequest] = []
    private(set) var callCount = 0

    init(results: [LLMResult]) { self.results = results }
    init(result: LLMResult)    { self.results = [result] }

    func run(_ request: LLMRequest) async -> LLMResult {
        requests.append(request)
        let idx = min(callCount, results.count - 1)
        callCount += 1
        return results[idx]
    }
}

// MARK: - Helpers

private extension AppStoreTests {

    func makeMultimodalRequest() throws -> MultimodalLLMRequest {
        let imageData = Data([0xFF, 0xD8, 0xFF])
        let image = try PreparedImage(
            data: imageData, mimeType: "image/jpeg",
            widthPx: 100, heightPx: 100, originalByteCount: 3
        )
        // base values other than userMessage are rebuilt by AppStore.sendWithMultimodalLLM.
        let base = LLMRequest(
            recipeId: AppStore.recipeId.uuidString,
            recipeVersion: 1,
            hasCanvas: true,
            userMessage: "Does this look done?",
            recipeSnapshotForPrompt: Recipe(title: "placeholder"),
            userPrefs: LLMUserPrefs(hardAvoids: [])
        )
        return MultimodalLLMRequest(base: base, image: image)
    }

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
        .valid(patchSet: patchSet, assistantMessage: "Done.", raw: nil, debug: minimalDebug(), proposedMemory: nil)
    }

    func noPatchesResult() -> LLMResult {
        .noPatches(assistantMessage: "Clarification needed: please elaborate.", raw: nil, debug: minimalDebug(), proposedMemory: nil)
    }

    func failureDebug() -> LLMDebugBundle {
        LLMDebugBundle(
            status: .failed,
            attemptCount: 2, maxAttempts: 2,
            requestId: "test-fail",
            extractionUsed: false, repairUsed: true,
            timingTotalMs: 0
        )
    }

    func failureResult(fallbackPatchSet: PatchSet? = nil) -> LLMResult {
        .failure(
            fallbackPatchSet: fallbackPatchSet,
            assistantMessage: "Something went wrong. Please try again.",
            raw: nil,
            debug: failureDebug(),
            error: .schemaInvalid
        )
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
        // drainMain (5 yields) is required here: a single yield is not reliably enough for
        // the LLM task to start on the main actor, hop to the orchestrator's actor executor,
        // and execute callCount += 1 before the assertion runs.
        await drainMain()
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

    // MARK: (e) Valid PatchSet → no recipe mutation until Accept

    func test_validPatch_noMutationUntilAccept() async {
        let mock = SyncOrchestrator(result: validResult(patchSet: seedPatchSet()))
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        // Establish chatOpen (patchReceived is only handled from chatOpen state)
        store.send(.openChat)

        store.sendUserMessage("add a note")
        await drainMain()

        // Must be in patchReview (auto-advanced from patchProposed); recipe not yet mutated
        XCTAssertTrue(store.uiState.isPatchReview, "Must be in patchReview after valid LLM result (auto-advanced)")
        XCTAssertEqual(store.uiState.recipe, original, "Recipe must not change before Accept")

        // validatePatch is now a no-op (already in patchReview); recipe still unchanged
        store.send(.validatePatch)
        XCTAssertTrue(store.uiState.isPatchReview, "Must remain in patchReview")
        XCTAssertEqual(store.uiState.recipe, original, "Recipe must not change during patchReview")

        // Accept → recipe mutates deterministically
        store.send(.acceptPatch)
        let updated = store.uiState.recipe
        XCTAssertEqual(updated.version, original.version + 1,
                       "Recipe version must increment exactly once on Accept")
        XCTAssertTrue(updated.notes.contains("test note"),
                      "Patch note must be present after Accept")
        XCTAssertTrue(updated.notes.contains("Original family recipe"),
                      "Original note must be preserved after Accept")
    }

    // MARK: (f) Reject → no recipe mutation ever

    func test_reject_noMutation() async {
        let mock = SyncOrchestrator(result: validResult(patchSet: seedPatchSet()))
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        store.send(.openChat)
        store.sendUserMessage("add a note")
        await drainMain()

        store.send(.validatePatch)
        store.send(.rejectPatch(userText: "nope"))

        XCTAssertEqual(store.uiState.recipe, original,
                       "Recipe must be identical to original after Reject")
        XCTAssertFalse(store.uiState.isPatchProposed, "No pending patch after Reject")
        XCTAssertFalse(store.uiState.isPatchReview,   "No patch review after Reject")
    }

    // MARK: (g) Expired (stale version) → no recipe mutation ever

    func test_staleVersion_recipeUnchanged() async {
        let stalePatchSet = PatchSet(
            baseRecipeId: AppStore.recipeId,
            baseRecipeVersion: 99,
            patches: [.addNote(text: "stale")]
        )
        let mock = SyncOrchestrator(result: validResult(patchSet: stalePatchSet))
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        store.send(.openChat)
        store.sendUserMessage("make it better")
        await drainMain()

        XCTAssertEqual(store.llmDebugStatus, "expired_recipeVersionMismatch")
        XCTAssertEqual(store.uiState.recipe, original,
                       "Recipe must be unchanged after expired version mismatch")
    }

    // MARK: (h) Fatal recipeId mismatch → no recipe mutation ever

    func test_fatalIdMismatch_recipeUnchanged() async {
        let wrongId = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000000")!
        let mismatchedPatchSet = PatchSet(
            baseRecipeId: wrongId,
            baseRecipeVersion: 1,
            patches: [.addNote(text: "wrong recipe")]
        )
        let mock = SyncOrchestrator(result: validResult(patchSet: mismatchedPatchSet))
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        store.send(.openChat)
        store.sendUserMessage("make it better")
        await drainMain()

        XCTAssertEqual(store.llmDebugStatus, "fatal_recipeIdMismatch")
        XCTAssertEqual(store.uiState.recipe, original,
                       "Recipe must be unchanged after fatal recipeId mismatch")
    }

    // MARK: (i) noPatches → assistant message appended, chatOpen state, no patch flow

    func test_noPatches_appendsAssistantMessage_noPatchFlow() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let store = AppStore(testOrchestrator: mock)
        let initialCount = store.chatTranscript.count

        store.send(.openChat)
        store.sendUserMessage("what temperature?")
        await drainMain()

        // Exact state: chatOpen, no patch states entered
        if case .chatOpen = store.uiState {} else {
            XCTFail("Expected chatOpen after noPatches, got \(store.uiState)")
        }
        XCTAssertFalse(store.uiState.isPatchProposed, "noPatches must not enter patchProposed")
        XCTAssertFalse(store.uiState.isPatchReview,   "noPatches must not enter patchReview")
        // +2: user bubble + assistant reply
        XCTAssertEqual(store.chatTranscript.count, initialCount + 2,
                       "Transcript must grow by exactly 2 (user bubble + assistant reply)")
        XCTAssertEqual(store.llmDebugStatus, "succeeded")
    }

    // MARK: (j) noPatches clears nextLLMContext — asserted via captured third request

    func test_noPatches_clearsNextLLMContext() async {
        // Call 1 (.valid): seed nextLLMContext by driving through reject
        // Call 2 (.noPatches): must carry the prior reject context, then clear it
        // Call 3: captured request must have nextLLMContext == nil
        let mock = CapturingOrchestrator(results: [
            validResult(patchSet: seedPatchSet()),
            noPatchesResult(),
            noPatchesResult(),
        ])
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        // Seed nextLLMContext via reject flow (call 1)
        store.send(.openChat)
        store.sendUserMessage("add a note")
        await drainMain()
        store.send(.validatePatch)
        store.send(.rejectPatch(userText: "nope"))   // populates nextLLMContext

        // noPatches call — should include the prior reject context (call 2)
        store.sendUserMessage("never mind")
        await drainMain()

        // Third send — captured request must carry nil nextLLMContext (call 3)
        store.sendUserMessage("what else?")
        await drainMain()

        let requests = await mock.requests
        XCTAssertEqual(requests.count, 3, "Expected exactly 3 LLM calls")
        XCTAssertNotNil(requests[1].nextLLMContext,
                        "Call 2 (noPatches) must carry the prior reject context")
        XCTAssertNil(requests[2].nextLLMContext,
                     "Call 3 must have nil nextLLMContext — noPatches cleared it")
        XCTAssertEqual(store.uiState.recipe, original, "Recipe must be unchanged throughout")
    }

    // MARK: (k) noPatches does not block future sends

    func test_noPatches_doesNotBlockFutureSends() async {
        let mock = CapturingOrchestrator(result: noPatchesResult())
        let store = AppStore(testOrchestrator: mock)
        let initialCount = store.chatTranscript.count

        store.send(.openChat)
        store.sendUserMessage("first")
        await drainMain()
        store.sendUserMessage("second")
        await drainMain()

        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 2, "Orchestrator must be called exactly twice")
        // +4: user1, assistant1, user2, assistant2
        XCTAssertEqual(store.chatTranscript.count, initialCount + 4,
                       "Transcript must reflect both successful sends (+4)")
        XCTAssertEqual(store.llmDebugStatus, "succeeded")
        XCTAssertFalse(store.uiState.isPatchProposed)
        XCTAssertFalse(store.uiState.isPatchReview)
    }

    // MARK: (l) noPatches + existing recipe leaves recipe byte-for-byte unchanged

    func test_noPatches_recipeByteForByteUnchanged() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        store.send(.openChat)
        store.sendUserMessage("just a question")
        await drainMain()

        XCTAssertEqual(store.uiState.recipe, original,
                       "Recipe must be byte-for-byte unchanged after noPatches")
        XCTAssertEqual(store.uiState.recipe.version, original.version,
                       "Recipe version must not increment")
        XCTAssertFalse(store.uiState.isPatchProposed)
        XCTAssertFalse(store.uiState.isPatchReview)
        if case .chatOpen = store.uiState {} else {
            XCTFail("Expected chatOpen after noPatches, got \(store.uiState)")
        }
    }

    // MARK: (m) repair exhaustion (failure, no fallback) → no mutation, no patch flow

    func test_failure_noMutation_noPatchFlow() async {
        let mock = SyncOrchestrator(result: failureResult(fallbackPatchSet: nil))
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe
        let initialCount = store.chatTranscript.count

        store.send(.openChat)
        store.sendUserMessage("make it spicy")
        await drainMain()

        XCTAssertEqual(store.uiState.recipe, original,
                       "Recipe must not mutate after LLM failure with no fallback")
        XCTAssertFalse(store.uiState.isPatchProposed,
                       "Failure with no fallback must not enter patchProposed")
        XCTAssertFalse(store.uiState.isPatchReview,
                       "Failure with no fallback must not enter patchReview")
        // +2: user bubble + assistant failure message
        XCTAssertEqual(store.chatTranscript.count, initialCount + 2,
                       "Transcript must grow by 2 (user + assistant failure message)")
        XCTAssertEqual(store.llmDebugStatus, "failed",
                       "llmDebugStatus must be 'failed' after exhaustion")
    }

    // MARK: (n) failure with fallbackPatchSet → recipe does not mutate before Accept

    func test_failureWithFallback_noMutationUntilAccept() async {
        let mock = SyncOrchestrator(result: failureResult(fallbackPatchSet: seedPatchSet()))
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        store.send(.openChat)
        store.sendUserMessage("make it spicy")
        await drainMain()

        // Fallback patch auto-advances to patchReview — recipe still unchanged
        XCTAssertEqual(store.uiState.recipe, original,
                       "Recipe must not mutate before Accept even with fallbackPatchSet")
        XCTAssertTrue(store.uiState.isPatchReview,
                      "Fallback patchSet must auto-advance to patchReview")
        XCTAssertEqual(store.llmDebugStatus, "failed")

        // Accept → recipe mutates (validatePatch is a no-op, already in patchReview)
        store.send(.validatePatch)
        store.send(.acceptPatch)
        let updated = store.uiState.recipe
        XCTAssertEqual(updated.version, original.version + 1,
                       "Recipe version must increment exactly once on Accept")
        XCTAssertTrue(updated.notes.contains("test note"),
                      "Fallback patch note must be present after Accept")
    }

    // MARK: (m9-a) multimodal send dispatches to orchestrator and returns result

    func test_multimodalSend_dispatchesOrchestrator_andHandlesResult() async throws {
        let mock = CapturingOrchestrator(result: noPatchesResult())
        let store = AppStore(testOrchestrator: mock)
        let initialCount = store.chatTranscript.count

        store.send(.openChat)
        let req = try makeMultimodalRequest()
        store.sendMultimodalRequest(req)
        await drainMain()

        let count = await mock.callCount
        XCTAssertEqual(count, 1, "Orchestrator must be called exactly once for multimodal send")
        XCTAssertEqual(store.llmDebugStatus, "succeeded")
        // noPatches → assistant message appended
        XCTAssertEqual(store.chatTranscript.count, initialCount + 1,
                       "One assistant message must be appended after noPatches multimodal result")
    }

    // MARK: (m9-b) multimodal send blocked while a text LLM call is in flight

    func test_multimodalSend_blockedWhileTextLLMInFlight() async throws {
        let textMock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: textMock)

        store.sendUserMessage("first")  // starts text LLM task
        let req = try makeMultimodalRequest()
        store.sendMultimodalRequest(req)

        XCTAssertEqual(store.llmDebugStatus, "blocked_inflight_llm",
                       "Multimodal send must be blocked while text LLM is in flight")

        // Drain: resume the controlled mock to avoid a leaked continuation.
        await textMock.resume(with: noPatchesResult())
        await drainMain()
    }

    // MARK: (m9-c) multimodal send blocked when patch is pending

    func test_multimodalSend_blockedIfPatchPending() async throws {
        let mock = CapturingOrchestrator(result: validResult(patchSet: seedPatchSet()))
        let store = AppStore(testOrchestrator: mock)

        store.send(.openChat)
        store.sendUserMessage("add a note")
        await drainMain()
        XCTAssertTrue(store.uiState.isPatchReview, "Pre-condition: must be in patchReview (auto-advanced)")

        let callCountBefore = await mock.callCount
        let req = try makeMultimodalRequest()
        store.sendMultimodalRequest(req)
        await drainMain()

        let callCountAfter = await mock.callCount
        XCTAssertEqual(callCountAfter, callCountBefore,
                       "No additional orchestrator call must be made when a patch is pending")
        XCTAssertTrue(store.uiState.isPatchReview,
                      "State must remain patchReview after a blocked multimodal send")
    }

    // MARK: (m9-d) multimodal valid patch — no mutation before Accept

    func test_multimodalSend_validPatch_noMutationUntilAccept() async throws {
        let mock = SyncOrchestrator(result: validResult(patchSet: seedPatchSet()))
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        store.send(.openChat)
        let req = try makeMultimodalRequest()
        store.sendMultimodalRequest(req)
        await drainMain()

        XCTAssertTrue(store.uiState.isPatchReview,
                      "Valid multimodal result must auto-advance to patchReview")
        XCTAssertEqual(store.uiState.recipe, original,
                       "Recipe must not change before Accept")

        store.send(.validatePatch)  // no-op (already in patchReview)
        store.send(.acceptPatch)
        let updated = store.uiState.recipe
        XCTAssertEqual(updated.version, original.version + 1,
                       "Recipe version must increment after Accept")
        XCTAssertTrue(updated.notes.contains("test note"),
                      "Patch note must be applied after Accept")
    }

    // MARK: (o) repeated failure does not block future sends

    func test_failure_doesNotBlockFutureSends() async {
        let mock = CapturingOrchestrator(results: [
            failureResult(fallbackPatchSet: nil),
            noPatchesResult(),
        ])
        let store = AppStore(testOrchestrator: mock)
        let initialCount = store.chatTranscript.count

        store.send(.openChat)
        store.sendUserMessage("first")
        await drainMain()

        XCTAssertEqual(store.llmDebugStatus, "failed")
        // Second send must not be blocked by stale failed state
        store.sendUserMessage("second")
        await drainMain()

        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 2, "Orchestrator must be called exactly twice")
        // +4: user1, assistant1(failure), user2, assistant2(noPatches)
        XCTAssertEqual(store.chatTranscript.count, initialCount + 4,
                       "Transcript must reflect both sends (+4 entries)")
        XCTAssertEqual(store.llmDebugStatus, "succeeded")
    }

    // MARK: (m11-a) startNewSession transitions to blank state

    func test_m11a_startNewSession_clearsToBlankState() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)

        // Pre-condition: test mode starts with hasCanvas = true and seed data
        XCTAssertTrue(store.hasCanvas, "Pre-condition: hasCanvas must be true in test mode")

        store.startNewSession()

        XCTAssertFalse(store.hasCanvas, "hasCanvas must be false after startNewSession")
        XCTAssertTrue(store.chatTranscript.isEmpty, "Chat transcript must be empty after startNewSession")
        if case .chatOpen = store.uiState {} else {
            XCTFail("Expected chatOpen state after startNewSession, got \(store.uiState)")
        }
        XCTAssertNotEqual(store.uiState.recipe.id, AppStore.recipeId,
                          "Blank recipe must have a new UUID, not the seed recipe ID")

        // Cleanup: resume the controlled mock to avoid a leaked continuation
        await mock.resume(with: noPatchesResult())
    }

    // MARK: (m11-b) LLM request in blank state uses hasCanvas = false

    func test_m11b_blankState_LLMRequest_hasCanvasFalse() async {
        let capturer = CapturingOrchestrator(result: noPatchesResult())
        let store = AppStore(testOrchestrator: capturer)
        store.startNewSession()

        store.sendUserMessage("I want to cook something Italian")
        await drainMain()

        let requests = await capturer.requests
        XCTAssertFalse(requests.isEmpty, "Expected at least one LLM call")
        XCTAssertFalse(requests[0].hasCanvas,
                       "LLM request in blank state must have hasCanvas == false")
    }

    // MARK: (m11-c) accepting first recipe from blank state sets hasCanvas = true

    func test_m11c_acceptFirstRecipe_setsHasCanvas() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)
        store.startNewSession()

        XCTAssertFalse(store.hasCanvas, "Pre-condition: must be false after startNewSession")

        let blankRecipe = store.uiState.recipe
        let ps = PatchSet(
            baseRecipeId: blankRecipe.id,
            baseRecipeVersion: blankRecipe.version,
            patches: [.setTitle("Pasta Carbonara"), .addNote(text: "created")]
        )
        store.send(.patchReceived(ps))
        store.send(.validatePatch)
        store.send(.acceptPatch)

        XCTAssertTrue(store.hasCanvas,
                      "hasCanvas must be true after accepting the first recipe")
        XCTAssertFalse(store.uiState.isPatchProposed, "No pending patch after Accept")
        XCTAssertFalse(store.uiState.isPatchReview, "No patch review after Accept")
        if case .recipeOnly(let r) = store.uiState {
            XCTAssertEqual(r.title, "Pasta Carbonara", "setTitle patch must be applied")
        } else {
            XCTFail("Expected recipeOnly after Accept, got \(store.uiState)")
        }
    }

    // MARK: (p) failure does not clear nextLLMContext — preserved for next call

    func test_failure_preservesNextLLMContext() async {
        let mock = CapturingOrchestrator(results: [
            validResult(patchSet: seedPatchSet()),   // call 1: seed nextLLMContext via reject
            failureResult(fallbackPatchSet: nil),    // call 2: failure must NOT clear context
            noPatchesResult(),                       // call 3: must receive preserved context
        ])
        let store = AppStore(testOrchestrator: mock)
        let original = store.uiState.recipe

        // Call 1: valid → reject → seeds nextLLMContext
        store.send(.openChat)
        store.sendUserMessage("first")
        await drainMain()
        store.send(.validatePatch)
        store.send(.rejectPatch(userText: "no thanks"))

        // Call 2: failure(nil) — nextLLMContext must survive
        store.sendUserMessage("second")
        await drainMain()
        XCTAssertEqual(store.llmDebugStatus, "failed")

        // Call 3: noPatches — request must still carry the reject context
        store.sendUserMessage("third")
        await drainMain()

        let requests = await mock.requests
        XCTAssertEqual(requests.count, 3, "Expected exactly 3 LLM calls")
        XCTAssertNotNil(requests[1].nextLLMContext,
                        "Call 2 (failure) must carry the prior reject context")
        XCTAssertNotNil(requests[2].nextLLMContext,
                        "Call 3 must still carry context — failure did not clear it")
        XCTAssertEqual(store.uiState.recipe, original, "Recipe must be unchanged throughout")
    }
}

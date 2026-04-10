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

// MARK: - MockMiseEnPlaceService

/// Synchronous mock that returns a fixed result for mise en place tests.
private struct MockMiseEnPlaceService: MiseEnPlaceServiceProtocol {
    private let result: Result<MiseEnPlaceResponse, Error>

    init(response: MiseEnPlaceResponse) { self.result = .success(response) }
    init(error: Error) { self.result = .failure(error) }

    func run(recipe: Recipe, apiKey: String) async throws -> MiseEnPlaceResponse {
        try result.get()
    }
}

// MARK: - DynamicImportOrchestrator

/// Actor-based mock that generates a valid import PatchSet matching whatever recipe ID/version
/// the store passes in. Used to test the import flow without hardcoding a recipe UUID.
private actor DynamicImportOrchestrator: LLMOrchestrator {
    private(set) var requests: [LLMRequest] = []

    func run(_ request: LLMRequest) async -> LLMResult {
        requests.append(request)
        let recipeId = UUID(uuidString: request.recipeId) ?? UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipeId,
            baseRecipeVersion: request.recipeVersion,
            patches: [
                .setTitle("Spaghetti Carbonara"),
                .addIngredient(text: "200g spaghetti", afterId: nil),
                .addIngredient(text: "100g guanciale", afterId: nil),
                .addStep(text: "Boil pasta until al dente", afterStepId: nil, preassignedId: nil),
                .addStep(text: "Fry guanciale until crispy", afterStepId: nil, preassignedId: nil),
            ]
        )
        return .valid(
            patchSet: patchSet,
            assistantMessage: "Got your Carbonara! What would you like to adapt?",
            raw: nil,
            debug: LLMDebugBundle(
                status: .succeeded,
                attemptCount: 1, maxAttempts: 3,
                requestId: "test-import",
                extractionUsed: false, repairUsed: false,
                timingTotalMs: 0
            ),
            proposedMemory: nil
        )
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
        .noPatches(assistantMessage: "Clarification needed: please elaborate.", raw: nil, debug: minimalDebug(), proposedMemory: nil, suggestGenerate: nil)
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
    /// M18 added two extra async hops per sendWithLLM (streamConsumer task creation +
    /// await streamConsumer.value), raising the minimum yield count from ~3 to ~6.
    /// 10 yields provides comfortable headroom without slowing the suite meaningfully.
    func drainMain() async {
        for _ in 0..<10 { await Task.yield() }
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

    // MARK: (m18-a) streamingAssistantMessage is nil before any send

    func test_m18a_streamingAssistantMessage_nilAtStart() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)

        XCTAssertNil(store.streamingAssistantMessage,
                     "streamingAssistantMessage must be nil before any LLM call")
    }

    // MARK: (m18-b) streamingAssistantMessage is nil after noPatches result

    func test_m18b_streamingAssistantMessage_nilAfterNoPatchesResult() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let store = AppStore(testOrchestrator: mock)

        store.send(.openChat)
        store.sendUserMessage("what temperature?")
        await drainMain()

        XCTAssertNil(store.streamingAssistantMessage,
                     "streamingAssistantMessage must be nil after LLM call completes")
    }

    // MARK: (m18-c) streamingAssistantMessage is nil after valid patch result

    func test_m18c_streamingAssistantMessage_nilAfterValidPatch() async {
        let mock = SyncOrchestrator(result: validResult(patchSet: seedPatchSet()))
        let store = AppStore(testOrchestrator: mock)

        store.send(.openChat)
        store.sendUserMessage("add a note")
        await drainMain()

        XCTAssertNil(store.streamingAssistantMessage,
                     "streamingAssistantMessage must be nil after patch result is processed")
    }

    // MARK: (m18-d) streamingAssistantMessage is nil after failure result

    func test_m18d_streamingAssistantMessage_nilAfterFailure() async {
        let mock = SyncOrchestrator(result: failureResult(fallbackPatchSet: nil))
        let store = AppStore(testOrchestrator: mock)

        store.send(.openChat)
        store.sendUserMessage("make it spicy")
        await drainMain()

        XCTAssertNil(store.streamingAssistantMessage,
                     "streamingAssistantMessage must be nil after failure result is processed")
    }

    // MARK: (m18-e) streamingAssistantMessage is nil after cancellation

    func test_m18e_streamingAssistantMessage_nilAfterCancellation() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)

        store.sendUserMessage("hello")
        await Task.yield()

        store.cancelLiveLLM()
        await mock.resume(with: noPatchesResult())
        await drainMain()

        XCTAssertNil(store.streamingAssistantMessage,
                     "streamingAssistantMessage must be nil after cancellation")
    }

    // MARK: (m21-a) import text success — canvas populated, hasCanvas true, one transcript message

    func test_m21a_importText_success_populatesCanvas() async {
        let capturer = DynamicImportOrchestrator()
        let store = AppStore(testOrchestrator: capturer)
        store.startNewSession()

        XCTAssertFalse(store.hasCanvas, "Pre-condition: blank state required")
        XCTAssertFalse(store.isShowingImportSheet, "Pre-condition: import sheet closed")

        store.isShowingImportSheet = true
        store.sendImportRequest(text: "Spaghetti Carbonara\n200g spaghetti\nBoil pasta")
        await drainMain()

        XCTAssertTrue(store.hasCanvas, "hasCanvas must be true after successful import")
        XCTAssertTrue(store.importSuccess, "importSuccess must be true — sheet handles dismissal after animation")
        XCTAssertNil(store.importError, "importError must be nil on success")
        XCTAssertEqual(store.llmDebugStatus, "succeeded")

        if case .recipeOnly(let r) = store.uiState {
            XCTAssertEqual(r.title, "Spaghetti Carbonara", "Extracted title must be applied")
            XCTAssertFalse(r.ingredients.isEmpty, "Extracted recipe must have ingredients")
            XCTAssertFalse(r.steps.isEmpty, "Extracted recipe must have steps")
        } else {
            XCTFail("Expected recipeOnly after import, got \(store.uiState)")
        }

        XCTAssertEqual(store.chatTranscript.count, 1,
                       "Transcript must contain exactly one message after import (AI welcome)")
        XCTAssertEqual(store.chatTranscript.first?.role, .assistant,
                       "First transcript message must be from the assistant")
    }

    // MARK: (m21-b) import text sends isImportExtraction=true to the orchestrator

    func test_m21b_importText_setsIsImportExtraction() async {
        let capturer = DynamicImportOrchestrator()
        let store = AppStore(testOrchestrator: capturer)
        store.startNewSession()

        store.sendImportRequest(text: "some recipe text")
        await drainMain()

        let requests = await capturer.requests
        XCTAssertEqual(requests.count, 1, "Exactly one LLM call must be made for import")
        XCTAssertTrue(requests[0].isImportExtraction,
                      "Import LLM request must have isImportExtraction=true")
        XCTAssertFalse(requests[0].hasCanvas,
                       "Import LLM request must have hasCanvas=false")
    }

    // MARK: (m21-c) import never enters patch review

    func test_m21c_importText_neverEntersPatchReview() async {
        let capturer = DynamicImportOrchestrator()
        let store = AppStore(testOrchestrator: capturer)
        store.startNewSession()

        store.sendImportRequest(text: "some recipe text")
        await drainMain()

        XCTAssertFalse(store.uiState.isPatchProposed,
                       "Import must never enter patchProposed state")
        XCTAssertFalse(store.uiState.isPatchReview,
                       "Import must never enter patchReview state")
    }

    // MARK: (m21-d) import LLM failure — hasCanvas stays false, importError set, sheet stays open

    func test_m21d_importText_failure_setsError() async {
        let mock = SyncOrchestrator(result: failureResult(fallbackPatchSet: nil))
        let store = AppStore(testOrchestrator: mock)
        store.startNewSession()

        store.isShowingImportSheet = true
        store.sendImportRequest(text: "some recipe text")
        await drainMain()

        XCTAssertFalse(store.hasCanvas, "hasCanvas must remain false after import failure")
        XCTAssertTrue(store.isShowingImportSheet, "Import sheet must stay open on failure")
        XCTAssertNotNil(store.importError, "importError must be set after import failure")
        XCTAssertEqual(store.chatTranscript.count, 0,
                       "Transcript must be empty after import failure (no messages appended)")
    }

    // MARK: (m21-e) import noPatches result — hasCanvas stays false, importError set

    func test_m21e_importText_noPatches_setsError() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let store = AppStore(testOrchestrator: mock)
        store.startNewSession()

        store.isShowingImportSheet = true
        store.sendImportRequest(text: "some recipe text")
        await drainMain()

        XCTAssertFalse(store.hasCanvas, "hasCanvas must remain false after noPatches import")
        XCTAssertNotNil(store.importError, "importError must be set when LLM returns noPatches")
    }

    // MARK: (mep-a) triggerMiseEnPlace — applies transformation to recipe

    func test_mepa_triggerMiseEnPlace_populatesMiseEnPlaceAndUpdatesProcedure() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let mepService = MockMiseEnPlaceService(response: MiseEnPlaceResponse(
            miseEnPlace: [
                .solo(instruction: "Chop the onions"),
                .solo(instruction: "Mince the garlic"),
            ],
            updatedSteps: ["Saute until golden", "Add sauce and simmer"]
        ))
        let store = AppStore(testOrchestrator: mock, testMiseEnPlaceService: mepService)
        let originalVersion = store.uiState.recipe.version

        XCTAssertNil(store.uiState.recipe.miseEnPlace, "Pre-condition: miseEnPlace must be nil")

        store.triggerMiseEnPlace()
        await drainMain()

        let recipe = store.uiState.recipe
        XCTAssertNotNil(recipe.miseEnPlace, "miseEnPlace must be populated after trigger")
        XCTAssertEqual(recipe.miseEnPlace?.count, 2, "Two prep entries must be in miseEnPlace")
        if case .solo(let instruction, _) = recipe.miseEnPlace?[0].content {
            XCTAssertEqual(instruction, "Chop the onions")
        } else { XCTFail("Expected .solo entry at index 0") }
        if case .solo(let instruction, _) = recipe.miseEnPlace?[1].content {
            XCTAssertEqual(instruction, "Mince the garlic")
        } else { XCTFail("Expected .solo entry at index 1") }
        XCTAssertEqual(recipe.steps.count, 2, "Procedure must have the two cooking-only steps")
        XCTAssertEqual(recipe.steps[0].text, "Saute until golden")
        XCTAssertEqual(recipe.version, originalVersion + 1, "Version must increment after transformation")
        XCTAssertNil(store.miseEnPlaceError, "No error on success")
        XCTAssertFalse(store.miseEnPlaceIsLoading, "Loading flag must clear after completion")
    }

    // MARK: (mep-b) triggerMiseEnPlace with empty miseEnPlace — shows error, recipe unchanged

    func test_mepb_triggerMiseEnPlace_emptyResult_setsErrorNoChange() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let mepService = MockMiseEnPlaceService(response: MiseEnPlaceResponse(
            miseEnPlace: [],
            updatedSteps: ["Mix dry ingredients", "Bake at 375°F for 30 min"]
        ))
        let store = AppStore(testOrchestrator: mock, testMiseEnPlaceService: mepService)
        let originalRecipe = store.uiState.recipe

        store.triggerMiseEnPlace()
        await drainMain()

        XCTAssertEqual(store.miseEnPlaceError, "No prep steps found to separate",
                       "Error message must be set when no prep steps are found")
        XCTAssertNil(store.uiState.recipe.miseEnPlace,
                     "miseEnPlace must remain nil when result is empty")
        XCTAssertEqual(store.uiState.recipe.steps.count, originalRecipe.steps.count,
                       "Steps must be unchanged when no prep steps found")
        XCTAssertFalse(store.miseEnPlaceIsLoading, "Loading flag must clear")
    }

    // MARK: (mep-c) triggerMiseEnPlace — preserves done status on matching procedure steps

    func test_mepc_triggerMiseEnPlace_preservesDoneStatusOnMatchingSteps() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        // Seed recipe has "Let cool on rack" as done. Simulate LLM returning it unchanged.
        let mepService = MockMiseEnPlaceService(response: MiseEnPlaceResponse(
            miseEnPlace: [.solo(instruction: "Mix dry ingredients")],
            updatedSteps: ["Bake at 375°F for 30 min", "Let cool on rack"]
        ))
        let store = AppStore(testOrchestrator: mock, testMiseEnPlaceService: mepService)

        store.triggerMiseEnPlace()
        await drainMain()

        let steps = store.uiState.recipe.steps
        let coolStep = steps.first(where: { $0.text == "Let cool on rack" })
        XCTAssertNotNil(coolStep, "Updated step must exist in procedure")
        XCTAssertEqual(coolStep?.status, .done,
                       "Done status must be preserved for steps whose text matches a done step")
        let prepEntry = store.uiState.recipe.miseEnPlace?.first
        XCTAssertFalse(prepEntry?.isDone ?? true,
                       "Mise en place entries start as not done")
    }

    // MARK: (mep-d) triggerMiseEnPlace — service error sets error message, recipe unchanged

    func test_mepd_triggerMiseEnPlace_serviceError_setsErrorMessage() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let mepService = MockMiseEnPlaceService(error: MiseEnPlaceServiceError.networkError(
            URLError(.notConnectedToInternet)
        ))
        let store = AppStore(testOrchestrator: mock, testMiseEnPlaceService: mepService)
        let originalRecipe = store.uiState.recipe

        store.triggerMiseEnPlace()
        await drainMain()

        XCTAssertEqual(store.miseEnPlaceError, "Couldn't generate mise en place — try again",
                       "Error message must be set on service failure")
        XCTAssertNil(store.uiState.recipe.miseEnPlace,
                     "Recipe must be unchanged after service failure")
        XCTAssertEqual(store.uiState.recipe.version, originalRecipe.version,
                       "Version must not increment on failure")
        XCTAssertFalse(store.miseEnPlaceIsLoading, "Loading flag must clear on failure")
    }

    // MARK: (mep-e) markMiseEnPlaceDone — marks a solo step done

    func test_mepe_markMiseEnPlaceDone_marksStepAsDone() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let mepService = MockMiseEnPlaceService(response: MiseEnPlaceResponse(
            miseEnPlace: [.solo(instruction: "Chop the onions")],
            updatedSteps: ["Saute and cook"]
        ))
        let store = AppStore(testOrchestrator: mock, testMiseEnPlaceService: mepService)

        store.triggerMiseEnPlace()
        await drainMain()

        guard let mepEntry = store.uiState.recipe.miseEnPlace?.first else {
            XCTFail("Expected a miseEnPlace entry to exist"); return
        }
        XCTAssertFalse(mepEntry.isDone, "Pre-condition: entry must start as not done")

        store.markMiseEnPlaceDone(mepEntry.id)

        let updated = store.uiState.recipe.miseEnPlace?.first(where: { $0.id == mepEntry.id })
        XCTAssertTrue(updated?.isDone ?? false, "Entry must be done after markMiseEnPlaceDone")
    }

    // MARK: (mep-f) miseEnPlace persisted and restored across app launches

    func test_mepf_miseEnPlace_persistedAndRestoredFromDisk() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sous_test_mep_f_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mepEntry = MiseEnPlaceEntry(content: .solo(instruction: "Chop onions", isDone: false))
        let recipe = Recipe(
            id: UUID(), version: 2, title: "Test Recipe",
            ingredients: [], steps: [Step(text: "Add onions and cook")],
            notes: [], miseEnPlace: [mepEntry]
        )
        let snapshot = SessionSnapshot(
            schemaVersion: SessionSnapshot.currentSchemaVersion,
            hasCanvas: true,
            recipe: recipe,
            pendingPatchSet: nil,
            chatMessages: [],
            nextLLMContext: nil,
            savedAt: Date()
        )
        let fileURL = SessionPersistence.fileURL(for: recipe.id, in: tempDir)
        try SessionPersistence.save(snapshot, to: fileURL)

        let testDefaults = UserDefaults(suiteName: "sous_mep_f_\(UUID().uuidString)")
        let store = AppStore(sessionsDirectory: tempDir, preferencesDefaults: testDefaults)

        XCTAssertTrue(store.hasCanvas, "Store must restore canvas from seeded session")
        XCTAssertNotNil(store.uiState.recipe.miseEnPlace,
                        "miseEnPlace must be restored from disk")
        guard let restoredEntry = store.uiState.recipe.miseEnPlace?.first else {
            XCTFail("Expected a miseEnPlace entry to be restored"); return
        }
        if case .solo(let instruction, let isDone) = restoredEntry.content {
            XCTAssertEqual(instruction, "Chop onions", "Entry instruction must match the saved value")
            XCTAssertFalse(isDone, "Entry must restore as not done")
        } else {
            XCTFail("Expected .solo entry to be restored from disk")
        }
    }

    // MARK: (mep-g) group entry — per-component checking and auto-complete

    func test_mepg_groupEntry_perComponentChecking_andAutoComplete() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let mepService = MockMiseEnPlaceService(response: MiseEnPlaceResponse(
            miseEnPlace: [
                .group(vesselName: "Spice Bowl", components: ["1 tsp cumin", "1 tsp paprika"]),
            ],
            updatedSteps: ["Cook"]
        ))
        let store = AppStore(testOrchestrator: mock, testMiseEnPlaceService: mepService)

        store.triggerMiseEnPlace()
        await drainMain()

        guard let entry = store.uiState.recipe.miseEnPlace?.first else {
            XCTFail("Expected a miseEnPlace entry"); return
        }
        guard case .group(let vesselName, let components) = entry.content else {
            XCTFail("Expected a .group entry"); return
        }
        XCTAssertEqual(vesselName, "Spice Bowl")
        XCTAssertEqual(components.count, 2)
        XCTAssertFalse(entry.isDone, "Group must not be done when no components are done")

        // Mark first component done — group still not fully done
        let firstComponentId = components[0].id
        store.markMiseEnPlaceDone(firstComponentId)

        let afterFirst = store.uiState.recipe.miseEnPlace?.first
        XCTAssertFalse(afterFirst?.isDone ?? true,
                       "Group must not be done when only one of two components is done")
        if case .group(_, let updated) = afterFirst?.content {
            XCTAssertTrue(updated[0].isDone,  "First component must be done")
            XCTAssertFalse(updated[1].isDone, "Second component must still be undone")
        }

        // Mark second component done — group auto-completes
        let secondComponentId = components[1].id
        store.markMiseEnPlaceDone(secondComponentId)

        let afterBoth = store.uiState.recipe.miseEnPlace?.first
        XCTAssertTrue(afterBoth?.isDone ?? false,
                      "Group must be done when all components are done")
    }

    // MARK: (m22-a) deleteActiveSessionAndStartNew — transitions to blank state

    func test_m22a_deleteActiveSessionAndStartNew_clearsToBlankState() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let store = AppStore(testOrchestrator: mock)

        // Pre-condition: test mode starts with seed recipe and hasCanvas = true
        XCTAssertTrue(store.hasCanvas, "Pre-condition: hasCanvas must be true in test mode")
        let activeId = store.uiState.recipe.id

        store.deleteActiveSessionAndStartNew()

        XCTAssertFalse(store.hasCanvas, "hasCanvas must be false after deleteActiveSessionAndStartNew")
        XCTAssertTrue(store.chatTranscript.isEmpty, "Chat transcript must be empty after deleteActiveSessionAndStartNew")
        if case .chatOpen = store.uiState {} else {
            XCTFail("Expected chatOpen state after deleteActiveSessionAndStartNew, got \(store.uiState)")
        }
        XCTAssertNotEqual(store.uiState.recipe.id, activeId,
                          "Blank recipe must have a new UUID, not the deleted recipe's ID")
    }

    // MARK: (m22-b) deleteActiveSessionAndStartNew — deletes session file from disk

    func test_m22b_deleteActiveSessionAndStartNew_deletesSessionFromDisk() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sous_test_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Pre-seed a session on disk so AppStore restores it on init
        let recipe = Recipe(id: UUID(), version: 1, title: "To Be Deleted",
                            ingredients: [], steps: [], notes: [])
        let snapshot = SessionSnapshot(
            schemaVersion: SessionSnapshot.currentSchemaVersion,
            hasCanvas: true,
            recipe: recipe,
            pendingPatchSet: nil,
            chatMessages: [],
            nextLLMContext: nil,
            savedAt: Date()
        )
        let fileURL = SessionPersistence.fileURL(for: recipe.id, in: tempDir)
        try SessionPersistence.save(snapshot, to: fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path),
                      "Pre-condition: session file must exist before deletion")

        // Init with real persistence pointed at temp dir — loads the seeded snapshot
        let testDefaults = UserDefaults(suiteName: "sous_test_m22b_\(UUID().uuidString)")
        let store = AppStore(sessionsDirectory: tempDir, preferencesDefaults: testDefaults)
        XCTAssertTrue(store.hasCanvas, "Pre-condition: store must have restored the seeded canvas")
        XCTAssertEqual(store.uiState.recipe.id, recipe.id,
                       "Pre-condition: active recipe must match the seeded recipe")

        store.deleteActiveSessionAndStartNew()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path),
                       "Session file must be deleted from disk after deleteActiveSessionAndStartNew")
        XCTAssertFalse(store.hasCanvas, "hasCanvas must be false after deleteActiveSessionAndStartNew")
    }

    // MARK: - resetRecipe

    func test_resetRecipe_resetsAllStepsTodo() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)
        // Seed recipe already has stepDoneId at .done; mark another step done too.
        store.send(.markStepDone(stepId: AppStore.stepMixId))
        await drainMain()
        XCTAssertEqual(
            store.uiState.recipe.steps.first { $0.id == AppStore.stepMixId }?.status, .done,
            "Pre-condition: stepMixId should be .done before reset"
        )
        XCTAssertEqual(
            store.uiState.recipe.steps.first { $0.id == AppStore.stepDoneId }?.status, .done,
            "Pre-condition: stepDoneId should be .done before reset"
        )

        store.resetRecipe()

        let steps = store.uiState.recipe.steps
        XCTAssertTrue(
            steps.allSatisfy { $0.status == .todo },
            "All steps must be .todo after resetRecipe; got: \(steps.map { "\($0.text): \($0.status)" })"
        )
    }

    func test_resetRecipe_preservesChatTranscript() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)
        let countBefore = store.chatTranscript.count
        XCTAssertGreaterThan(countBefore, 0, "Pre-condition: seed transcript must be non-empty")

        store.resetRecipe()

        XCTAssertEqual(store.chatTranscript.count, countBefore,
                       "Chat transcript must be preserved after resetRecipe")
    }

    func test_resetRecipe_preservesRecipeContent() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)
        let before = store.uiState.recipe

        store.resetRecipe()

        let after = store.uiState.recipe
        XCTAssertEqual(after.id, before.id, "Recipe id must be preserved")
        XCTAssertEqual(after.title, before.title, "Recipe title must be preserved")
        XCTAssertEqual(after.ingredients, before.ingredients, "Ingredients must be preserved")
        XCTAssertEqual(after.steps.map(\.text), before.steps.map(\.text), "Step text must be preserved")
    }

    func test_resetRecipe_clearsMiseEnPlaceSoloStates() async {
        let mock = SyncOrchestrator(result: noPatchesResult())
        let mepService = MockMiseEnPlaceService(response: MiseEnPlaceResponse(
            miseEnPlace: [
                .solo(instruction: "Chop onions"),
                .solo(instruction: "Mince garlic"),
            ],
            updatedSteps: ["Saute until golden"]
        ))
        let store = AppStore(testOrchestrator: mock, testMiseEnPlaceService: mepService)
        store.triggerMiseEnPlace()
        await drainMain()

        // Mark the first solo entry done.
        let entryId = store.uiState.recipe.miseEnPlace![0].id
        store.markMiseEnPlaceDone(entryId)
        XCTAssertTrue(store.uiState.recipe.miseEnPlace![0].isDone, "Pre-condition: entry must be done before reset")

        store.resetRecipe()

        let mep = store.uiState.recipe.miseEnPlace
        XCTAssertNotNil(mep, "Mise en place section must still be present after reset")
        XCTAssertEqual(mep?.count, 2, "Entry count must be unchanged")
        XCTAssertTrue(mep?.allSatisfy { !$0.isDone } ?? false,
                      "All mise en place entries must be unchecked after reset")
    }

    func test_resetRecipe_clearsMiseEnPlaceGroupComponentStates() async {
        // Populate MEP with two solo entries, mark both done, verify reset clears them both.
        let mock = SyncOrchestrator(result: noPatchesResult())
        let mepService = MockMiseEnPlaceService(response: MiseEnPlaceResponse(
            miseEnPlace: [
                .solo(instruction: "Chop onions"),
                .solo(instruction: "Mince garlic"),
            ],
            updatedSteps: ["Saute until golden"]
        ))
        let store = AppStore(testOrchestrator: mock, testMiseEnPlaceService: mepService)
        store.triggerMiseEnPlace()
        await drainMain()

        let id0 = store.uiState.recipe.miseEnPlace![0].id
        let id1 = store.uiState.recipe.miseEnPlace![1].id
        store.markMiseEnPlaceDone(id0)
        store.markMiseEnPlaceDone(id1)
        XCTAssertTrue(store.uiState.recipe.miseEnPlace!.allSatisfy { $0.isDone },
                      "Pre-condition: all entries are done before reset")

        store.resetRecipe()

        let mep = store.uiState.recipe.miseEnPlace
        XCTAssertNotNil(mep, "Section must remain after reset")
        XCTAssertEqual(mep?.count, 2, "Entry count must be unchanged")
        XCTAssertTrue(mep!.allSatisfy { !$0.isDone },
                      "All mise en place entries must be undone after reset")
    }

    func test_resetRecipe_nilMiseEnPlace_remainsNil() async {
        let mock = ControlledOrchestrator()
        let store = AppStore(testOrchestrator: mock)
        XCTAssertNil(store.uiState.recipe.miseEnPlace, "Pre-condition: seed recipe has no mise en place")

        store.resetRecipe()

        XCTAssertNil(store.uiState.recipe.miseEnPlace,
                     "miseEnPlace must remain nil after reset when it was not set")
    }
}

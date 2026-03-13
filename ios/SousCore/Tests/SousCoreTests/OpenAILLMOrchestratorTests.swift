import Testing
import Foundation
@testable import SousCore

// MARK: - MockLLMClient

private final class MockLLMClient: LLMClient, @unchecked Sendable {
    private let responses: [Result<String, Error>]
    private(set) var callCount = 0

    init(_ responses: [Result<String, Error>]) {
        self.responses = responses
    }

    func send(_ request: LLMClientRequest) async throws -> LLMRawResponse {
        let idx = callCount
        callCount += 1
        switch responses[idx] {
        case .success(let text):
            return LLMRawResponse(rawText: text, requestId: request.requestId ?? "mock",
                                  attempt: idx + 1, timingMs: 1, transport: .mock)
        case .failure(let e):
            throw e
        }
    }
}

// MARK: - Fixtures

private extension OpenAILLMOrchestratorTests {
    var recipe: Recipe { SeedRecipes.sample() }

    func request(message: String = "Make it spicier") -> LLMRequest {
        LLMRequest(
            recipeId: SeedRecipes.recipeId.uuidString,
            recipeVersion: 1,
            hasCanvas: true,
            userMessage: message,
            recipeSnapshotForPrompt: SeedRecipes.sample(),
            userPrefs: LLMUserPrefs(hardAvoids: [])
        )
    }

    /// Valid LLM JSON response adding a note (uses known recipe IDs).
    func validJSON(patchSetId: String = "ps-1") -> String {
        """
        {
          "assistant_message": "Done.",
          "patchSet": {
            "patchSetId": "\(patchSetId)",
            "baseRecipeId": "\(SeedRecipes.recipeId.uuidString)",
            "baseRecipeVersion": 1,
            "patches": [{"type":"add_note","text":"Add chilli flakes"}]
          }
        }
        """
    }

    func nullPatchSetJSON() -> String {
        #"{"assistant_message":"What kind of spice?","patchSet":null}"#
    }

    func wrongRecipeIdJSON() -> String {
        """
        {"assistant_message":"Done.","patchSet":{"patchSetId":"ps-x","baseRecipeId":"AAAAAAAA-0000-0000-0000-000000000001","baseRecipeVersion":1,"patches":[{"type":"add_note","text":"hi"}]}}
        """
    }

    func wrongVersionJSON() -> String {
        """
        {"assistant_message":"Done.","patchSet":{"patchSetId":"ps-x","baseRecipeId":"\(SeedRecipes.recipeId.uuidString)","baseRecipeVersion":99,"patches":[{"type":"add_note","text":"hi"}]}}
        """
    }

    /// Targets the done step — fatal validator error.
    func doneStepMutationJSON() -> String {
        """
        {"assistant_message":"Done.","patchSet":{"patchSetId":"ps-x","baseRecipeId":"\(SeedRecipes.recipeId.uuidString)","baseRecipeVersion":1,"patches":[{"type":"update_step","id":"\(SeedRecipes.stepDoneId.uuidString)","text":"changed"}]}}
        """
    }

    /// Targets a non-existent step ID — recoverable validator error.
    func badStepIdJSON() -> String {
        let fakeId = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001")!
        return """
        {"assistant_message":"Done.","patchSet":{"patchSetId":"ps-x","baseRecipeId":"\(SeedRecipes.recipeId.uuidString)","baseRecipeVersion":1,"patches":[{"type":"update_step","id":"\(fakeId.uuidString)","text":"new"}]}}
        """
    }

    func orchestrator(_ responses: [Result<String, Error>]) -> (OpenAILLMOrchestrator, MockLLMClient) {
        let mock = MockLLMClient(responses)
        let orch = OpenAILLMOrchestrator(client: mock, model: "gpt-4o-mini")
        return (orch, mock)
    }
}

// MARK: - Tests

@Suite("OpenAILLMOrchestrator")
struct OpenAILLMOrchestratorTests {

    @Test("valid patchSet returns .valid")
    func validPatchSet_returnsValid() async {
        let (orch, mock) = orchestrator([.success(validJSON())])
        let result = await orch.run(request())
        guard case .valid(let ps, _, _, _, _) = result else {
            Issue.record("Expected .valid, got \(result)"); return
        }
        #expect(ps.patches.count == 1)
        #expect(mock.callCount == 1)
    }

    @Test("patchSet null returns .noPatches")
    func nullPatchSet_returnsNoPatches() async {
        let (orch, mock) = orchestrator([.success(nullPatchSetJSON())])
        let result = await orch.run(request())
        guard case .noPatches(let msg, _, _, _) = result else {
            Issue.record("Expected .noPatches, got \(result)"); return
        }
        #expect(msg == "What kind of spice?")
        #expect(mock.callCount == 1)
    }

    @Test("recipeId mismatch returns .failure(.recipeIdMismatchFatal), no repair")
    func recipeIdMismatch_fatalNoRepair() async {
        let (orch, mock) = orchestrator([.success(wrongRecipeIdJSON())])
        let result = await orch.run(request())
        guard case .failure(_, _, _, _, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .recipeIdMismatchFatal)
        #expect(mock.callCount == 1)
    }

    @Test("baseRecipeVersion mismatch returns .failure(.validationExpired), no repair")
    func versionMismatch_expiredNoRepair() async {
        let (orch, mock) = orchestrator([.success(wrongVersionJSON())])
        let result = await orch.run(request())
        guard case .failure(_, _, _, _, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .validationExpired)
        #expect(mock.callCount == 1)
    }

    @Test("fatal validator error returns .failure(.validationFatal), no repair")
    func fatalValidatorError_noRepair() async {
        let (orch, mock) = orchestrator([.success(doneStepMutationJSON())])
        let result = await orch.run(request())
        guard case .failure(_, _, _, _, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .validationFatal)
        #expect(mock.callCount == 1)
    }

    @Test("recoverable validator error triggers repair; repair success returns .valid")
    func recoverableError_repairSucceeds() async {
        let (orch, mock) = orchestrator([
            .success(badStepIdJSON()),   // first call: recoverable (invalid step ID)
            .success(validJSON())         // repair call: valid
        ])
        let result = await orch.run(request())
        guard case .valid = result else {
            Issue.record("Expected .valid after repair, got \(result)"); return
        }
        #expect(mock.callCount == 2)
    }

    @Test("debug bundle carries stable eval fields: model, promptVersion, outcome, failureCategory, attemptCount")
    func debugBundle_stableEvalFields() async {
        // 1. valid result: model/promptVersion set, outcome="valid", failureCategory=nil
        let (orch1, _) = orchestrator([.success(validJSON())])
        let r1 = await orch1.run(request())
        guard case .valid(_, _, _, let d1, _) = r1 else { Issue.record("Expected .valid"); return }
        #expect(d1.model == "gpt-4o-mini")
        #expect(d1.promptVersion == "v5")
        #expect(d1.outcome == "valid")
        #expect(d1.failureCategory == nil)
        #expect(d1.attemptCount == 1)

        // 2. repair path: attemptCount=2, outcome="valid", repairUsed=true
        let (orch2, _) = orchestrator([.success(badStepIdJSON()), .success(validJSON())])
        let r2 = await orch2.run(request())
        guard case .valid(_, _, _, let d2, _) = r2 else { Issue.record("Expected .valid after repair"); return }
        #expect(d2.attemptCount == 2)
        #expect(d2.outcome == "valid")
        #expect(d2.repairUsed == true)

        // 3. noPatches: outcome="noPatches", failureCategory=nil
        let (orch3, _) = orchestrator([.success(nullPatchSetJSON())])
        let r3 = await orch3.run(request())
        guard case .noPatches(_, _, let d3, _) = r3 else { Issue.record("Expected .noPatches"); return }
        #expect(d3.outcome == "noPatches")
        #expect(d3.failureCategory == nil)

        // 4. network failure: outcome="failure", failureCategory="network" (stable string)
        // Two failures needed: first triggers retry, second triggers repeat_failure termination.
        struct FakeNetworkError: Error {}
        let (orch4, _) = orchestrator([.failure(FakeNetworkError()), .failure(FakeNetworkError())])
        let r4 = await orch4.run(request())
        guard case .failure(_, _, _, let d4, _) = r4 else { Issue.record("Expected .failure"); return }
        #expect(d4.outcome == "failure")
        #expect(d4.failureCategory == "network")

        // 5. validationFatal: failureCategory="validationFatal"
        let (orch5, _) = orchestrator([.success(doneStepMutationJSON())])
        let r5 = await orch5.run(request())
        guard case .failure(_, _, _, let d5, _) = r5 else { Issue.record("Expected .failure"); return }
        #expect(d5.failureCategory == "validationFatal")
    }

    // MARK: - Retry / Backoff / TerminationReason Tests

    @Test("network failure then success: 2 attempts, terminationReason success")
    func networkFailureThenSuccess_twoAttempts() async {
        struct FakeNetworkError: Error {}
        let (orch, mock) = orchestrator([.failure(FakeNetworkError()), .success(validJSON())])
        let result = await orch.run(request())
        guard case .valid(_, _, _, let d, _) = result else {
            Issue.record("Expected .valid, got \(result)"); return
        }
        #expect(mock.callCount == 2)
        #expect(d.attemptCount == 2)
        #expect(d.terminationReason == "success")
    }

    @Test("network failure twice: terminates with repeat_failure")
    func networkFailureTwice_repeatFailure() async {
        struct FakeNetworkError: Error {}
        let (orch, mock) = orchestrator([.failure(FakeNetworkError()), .failure(FakeNetworkError())])
        let result = await orch.run(request())
        guard case .failure(_, _, _, let d, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .network)
        #expect(mock.callCount == 2)
        #expect(d.terminationReason == "repeat_failure")
    }

    @Test("recoverable validation failure triggers repair once then succeeds: terminationReason success")
    func recoverableValidation_repairSucceeds_terminationSuccess() async {
        let (orch, mock) = orchestrator([.success(badStepIdJSON()), .success(validJSON())])
        let result = await orch.run(request())
        guard case .valid(_, _, _, let d, _) = result else {
            Issue.record("Expected .valid after repair, got \(result)"); return
        }
        #expect(mock.callCount == 2)
        #expect(d.repairUsed == true)
        #expect(d.terminationReason == "success")
    }

    @Test("same decode failure signature on primary + repair: terminates with repeat_failure")
    func decodeInvalidJSON_sameSignatureOnRepair_repeatFailure() async {
        // Both responses trigger DecodeFailure.decodeInvalidJSON — assistant_message is a number,
        // not a String. The two raw strings are intentionally different so the rawText identity
        // check in repair() does not fire; only the failure-signature guard does.
        let jsonA = #"{"assistant_message": 1}"#
        let jsonB = #"{"assistant_message": 2}"#
        let (orch, mock) = orchestrator([.success(jsonA), .success(jsonB)])
        let result = await orch.run(request())
        guard case .failure(_, _, _, let d, _) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(d.terminationReason == "repeat_failure")
        #expect(d.repairUsed == true)
        #expect(d.attemptCount == 2)   // primary call + one repair call
        #expect(mock.callCount == 2)
    }

    @Test("repair returns identical rawText: terminates with repair_identical")
    func repair_identicalRawText_terminates() async {
        // Primary call returns JSON X that fails recoverable validation.
        // Repair call returns the exact same rawText X.
        // Orchestrator must terminate immediately — no further decode or repair.
        let (orch, mock) = orchestrator([.success(badStepIdJSON()), .success(badStepIdJSON())])
        let result = await orch.run(request())
        guard case .failure(_, _, _, let d, _) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(d.terminationReason == "repair_identical")
        #expect(d.repairUsed == true)
        #expect(d.attemptCount == 2)   // primary call + repair call
        #expect(mock.callCount == 2)
    }

    @Test("fatal validation terminates immediately with fatal_validation, no retry")
    func fatalValidation_terminatesImmediately() async {
        let (orch, mock) = orchestrator([.success(doneStepMutationJSON())])
        let result = await orch.run(request())
        guard case .failure(_, _, _, let d, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .validationFatal)
        #expect(mock.callCount == 1)
        #expect(d.terminationReason == "fatal_validation")
    }

    @Test("expired validation terminates immediately with expired_validation, no retry")
    func expiredValidation_terminatesImmediately() async {
        let (orch, mock) = orchestrator([.success(wrongVersionJSON())])
        let result = await orch.run(request())
        guard case .failure(_, _, _, let d, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .validationExpired)
        #expect(mock.callCount == 1)
        #expect(d.terminationReason == "expired_validation")
    }

    @Test("auth error terminates immediately — not retried")
    func authError_terminatesImmediately_notRetried() async {
        let (orch, mock) = orchestrator([.failure(LLMError.auth)])
        let result = await orch.run(request())
        guard case .failure(_, _, _, let d, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .auth)
        #expect(mock.callCount == 1, "auth must not trigger any retry")
        #expect(d.failureCategory == "auth")
        #expect(d.terminationReason == "fatal_auth")
    }

    @Test("rateLimited error retries once then fails with repeat_failure")
    func rateLimited_retriesOnce_thenRepeatFailure() async {
        // Two consecutive rateLimited throws → repeat_failure on second.
        let (orch, mock) = orchestrator([
            .failure(LLMError.rateLimited(retryAfterSec: 0)),
            .failure(LLMError.rateLimited(retryAfterSec: 0)),
        ])
        let result = await orch.run(request())
        guard case .failure(_, _, _, let d, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .rateLimited(retryAfterSec: 0))
        #expect(mock.callCount == 2, "rateLimited must be retried exactly once")
        #expect(d.failureCategory == "rateLimited")
        #expect(d.terminationReason == "repeat_failure")
    }

    @Test("rateLimited failure message maps to quota/rate limit copy")
    func rateLimited_assistantMessage_isQuotaString() async {
        let (orch, _) = orchestrator([
            .failure(LLMError.rateLimited(retryAfterSec: nil)),
            .failure(LLMError.rateLimited(retryAfterSec: nil)),
        ])
        let result = await orch.run(request())
        guard case .failure(_, let msg, _, _, _) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(msg == "OpenAI quota/rate limit hit. Try again shortly.")
    }

    // MARK: - Multimodal run() tests

    @Test("multimodal: payload too large returns .failure before any network call")
    func multimodal_payloadTooLarge_returnsFailureBeforeNetworkCall() async throws {
        // MockLLMClient with no configured responses — any network call would crash.
        let mock = MockLLMClient([])
        let orch = OpenAILLMOrchestrator(client: mock, model: "gpt-4o")

        // 10 MB + 1 byte exceeds the 10 MB internal gate.
        let bigData = Data(repeating: 0xFF, count: 10 * 1024 * 1024 + 1)
        let image = try PreparedImage(
            data: bigData, mimeType: "image/jpeg",
            widthPx: 1000, heightPx: 1000, originalByteCount: bigData.count
        )
        let req = MultimodalLLMRequest(base: request(), image: image)

        let result = await orch.run(req)

        #expect(mock.callCount == 0, "No network call must be made when image exceeds size limit")
        guard case .failure(_, let msg, _, _, let err) = result else {
            Issue.record("Expected .failure for oversized payload, got \(result)"); return
        }
        #expect(err == .badRequest)
        #expect(msg.contains("too large"))
    }

    @Test("multimodal: valid response returns .valid result via shared decode path")
    func multimodal_validResponse_returnsValid() async throws {
        let mock = MockLLMClient([.success(validJSON())])
        let orch = OpenAILLMOrchestrator(client: mock, model: "gpt-4o")

        let imageData = Data([0xFF, 0xD8, 0xFF])
        let image = try PreparedImage(
            data: imageData, mimeType: "image/jpeg",
            widthPx: 100, heightPx: 100, originalByteCount: 3
        )
        let req = MultimodalLLMRequest(base: request(), image: image)

        let result = await orch.run(req)

        #expect(mock.callCount == 1)
        guard case .valid(let ps, _, _, _, _) = result else {
            Issue.record("Expected .valid, got \(result)"); return
        }
        #expect(ps.patches.count == 1)
    }

    @Test("multimodal: auth error terminates immediately without retry")
    func multimodal_authError_noRetry() async throws {
        let mock = MockLLMClient([.failure(LLMError.auth)])
        let orch = OpenAILLMOrchestrator(client: mock, model: "gpt-4o")

        let imageData = Data([0xFF, 0xD8, 0xFF])
        let image = try PreparedImage(
            data: imageData, mimeType: "image/jpeg",
            widthPx: 100, heightPx: 100, originalByteCount: 3
        )
        let req = MultimodalLLMRequest(base: request(), image: image)

        let result = await orch.run(req)

        #expect(mock.callCount == 1, "auth must not trigger any retry in multimodal path")
        guard case .failure(_, _, _, let d, let err) = result else {
            Issue.record("Expected .failure, got \(result)"); return
        }
        #expect(err == .auth)
        #expect(d.terminationReason == "fatal_auth")
    }

    @Test("proposed_memory field is decoded and returned in result")
    func proposedMemory_isParsedFromJSON() async {
        let json = """
        {"assistant_message":"Got it!","patchSet":null,"proposed_memory":"I avoid cilantro"}
        """
        let (orch, _) = orchestrator([.success(json)])
        let result = await orch.run(request())
        guard case .noPatches(let msg, _, _, let memory) = result else {
            Issue.record("Expected .noPatches, got \(result)"); return
        }
        #expect(msg == "Got it!")
        #expect(memory == "I avoid cilantro")
    }

    @Test("absent proposed_memory field yields nil proposedMemory")
    func proposedMemory_absent_isNil() async {
        let (orch, _) = orchestrator([.success(nullPatchSetJSON())])
        let result = await orch.run(request())
        guard case .noPatches(_, _, _, let memory) = result else {
            Issue.record("Expected .noPatches, got \(result)"); return
        }
        #expect(memory == nil)
    }
}

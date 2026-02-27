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
        guard case .valid(let ps, _, _, _) = result else {
            Issue.record("Expected .valid, got \(result)"); return
        }
        #expect(ps.patches.count == 1)
        #expect(mock.callCount == 1)
    }

    @Test("patchSet null returns .noPatches")
    func nullPatchSet_returnsNoPatches() async {
        let (orch, mock) = orchestrator([.success(nullPatchSetJSON())])
        let result = await orch.run(request())
        guard case .noPatches(let msg, _, _) = result else {
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
}

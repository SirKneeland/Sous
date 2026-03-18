import Testing
@testable import SousCore

// MARK: - LLMTypesTests

/// Lightweight compile-and-pattern-match tests for LLM boundary types.
/// No network, no UI, no SwiftUI imports.
struct LLMTypesTests {

    // MARK: Test 1: LLMResult covers all three cases without UI imports

    @Test func llmResultAllCasesPatternMatch() {
        let recipe = Recipe(title: "Test Recipe")
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: []
        )
        let debug = LLMDebugBundle(
            status: .succeeded,
            attemptCount: 1,
            maxAttempts: 3,
            requestId: "req-1",
            extractionUsed: false,
            repairUsed: false,
            timingTotalMs: 200,
            model: "gpt-4o-mini",
            promptVersion: "v1",
            outcome: "valid"
        )

        let results: [LLMResult] = [
            .valid(patchSet: patchSet, assistantMessage: "Done", raw: nil, debug: debug, proposedMemory: nil),
            .noPatches(assistantMessage: "Nothing to change", raw: nil, debug: debug, proposedMemory: nil, suggestGenerate: nil),
            .failure(fallbackPatchSet: nil, assistantMessage: "Error", raw: nil, debug: debug, error: .network)
        ]

        for result in results {
            switch result {
            case .valid(let ps, _, _, _, _):
                #expect(ps.baseRecipeVersion == recipe.version)
            case .noPatches(let msg, _, _, _, _):
                #expect(!msg.isEmpty)
            case .failure(_, _, _, _, let error):
                #expect(error == .network)
            }
        }
    }

    // MARK: Test 2: LLMError.missingAPIKey is present and exhaustive switch compiles

    @Test func llmErrorExhaustiveSwitch() {
        let allErrors: [LLMError] = [
            .missingAPIKey,
            .network,
            .timeout,
            .cancelled,
            .decodeNonJSON,
            .decodeInvalidJSON,
            .schemaInvalid,
            .validationRecoverable,
            .validationExpired,
            .validationFatal,
            .recipeIdMismatchFatal,
            .rateLimited(retryAfterSec: nil),
            .auth,
            .badRequest,
            .server,
        ]

        for error in allErrors {
            // This switch must be exhaustive at compile time.
            let category: String = switch error {
            case .missingAPIKey:         "config"
            case .network:               "transport"
            case .timeout:               "transport"
            case .cancelled:             "transport"
            case .decodeNonJSON:         "decode"
            case .decodeInvalidJSON:     "decode"
            case .schemaInvalid:         "decode"
            case .validationRecoverable: "validation"
            case .validationExpired:     "validation"
            case .validationFatal:       "validation"
            case .recipeIdMismatchFatal: "validation"
            case .rateLimited:           "transport"
            case .auth:                  "transport"
            case .badRequest:            "transport"
            case .server:                "transport"
            }
            #expect(!category.isEmpty)
        }

        // missingAPIKey must be pattern-matchable in isolation
        let key: LLMError = .missingAPIKey
        #expect(key == .missingAPIKey)
    }

    // MARK: Test 3: Token fields propagate into LLMDebugBundle

    @Test func tokenFieldsPropagateWhenPresent() {
        let bundle = LLMDebugBundle(
            status: .succeeded,
            attemptCount: 1,
            maxAttempts: 3,
            requestId: "req-tokens",
            extractionUsed: false,
            repairUsed: false,
            timingTotalMs: 500,
            model: "gpt-4o-mini",
            promptVersion: "v1",
            outcome: "valid",
            promptTokens: 120,
            completionTokens: 80,
            totalTokens: 200
        )
        #expect(bundle.promptTokens == 120)
        #expect(bundle.completionTokens == 80)
        #expect(bundle.totalTokens == 200)
    }

    @Test func tokenFieldsAreNilByDefault() {
        let bundle = LLMDebugBundle(
            status: .succeeded,
            attemptCount: 1,
            maxAttempts: 3,
            requestId: "req-no-tokens",
            extractionUsed: false,
            repairUsed: false,
            timingTotalMs: 300,
            model: "gpt-4o-mini",
            promptVersion: "v1",
            outcome: "valid"
        )
        #expect(bundle.promptTokens == nil)
        #expect(bundle.completionTokens == nil)
        #expect(bundle.totalTokens == nil)
    }

    @Test func tokenFieldsPropagateFromLLMRawResponse() {
        let raw = LLMRawResponse(
            rawText: "{}",
            requestId: "req-raw",
            attempt: 1,
            timingMs: 100,
            transport: .openAI,
            promptTokens: 50,
            completionTokens: 30,
            totalTokens: 80
        )
        #expect(raw.promptTokens == 50)
        #expect(raw.completionTokens == 30)
        #expect(raw.totalTokens == 80)
    }

    @Test func rawResponseTokenFieldsAreNilByDefault() {
        let raw = LLMRawResponse(
            rawText: "{}",
            requestId: "req-raw-nil",
            attempt: 1,
            timingMs: 100,
            transport: .mock
        )
        #expect(raw.promptTokens == nil)
        #expect(raw.completionTokens == nil)
        #expect(raw.totalTokens == nil)
    }
}

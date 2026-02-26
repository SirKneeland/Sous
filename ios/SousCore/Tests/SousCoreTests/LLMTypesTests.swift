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
            timingTotalMs: 200
        )

        let results: [LLMResult] = [
            .valid(patchSet: patchSet, assistantMessage: "Done", raw: nil, debug: debug),
            .noPatches(assistantMessage: "Nothing to change", raw: nil, debug: debug),
            .failure(fallbackPatchSet: nil, assistantMessage: "Error", raw: nil, debug: debug, error: .network)
        ]

        for result in results {
            switch result {
            case .valid(let ps, _, _, _):
                #expect(ps.baseRecipeVersion == recipe.version)
            case .noPatches(let msg, _, _):
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
            .recipeIdMismatchFatal
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
            }
            #expect(!category.isEmpty)
        }

        // missingAPIKey must be pattern-matchable in isolation
        let key: LLMError = .missingAPIKey
        #expect(key == .missingAPIKey)
    }
}

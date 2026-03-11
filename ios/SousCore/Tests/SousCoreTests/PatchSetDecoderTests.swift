import Testing
@testable import SousCore

// MARK: - PatchSetDecoderTests

struct PatchSetDecoderTests {

    private let decoder = PatchSetDecoder()

    // MARK: - Helpers

    /// Pattern-matches a success result and returns the DTO for further inspection.
    /// Records a test failure and returns nil if the result is not success.
    private func expectSuccess(
        _ result: DecodeResult,
        extractionUsed expected: Bool? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> LLMResponseDTO? {
        guard case .success(let dto, let eu, _) = result else {
            Issue.record("Expected success, got \(result)", sourceLocation: sourceLocation)
            return nil
        }
        if let expected {
            #expect(eu == expected, sourceLocation: sourceLocation)
        }
        return dto
    }

    /// Asserts the result is exactly the given failure.
    private func expectFailure(
        _ result: DecodeResult,
        _ expected: DecodeFailure,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(result == .failure(expected), sourceLocation: sourceLocation)
    }

    // MARK: - Fixtures

    /// Minimal valid patchSet JSON fragment for reuse across tests.
    private func patchSetJSON(
        patchSetId: String = "ps-1",
        baseRecipeId: String = "r-1",
        baseRecipeVersion: Int = 1,
        patches: String = #"[{"type":"add_note","text":"Extra seasoning"}]"#
    ) -> String {
        """
        {
            "patchSetId": "\(patchSetId)",
            "baseRecipeId": "\(baseRecipeId)",
            "baseRecipeVersion": \(baseRecipeVersion),
            "patches": \(patches)
        }
        """
    }

    // MARK: Test 1: Valid JSON with extra keys — success, extras collected but ignored

    @Test func validJSONWithExtraKeys() {
        let json = """
        {
            "assistant_message": "Looks good!",
            "patchSet": {
                "patchSetId": "ps-1",
                "baseRecipeId": "r-1",
                "baseRecipeVersion": 3,
                "patches": [{"type": "add_note", "text": "Extra seasoning"}],
                "unknownPatchSetKey": "ignored"
            },
            "topLevelExtra": 42
        }
        """
        let result = decoder.decode(json)
        guard case .success(let dto, let extractionUsed, let unknownKeys) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(!extractionUsed)
        #expect(dto.assistantMessage == "Looks good!")
        #expect(dto.patchSet?.patchSetId == "ps-1")
        #expect(dto.patchSet?.baseRecipeVersion == 3)
        #expect(dto.patchSet?.patches.count == 1)
        // Both extra keys must be reported; order is alphabetical (sorted)
        #expect(unknownKeys.contains("topLevelExtra"))
        #expect(unknownKeys.contains("unknownPatchSetKey"))
        // Extra keys must never silently pass as decode failures
        #expect(!unknownKeys.isEmpty)
    }

    // MARK: Test 2: JSON followed by trailing prose — strict fails, extraction succeeds

    @Test func jsonWithTrailingCommentary() {
        // Raw string: valid JSON object immediately followed by prose (not valid JSON overall)
        let raw =
            #"{"assistant_message":"Done","patchSet":{"patchSetId":"p1","baseRecipeId":"r1","baseRecipeVersion":1,"patches":[{"type":"add_note","text":"hi"}]}}"# +
            "\nNote: I simplified the recipe as requested."

        let result = decoder.decode(raw)
        guard let dto = expectSuccess(result, extractionUsed: true) else { return }
        #expect(dto.assistantMessage == "Done")
        #expect(dto.patchSet?.patchSetId == "p1")
    }

    // MARK: Test 3: Plain prose text — decodeNonJSON

    @Test func plainProseText() {
        expectFailure(
            decoder.decode("Just some plain text, nothing to see here."),
            .decodeNonJSON
        )
    }

    // MARK: Test 4: Missing baseRecipeId

    @Test func missingBaseRecipeId() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeVersion": 2,
                "patches": [{"type": "add_note", "text": "hi"}]
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.baseRecipeIdMissing))
    }

    // MARK: Test 5: Missing baseRecipeVersion

    @Test func missingBaseRecipeVersion() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeId": "r1",
                "patches": [{"type": "add_note", "text": "hi"}]
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.baseRecipeVersionMissing))
    }

    // MARK: Test 6: Missing patches key

    @Test func missingPatchesKey() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeId": "r1",
                "baseRecipeVersion": 1
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.patchesMissing))
    }

    // MARK: Test 7: Empty patches array

    @Test func emptyPatchesArray() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeId": "r1",
                "baseRecipeVersion": 1,
                "patches": []
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.patchesEmpty))
    }

    // MARK: Test 8: patchSet null — success with no patchSet

    @Test func patchSetNull() {
        let json = #"{"assistant_message":"Nothing to change","patchSet":null}"#
        let result = decoder.decode(json)
        guard let dto = expectSuccess(result, extractionUsed: false) else { return }
        #expect(dto.patchSet == nil)
        #expect(dto.assistantMessage == "Nothing to change")
    }

    // MARK: Test 9: Missing assistant_message

    @Test func missingAssistantMessage() {
        let json = #"{"patchSet":null}"#
        expectFailure(decoder.decode(json), .schemaInvalid(.missingAssistantMessage))
    }

    // MARK: Test 10: Missing patchSetId

    @Test func missingPatchSetId() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "baseRecipeId": "r1",
                "baseRecipeVersion": 1,
                "patches": [{"type": "add_note", "text": "hi"}]
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.patchSetIdMissing))
    }

    // MARK: Test 11: Patches array contains non-object elements (strings)

    @Test func patchElementNotObject() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeId": "r1",
                "baseRecipeVersion": 1,
                "patches": ["addNote"]
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.patchElementNotObject))
    }

    // MARK: Test 12: Patch op present but required field absent

    @Test func patchOpMissingField() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeId": "r1",
                "baseRecipeVersion": 1,
                "patches": [{"type": "update_step", "text": "new text"}]
            }
        }
        """
        // update_step requires both "id" and "text"; "id" is missing
        expectFailure(decoder.decode(json), .schemaInvalid(.patchOpMissingField))
    }

    // MARK: Test 14: Patch object missing "type" key

    @Test func patchOpMissingType() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeId": "r1",
                "baseRecipeVersion": 1,
                "patches": [{"text": "Extra seasoning"}]
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.patchOpMissingType))
    }

    // MARK: Test 15: Patch object "type" value is not a String

    @Test func patchOpTypeNotString() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeId": "r1",
                "baseRecipeVersion": 1,
                "patches": [{"type": 42, "text": "hi"}]
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.patchOpTypeNotString))
    }

    // MARK: Test 16: Patch object "type" is a String but not a known op

    @Test func patchOpUnknownType() {
        let json = """
        {
            "assistant_message": "Here",
            "patchSet": {
                "patchSetId": "p1",
                "baseRecipeId": "r1",
                "baseRecipeVersion": 1,
                "patches": [{"type": "edit_step", "id": "s1", "text": "hi"}]
            }
        }
        """
        expectFailure(decoder.decode(json), .schemaInvalid(.patchOpUnknownType))
    }

    // MARK: Test 17: add_ingredient with JSON null after_id — success, afterId decoded as nil

    @Test func addIngredient_jsonNullAfterId_decodesAsNil() {
        let json = """
        {
            "assistant_message": "Adding tomato as an ingredient.",
            "patchSet": {
                "patchSetId": "ps-1",
                "baseRecipeId": "r-1",
                "baseRecipeVersion": 1,
                "patches": [{"type": "add_ingredient", "text": "tomato", "after_id": null}]
            }
        }
        """
        let result = decoder.decode(json)
        guard let dto = expectSuccess(result, extractionUsed: false) else { return }
        guard case .addIngredient(let text, let afterId) = dto.patchSet?.patches[0] else {
            Issue.record("Expected addIngredient patch op")
            return
        }
        #expect(text == "tomato")
        #expect(afterId == nil, "JSON null after_id must decode as nil, not the string 'null'")
    }

    // MARK: Test 18: add_ingredient with UUID string after_id — success, afterId decoded as string

    @Test func addIngredient_uuidAfterId_decodesAsString() {
        let uuidStr = "AAAABBBB-0000-0000-0000-000000000001"
        let json = """
        {
            "assistant_message": "Inserting tomato after flour.",
            "patchSet": {
                "patchSetId": "ps-1",
                "baseRecipeId": "r-1",
                "baseRecipeVersion": 1,
                "patches": [{"type": "add_ingredient", "text": "tomato", "after_id": "\(uuidStr)"}]
            }
        }
        """
        let result = decoder.decode(json)
        guard let dto = expectSuccess(result, extractionUsed: false) else { return }
        guard case .addIngredient(let text, let afterId) = dto.patchSet?.patches[0] else {
            Issue.record("Expected addIngredient patch op")
            return
        }
        #expect(text == "tomato")
        #expect(afterId == uuidStr)
    }

    // MARK: Test 19: add_step with JSON null after_step_id — success, afterStepId decoded as nil

    @Test func addStep_jsonNullAfterStepId_decodesAsNil() {
        let json = """
        {
            "assistant_message": "Adding a new step.",
            "patchSet": {
                "patchSetId": "ps-1",
                "baseRecipeId": "r-1",
                "baseRecipeVersion": 1,
                "patches": [{"type": "add_step", "text": "Stir well", "after_step_id": null}]
            }
        }
        """
        let result = decoder.decode(json)
        guard let dto = expectSuccess(result, extractionUsed: false) else { return }
        guard case .addStep(let text, let afterStepId) = dto.patchSet?.patches[0] else {
            Issue.record("Expected addStep patch op")
            return
        }
        #expect(text == "Stir well")
        #expect(afterStepId == nil, "JSON null after_step_id must decode as nil")
    }
}

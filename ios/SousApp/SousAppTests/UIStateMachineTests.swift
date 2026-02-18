import XCTest
import SousCore
@testable import SousApp

// MARK: - Seed helpers

private extension UIStateMachineTests {

    // Stable UUIDs for deterministic tests
    static let recipeId   = UUID(uuidString: "00000000-0000-0000-FFFF-000000000001")!
    static let flourId    = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let saltId     = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let stepMixId  = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let stepBakeId = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!
    static let stepDoneId = UUID(uuidString: "00000000-0000-0000-0001-000000000003")!
    static let patchSetId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    /// A seed recipe with version 1 and stable IDs.
    static func seedRecipe() -> Recipe {
        Recipe(
            id: recipeId,
            version: 1,
            title: "Simple Bread",
            ingredients: [
                Ingredient(id: flourId, text: "2 cups flour"),
                Ingredient(id: saltId,  text: "1 tsp salt"),
            ],
            steps: [
                Step(id: stepMixId,  text: "Mix dry ingredients", status: .todo),
                Step(id: stepBakeId, text: "Bake at 375°F", status: .todo),
                Step(id: stepDoneId, text: "Let cool on rack",   status: .done),
            ],
            notes: []
        )
    }

    /// A PatchSet that adds a note — always valid against the seed recipe at version 1.
    static func validPatchSet() -> PatchSet {
        PatchSet(
            patchSetId: patchSetId,
            baseRecipeId: recipeId,
            baseRecipeVersion: 1,
            patches: [.addNote(text: "Knead for 10 minutes")]
        )
    }

    /// A PatchSet that tries to update a `done` step — always invalid.
    static func invalidPatchSet() -> PatchSet {
        PatchSet(
            patchSetId: patchSetId,
            baseRecipeId: recipeId,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: stepDoneId, text: "Changed done step")]
        )
    }
}

// MARK: - UIStateMachineTests

final class UIStateMachineTests: XCTestCase {

    // MARK: recipeOnly + openChat → chatOpen

    func test_recipeOnly_openChat_returnsChatOpen() {
        let recipe = Self.seedRecipe()
        let state = UIState.recipeOnly(recipe: recipe)

        let next = UIStateMachine.reduce(state, .openChat)

        guard case .chatOpen(let r, let draft, let hidden) = next else {
            return XCTFail("Expected chatOpen, got \(next)")
        }
        XCTAssertEqual(r, recipe)
        XCTAssertEqual(draft, "")
        XCTAssertEqual(hidden.entries, [])
    }

    // MARK: chatOpen + closeChat → recipeOnly

    func test_chatOpen_closeChat_returnsRecipeOnly() {
        let recipe = Self.seedRecipe()
        let state = UIState.chatOpen(recipe: recipe, draftUserText: "hello", hidden: HiddenContext())

        let next = UIStateMachine.reduce(state, .closeChat)

        guard case .recipeOnly(let r) = next else {
            return XCTFail("Expected recipeOnly, got \(next)")
        }
        XCTAssertEqual(r, recipe)
    }

    // MARK: chatOpen + patchReceived → patchProposed

    func test_chatOpen_patchReceived_returnsPatchProposed() {
        let recipe = Self.seedRecipe()
        let patchSet = Self.validPatchSet()
        let state = UIState.chatOpen(recipe: recipe, draftUserText: "add a note", hidden: HiddenContext())

        let next = UIStateMachine.reduce(state, .patchReceived(patchSet))

        guard case .patchProposed(let r, let ps, let validation, _) = next else {
            return XCTFail("Expected patchProposed, got \(next)")
        }
        XCTAssertEqual(r, recipe)
        XCTAssertEqual(ps, patchSet)
        XCTAssertNil(validation, "Validation should be nil until validatePatch is sent")
    }

    // MARK: patchProposed + validatePatch → patchReview (validation present)

    func test_patchProposed_validatePatch_returnsPatchReview_withValidResult() {
        let recipe = Self.seedRecipe()
        let patchSet = Self.validPatchSet()
        let state = UIState.patchProposed(recipe: recipe, patchSet: patchSet, validation: nil, hidden: HiddenContext())

        let next = UIStateMachine.reduce(state, .validatePatch)

        guard case .patchReview(let r, let ps, let validation, _) = next else {
            return XCTFail("Expected patchReview, got \(next)")
        }
        XCTAssertEqual(r, recipe)
        XCTAssertEqual(ps, patchSet)
        XCTAssertEqual(validation, .valid, "addNote patch against correct version should be valid")
    }

    func test_patchProposed_validatePatch_returnsPatchReview_withInvalidResult() {
        let recipe = Self.seedRecipe()
        let patchSet = Self.invalidPatchSet()
        let state = UIState.patchProposed(recipe: recipe, patchSet: patchSet, validation: nil, hidden: HiddenContext())

        let next = UIStateMachine.reduce(state, .validatePatch)

        guard case .patchReview(_, _, let validation, _) = next else {
            return XCTFail("Expected patchReview, got \(next)")
        }
        guard case .invalid(let errors) = validation else {
            return XCTFail("Expected invalid validation result")
        }
        XCTAssertTrue(errors.contains(.stepDoneImmutable(Self.stepDoneId)))
    }

    // MARK: patchReview(valid) + acceptPatch → recipeOnly (version incremented)

    func test_patchReview_validPatch_acceptPatch_returnsRecipeOnlyWithVersionIncrement() {
        let recipe = Self.seedRecipe()
        let patchSet = Self.validPatchSet()
        let state = UIState.patchReview(recipe: recipe, patchSet: patchSet, validation: .valid, hidden: HiddenContext())

        let next = UIStateMachine.reduce(state, .acceptPatch)

        guard case .recipeOnly(let updated) = next else {
            return XCTFail("Expected recipeOnly, got \(next)")
        }
        XCTAssertEqual(updated.version, recipe.version + 1)
        XCTAssertEqual(updated.id, recipe.id)
        XCTAssertTrue(updated.notes.contains("Knead for 10 minutes"))
    }

    // MARK: patchReview(invalid) + acceptPatch → stays in patchReview

    func test_patchReview_invalidPatch_acceptPatch_remainsInPatchReview() {
        let recipe = Self.seedRecipe()
        let patchSet = Self.invalidPatchSet()
        let errors: [PatchValidationError] = [.stepDoneImmutable(Self.stepDoneId)]
        let validation = PatchValidationResult.invalid(errors)
        let state = UIState.patchReview(recipe: recipe, patchSet: patchSet, validation: validation, hidden: HiddenContext())

        let next = UIStateMachine.reduce(state, .acceptPatch)

        guard case .patchReview(let r, let ps, let v, _) = next else {
            return XCTFail("Expected patchReview to persist for invalid patch, got \(next)")
        }
        XCTAssertEqual(r, recipe)
        XCTAssertEqual(ps, patchSet)
        XCTAssertEqual(v, validation)
    }

    // MARK: patchReview + rejectPatch → chatOpen with hidden PATCH_REJECTED + draft == userText

    func test_patchReview_rejectPatch_returnsChatOpenWithHiddenContextAndDraft() {
        let recipe = Self.seedRecipe()
        let patchSet = Self.validPatchSet()
        let state = UIState.patchReview(recipe: recipe, patchSet: patchSet, validation: .valid, hidden: HiddenContext())

        let next = UIStateMachine.reduce(state, .rejectPatch(userText: "nope"))

        guard case .chatOpen(let r, let draft, let hidden) = next else {
            return XCTFail("Expected chatOpen, got \(next)")
        }
        XCTAssertEqual(r, recipe)
        XCTAssertEqual(draft, "nope")
        XCTAssertEqual(hidden.entries.count, 1)
        XCTAssertTrue(
            hidden.entries[0].hasPrefix("PATCH_REJECTED:"),
            "Hidden entry should start with PATCH_REJECTED: but was '\(hidden.entries[0])'"
        )
        XCTAssertTrue(
            hidden.entries[0].contains(Self.patchSetId.uuidString),
            "Hidden entry should contain the patchSetId"
        )
    }

    // MARK: Hidden context accumulates across multiple rejections

    func test_hiddenContext_accumulates() {
        let ctx = HiddenContext(entries: ["PATCH_REJECTED: aaa"])
        let next = ctx.appending("PATCH_REJECTED: bbb")
        XCTAssertEqual(next.entries, ["PATCH_REJECTED: aaa", "PATCH_REJECTED: bbb"])
    }

    // MARK: LLMContextComposer — empty hidden returns plain userText

    func test_composer_emptyHidden_returnsPlainText() {
        let result = LLMContextComposer.composeUserMessage(
            userText: "make it spicier",
            hidden: HiddenContext()
        )
        XCTAssertEqual(result, "make it spicier")
    }

    // MARK: LLMContextComposer — non-empty hidden prepends SYSCTX block

    func test_composer_withHidden_prependsSysctxBlock() {
        let hidden = HiddenContext(entries: [
            "PATCH_REJECTED: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        ])
        let result = LLMContextComposer.composeUserMessage(
            userText: "try again",
            hidden: hidden
        )
        XCTAssertTrue(result.hasPrefix("[[SYSCTX]]"), "Should start with [[SYSCTX]] block")
        XCTAssertTrue(result.contains("[[/SYSCTX]]"), "Should contain closing [[/SYSCTX]] tag")
        XCTAssertTrue(result.contains("PATCH_REJECTED:"), "Should embed the rejection entry")
        XCTAssertTrue(result.hasSuffix("try again"), "User text should appear after the block")
    }

    // MARK: LLMContextComposer — multiple hidden entries joined by newlines

    func test_composer_multipleHiddenEntries_joinedByNewlines() {
        let hidden = HiddenContext(entries: ["entry1", "entry2"])
        let result = LLMContextComposer.composeUserMessage(userText: "hi", hidden: hidden)
        XCTAssertTrue(result.contains("entry1\nentry2"), "Entries should be newline-separated")
    }
}

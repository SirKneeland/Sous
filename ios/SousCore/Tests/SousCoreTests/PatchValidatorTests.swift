import Testing
import Foundation
@testable import SousCore

@Suite("PatchValidator")
struct PatchValidatorTests {

    // MARK: - Version mismatch

    @Test("Rejects patchSet with wrong baseRecipeVersion")
    func versionMismatch() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 99,
            patches: [.setTitle("hello")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.versionMismatch(expected: 1, got: 99)]))
    }

    @Test("Accepts patchSet with correct baseRecipeVersion")
    func versionMatch() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.setTitle("hello")]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    // MARK: - Invalid ingredient ID

    @Test("Rejects updateIngredient with unknown ID")
    func invalidIngredientIdOnUpdate() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateIngredient(id: badId, text: "new text")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidIngredientId(badId)]))
    }

    @Test("Rejects removeIngredient with unknown ID")
    func invalidIngredientIdOnRemove() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeIngredient(id: badId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidIngredientId(badId)]))
    }

    @Test("Rejects addIngredient with unknown afterId in specified group")
    func invalidIngredientIdOnAddAfter() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: SeedRecipes.ingredientGroupId, afterId: badId, text: "yeast")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidIngredientId(badId)]))
    }

    @Test("Accepts addIngredient with nil groupId and nil afterId (append to first group)")
    func addIngredientNoAfterId() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: nil, afterId: nil, text: "yeast")]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    // MARK: - Invalid ingredient group ID

    @Test("Rejects addIngredient with unknown groupId")
    func invalidIngredientGroupIdOnAdd() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: badId, afterId: nil, text: "yeast")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidIngredientGroupId(badId)]))
    }

    @Test("Rejects updateIngredientGroup with unknown ID")
    func invalidIngredientGroupIdOnUpdate() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateIngredientGroup(id: badId, header: "Spices")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidIngredientGroupId(badId)]))
    }

    @Test("Rejects removeIngredientGroup with unknown ID")
    func invalidIngredientGroupIdOnRemove() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeIngredientGroup(id: badId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidIngredientGroupId(badId)]))
    }

    // MARK: - Invalid step ID

    @Test("Rejects updateStep with unknown ID")
    func invalidStepIdOnUpdate() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: badId, text: "new")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    @Test("Rejects addStep with unknown afterId at top level")
    func invalidStepIdOnAddAfter() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(parentId: nil, afterId: badId, text: "new step", preassignedId: nil)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    @Test("Rejects addStep with unknown parentId")
    func invalidStepIdOnAddWithParent() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(parentId: badId, afterId: nil, text: "sub step", preassignedId: nil)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    // MARK: - Done step immutability

    @Test("Rejects updateStep on a done step")
    func stepDoneImmutable() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: SeedRecipes.stepDoneId, text: "changed")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.stepDoneImmutable(SeedRecipes.stepDoneId)]))
    }

    @Test("Accepts updateStep on a todo step")
    func stepTodoMutable() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: SeedRecipes.stepMixId, text: "Mix all ingredients")]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    // MARK: - setStepNotes

    @Test("Accepts setStepNotes on a todo step")
    func setStepNotesValid() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.setStepNotes(stepId: SeedRecipes.stepMixId, notes: ["Use a fork"])]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Rejects setStepNotes on a done step")
    func setStepNotesDoneImmutable() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.setStepNotes(stepId: SeedRecipes.stepDoneId, notes: ["note"])]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.stepDoneImmutable(SeedRecipes.stepDoneId)]))
    }

    @Test("Rejects setStepNotes with unknown step ID")
    func setStepNotesInvalidStepId() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.setStepNotes(stepId: badId, notes: [])]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    // MARK: - Note section operations

    @Test("Accepts addNoteSection always")
    func addNoteSectionAlwaysValid() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addNoteSection(afterId: nil, header: "Tips", items: ["Item 1"])]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Rejects updateNoteSection with unknown ID")
    func invalidNoteSectionIdOnUpdate() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateNoteSection(id: badId, header: nil, items: [])]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidNoteSectionId(badId)]))
    }

    @Test("Rejects removeNoteSection with unknown ID")
    func invalidNoteSectionIdOnRemove() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeNoteSection(id: badId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidNoteSectionId(badId)]))
    }

    // MARK: - Multiple errors

    @Test("Collects multiple errors in one pass")
    func multipleErrors() {
        let recipe = SeedRecipes.sample()
        let badIngredientId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 99,
            patches: [
                .updateIngredient(id: badIngredientId, text: "x"),
                .updateStep(id: SeedRecipes.stepDoneId, text: "x"),
            ]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        guard case .invalid(let errors) = result else {
            Issue.record("Expected invalid result")
            return
        }
        #expect(errors.contains(.versionMismatch(expected: 1, got: 99)))
        #expect(errors.contains(.invalidIngredientId(badIngredientId)))
        #expect(errors.contains(.stepDoneImmutable(SeedRecipes.stepDoneId)))
    }

    // MARK: - removeStep validation

    @Test("Rejects removeStep with unknown ID")
    func invalidStepIdOnRemove() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeStep(id: badId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    @Test("Rejects removeStep on a done step")
    func removeStepDoneImmutable() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeStep(id: SeedRecipes.stepDoneId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.stepDoneImmutable(SeedRecipes.stepDoneId)]))
    }

    @Test("Accepts removeStep on a todo step")
    func removeStepTodoValid() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeStep(id: SeedRecipes.stepMixId)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Detects internal conflict: update after removeStep in same patchSet")
    func internalConflictRemoveStepThenUpdate() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [
                .removeStep(id: SeedRecipes.stepMixId),
                .updateStep(id: SeedRecipes.stepMixId, text: "Should fail"),
            ]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result != .valid)
    }

    // MARK: - Internal conflict (remove then use)

    @Test("Detects internal conflict: update after remove in same patchSet")
    func internalConflictRemoveThenUpdate() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [
                .removeIngredient(id: SeedRecipes.ingredientSaltId),
                .updateIngredient(id: SeedRecipes.ingredientSaltId, text: "2 tsp salt"),
            ]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result != .valid)
    }

    // MARK: - Recursive tree search for steps

    @Test("Finds step at any depth for updateStep")
    func updateStepRecursiveSearch() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: SeedRecipes.subStepAId, text: "Measure 2 cups")]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Finds step at any depth for removeStep")
    func removeStepRecursiveSearch() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeStep(id: SeedRecipes.subStepBId)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    // MARK: - Hard-avoid violations

    @Test("Rejects addIngredient whose text contains a hard-avoid keyword")
    func hardAvoidOnAddIngredient() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: nil, afterId: nil, text: "200g shrimp, peeled")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: ["shellfish", "shrimp"])
        #expect(result == .invalid([.hardAvoidViolation(ingredient: "shrimp")]))
    }

    @Test("Rejects addIngredient matching hard-avoid by case-insensitive substring")
    func hardAvoidCaseInsensitive() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: nil, afterId: nil, text: "1 cup Peanut Butter")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: ["peanut"])
        #expect(result == .invalid([.hardAvoidViolation(ingredient: "peanut")]))
    }

    @Test("Rejects updateIngredient whose new text contains a hard-avoid keyword")
    func hardAvoidOnUpdateIngredient() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateIngredient(id: SeedRecipes.ingredientSaltId, text: "1 tsp shrimp paste")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: ["shrimp"])
        #expect(result == .invalid([.hardAvoidViolation(ingredient: "shrimp")]))
    }

    @Test("Rejects addStep whose text contains a hard-avoid keyword")
    func hardAvoidOnAddStep() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(parentId: nil, afterId: nil, text: "Toss in shrimp and cook 2 minutes", preassignedId: nil)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: ["shrimp"])
        #expect(result == .invalid([.hardAvoidViolation(ingredient: "shrimp")]))
    }

    @Test("Rejects updateStep whose text contains a hard-avoid keyword")
    func hardAvoidOnUpdateStep() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: SeedRecipes.stepMixId, text: "Mix dry ingredients and fold in shrimp")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: ["shrimp"])
        #expect(result == .invalid([.hardAvoidViolation(ingredient: "shrimp")]))
    }

    @Test("Accepts patches when hardAvoids is empty")
    func hardAvoidEmptyListAllowsAll() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: nil, afterId: nil, text: "200g shrimp")]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: []) == .valid)
    }

    @Test("Accepts patches when text does not contain any hard-avoid keyword")
    func hardAvoidNoMatch() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: nil, afterId: nil, text: "fresh thyme")]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: ["shellfish", "peanuts"]) == .valid)
    }
}

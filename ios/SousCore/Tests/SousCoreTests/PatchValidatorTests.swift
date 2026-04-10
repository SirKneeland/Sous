import Testing
import Foundation
@testable import SousCore

@Suite("PatchValidator")
struct PatchValidatorTests {

    // MARK: - Version mismatch

    @Test("Rejects patchSet with wrong baseRecipeVersion")
    func versionMismatch() {
        let recipe = SeedRecipes.sample() // version 1
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 99,
            patches: [.addNote(text: "hello")]
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
            patches: [.addNote(text: "hello")]
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

    @Test("Rejects addIngredient with unknown afterId")
    func invalidIngredientIdOnAddAfter() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(text: "yeast", afterId: badId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidIngredientId(badId)]))
    }

    @Test("Accepts addIngredient with nil afterId (append)")
    func addIngredientNoAfterId() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(text: "yeast", afterId: nil)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
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

    @Test("Rejects addStep with unknown afterStepId")
    func invalidStepIdOnAddAfter() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(text: "new step", afterStepId: badId, preassignedId: nil)]
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

    // MARK: - Multiple errors

    @Test("Collects multiple errors in one pass")
    func multipleErrors() {
        let recipe = SeedRecipes.sample()
        let badIngredientId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 99,          // version mismatch
            patches: [
                .updateIngredient(id: badIngredientId, text: "x"),  // invalid ingredient
                .updateStep(id: SeedRecipes.stepDoneId, text: "x"), // done step
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

    // MARK: - Sub-step operations

    @Test("Accepts addSubStep with valid parent and nil afterSubStepId")
    func addSubStepValidParent() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addSubStep(parentStepId: SeedRecipes.stepMixId, text: "Sift flour", afterSubStepId: nil)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Accepts addSubStep with valid afterSubStepId")
    func addSubStepValidAfterSubStepId() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addSubStep(parentStepId: SeedRecipes.stepMixId, text: "Sift flour", afterSubStepId: SeedRecipes.subStepAId)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Rejects addSubStep with unknown parent step ID")
    func addSubStepInvalidParent() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addSubStep(parentStepId: badId, text: "Sift flour", afterSubStepId: nil)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    @Test("Rejects addSubStep with unknown afterSubStepId")
    func addSubStepInvalidAfterSubStepId() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let badSubId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addSubStep(parentStepId: SeedRecipes.stepMixId, text: "Sift flour", afterSubStepId: badSubId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidSubStepId(badSubId)]))
    }

    @Test("Accepts updateSubStep with valid parent and substep")
    func updateSubStepValid() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateSubStep(parentStepId: SeedRecipes.stepMixId, subStepId: SeedRecipes.subStepAId, text: "Measure 2 cups flour")]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Rejects updateSubStep with unknown parent step ID")
    func updateSubStepInvalidParent() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateSubStep(parentStepId: badId, subStepId: SeedRecipes.subStepAId, text: "x")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    @Test("Rejects updateSubStep with unknown substep ID")
    func updateSubStepInvalidSubStepId() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let badSubId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateSubStep(parentStepId: SeedRecipes.stepMixId, subStepId: badSubId, text: "x")]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidSubStepId(badSubId)]))
    }

    @Test("Accepts removeSubStep with valid parent and substep")
    func removeSubStepValid() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeSubStep(parentStepId: SeedRecipes.stepMixId, subStepId: SeedRecipes.subStepAId)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Rejects removeSubStep with unknown parent step ID")
    func removeSubStepInvalidParent() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeSubStep(parentStepId: badId, subStepId: SeedRecipes.subStepAId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    @Test("Rejects removeSubStep with unknown substep ID")
    func removeSubStepInvalidSubStepId() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let badSubId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeSubStep(parentStepId: SeedRecipes.stepMixId, subStepId: badSubId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidSubStepId(badSubId)]))
    }

    @Test("Detects internal conflict: update substep after remove in same patchSet")
    func removeSubStepThenUpdateConflict() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [
                .removeSubStep(parentStepId: SeedRecipes.stepMixId, subStepId: SeedRecipes.subStepAId),
                .updateSubStep(parentStepId: SeedRecipes.stepMixId, subStepId: SeedRecipes.subStepAId, text: "Should fail"),
            ]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) != .valid)
    }

    @Test("Accepts completeSubStep with valid parent and incomplete substep")
    func completeSubStepValid() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.completeSubStep(parentStepId: SeedRecipes.stepMixId, subStepId: SeedRecipes.subStepAId)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe) == .valid)
    }

    @Test("Rejects completeSubStep with unknown parent step ID")
    func completeSubStepInvalidParent() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.completeSubStep(parentStepId: badId, subStepId: SeedRecipes.subStepAId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidStepId(badId)]))
    }

    @Test("Rejects completeSubStep with unknown substep ID")
    func completeSubStepInvalidSubStepId() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let badSubId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.completeSubStep(parentStepId: SeedRecipes.stepMixId, subStepId: badSubId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.invalidSubStepId(badSubId)]))
    }

    // MARK: - Hard-avoid violations

    @Test("Rejects addIngredient whose text contains a hard-avoid keyword")
    func hardAvoidOnAddIngredient() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(text: "200g shrimp, peeled", afterId: nil)]
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
            patches: [.addIngredient(text: "1 cup Peanut Butter", afterId: nil)]
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
            patches: [.addStep(text: "Toss in shrimp and cook 2 minutes", afterStepId: nil, preassignedId: nil)]
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

    @Test("Rejects addSubStep whose text contains a hard-avoid keyword")
    func hardAvoidOnAddSubStep() {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addSubStep(parentStepId: SeedRecipes.stepMixId, text: "Stir in shrimp", afterSubStepId: nil)]
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
            patches: [.addIngredient(text: "200g shrimp", afterId: nil)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: []) == .valid)
    }

    @Test("Accepts patches when text does not contain any hard-avoid keyword")
    func hardAvoidNoMatch() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(text: "fresh thyme", afterId: nil)]
        )
        #expect(PatchValidator.validate(patchSet: patchSet, recipe: recipe, hardAvoids: ["shellfish", "peanuts"]) == .valid)
    }

    @Test("Rejects completeSubStep when parent step is already done")
    func completeSubStepParentAlreadyDone() {
        // stepDoneId in sampleWithSubSteps has one sub-step that is done,
        // making the parent's effectiveStatus == .done.
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.completeSubStep(parentStepId: SeedRecipes.stepDoneId, subStepId: SeedRecipes.subStepDoneId)]
        )
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        #expect(result == .invalid([.parentStepDone(SeedRecipes.stepDoneId)]))
    }
}

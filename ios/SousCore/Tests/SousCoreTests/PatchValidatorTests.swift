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
            patches: [.addStep(text: "new step", afterStepId: badId)]
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
}

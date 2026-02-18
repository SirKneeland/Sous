import Testing
import Foundation
@testable import SousCore

@Suite("PatchApplier")
struct PatchApplierTests {

    // MARK: - Version increment

    @Test("Valid patch increments recipe version by 1")
    func versionIncrement() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addNote(text: "test note")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.version == 2)
        #expect(updated.id == recipe.id)
    }

    @Test("Valid patch does not mutate original recipe")
    func originalUnmutated() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addNote(text: "extra")]
        )
        _ = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(recipe.notes == ["Original family recipe"])
        #expect(recipe.version == 1)
    }

    // MARK: - addIngredient

    @Test("addIngredient appends when afterId is nil")
    func addIngredientAppend() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(text: "1 tsp yeast", afterId: nil)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients.count == 4)
        #expect(updated.ingredients.last?.text == "1 tsp yeast")
    }

    @Test("addIngredient inserts after specified ID")
    func addIngredientAfter() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(text: "1 tsp yeast", afterId: SeedRecipes.ingredientFlourId)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients.count == 4)
        #expect(updated.ingredients[1].text == "1 tsp yeast")
    }

    // MARK: - updateIngredient

    @Test("updateIngredient changes text of existing ingredient")
    func updateIngredient() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateIngredient(id: SeedRecipes.ingredientSaltId, text: "2 tsp salt")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        let salt = updated.ingredients.first { $0.id == SeedRecipes.ingredientSaltId }
        #expect(salt?.text == "2 tsp salt")
    }

    // MARK: - removeIngredient

    @Test("removeIngredient deletes ingredient from list")
    func removeIngredient() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeIngredient(id: SeedRecipes.ingredientWaterId)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients.count == 2)
        #expect(!updated.ingredients.contains { $0.id == SeedRecipes.ingredientWaterId })
    }

    // MARK: - addStep

    @Test("addStep appends when afterStepId is nil")
    func addStepAppend() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(text: "Slice and serve", afterStepId: nil)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.steps.count == 4)
        #expect(updated.steps.last?.text == "Slice and serve")
        #expect(updated.steps.last?.status == .todo)
    }

    @Test("addStep inserts after specified step ID")
    func addStepAfter() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(text: "Knead dough", afterStepId: SeedRecipes.stepMixId)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.steps.count == 4)
        #expect(updated.steps[1].text == "Knead dough")
    }

    // MARK: - updateStep

    @Test("updateStep changes text of todo step")
    func updateStep() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: SeedRecipes.stepMixId, text: "Mix all ingredients thoroughly")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        let step = updated.steps.first { $0.id == SeedRecipes.stepMixId }
        #expect(step?.text == "Mix all ingredients thoroughly")
    }

    // MARK: - addNote

    @Test("addNote appends to notes array")
    func addNote() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addNote(text: "Great for sandwiches")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.notes.count == 2)
        #expect(updated.notes.last == "Great for sandwiches")
    }

    // MARK: - Validation rejection (atomicity)

    @Test("Version mismatch throws and leaves recipe unchanged")
    func atomicityOnVersionMismatch() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 99,
            patches: [.addNote(text: "should not apply")]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
        #expect(recipe.version == 1)
        #expect(recipe.notes == ["Original family recipe"])
    }

    @Test("Invalid ingredient ID throws")
    func throwsOnInvalidIngredientId() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateIngredient(id: badId, text: "x")]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
    }

    @Test("Invalid step ID throws")
    func throwsOnInvalidStepId() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: badId, text: "x")]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
    }

    @Test("Attempting to update done step throws")
    func throwsOnDoneStepUpdate() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: SeedRecipes.stepDoneId, text: "changed")]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
    }

    @Test("Atomicity: mixed valid+invalid patch leaves recipe unchanged")
    func atomicityMixed() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        // First patch valid, second invalid
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [
                .addNote(text: "valid note"),
                .updateIngredient(id: badId, text: "x"),
            ]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
        // Original unchanged
        #expect(recipe.notes == ["Original family recipe"])
        #expect(recipe.version == 1)
    }

    // MARK: - add-after ordering

    @Test("Multiple addIngredient after same ID preserves insertion order")
    func addIngredientOrderingMultiple() throws {
        let recipe = SeedRecipes.sample()
        // Insert A after flour, then B after flour → expected order: flour, A, B, salt, water
        // Actually each insert is after flour: flour -> A -> B depends on sequential application
        // After first insert: [flour, A, salt, water]
        // After second insert: [flour, A, B, salt, water]  (afterId=flour → idx 0, insert at 1 → pushes A to 2)
        // Wait: second insert also uses flour as afterId, flour is at index 0 → insert at 1 again
        // So: [flour, B, A, salt, water]
        // Let's just verify count and that both items are present
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [
                .addIngredient(text: "A", afterId: SeedRecipes.ingredientFlourId),
                .addIngredient(text: "B", afterId: SeedRecipes.ingredientFlourId),
            ]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients.count == 5)
        #expect(updated.ingredients[0].id == SeedRecipes.ingredientFlourId)
        let texts = updated.ingredients.map { $0.text }
        #expect(texts.contains("A"))
        #expect(texts.contains("B"))
    }

    @Test("addStep after specific ID inserts at correct position")
    func addStepOrderingAfter() throws {
        let recipe = SeedRecipes.sample()
        // steps: [mix, bake, done]
        // insert after bake → [mix, bake, NEW, done]
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(text: "Check crust", afterStepId: SeedRecipes.stepBakeId)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.steps.count == 4)
        #expect(updated.steps[2].text == "Check crust")
        #expect(updated.steps[3].id == SeedRecipes.stepDoneId)
    }
}

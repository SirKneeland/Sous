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
            patches: [.setTitle("Test Title")]
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
            patches: [.setTitle("New Title")]
        )
        _ = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(recipe.title == "Simple Bread")
        #expect(recipe.version == 1)
    }

    // MARK: - addIngredient

    @Test("addIngredient appends to first group when groupId is nil")
    func addIngredientAppend() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: nil, afterId: nil, text: "1 tsp yeast")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients[0].items.count == 4)
        #expect(updated.ingredients[0].items.last?.text == "1 tsp yeast")
    }

    @Test("addIngredient inserts after specified ID within group")
    func addIngredientAfter() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredient(groupId: SeedRecipes.ingredientGroupId, afterId: SeedRecipes.ingredientFlourId, text: "1 tsp yeast")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients[0].items.count == 4)
        #expect(updated.ingredients[0].items[1].text == "1 tsp yeast")
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
        let salt = updated.ingredients.flatMap { $0.items }.first { $0.id == SeedRecipes.ingredientSaltId }
        #expect(salt?.text == "2 tsp salt")
    }

    // MARK: - removeIngredient

    @Test("removeIngredient deletes ingredient from its group")
    func removeIngredient() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeIngredient(id: SeedRecipes.ingredientWaterId)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients[0].items.count == 2)
        #expect(!updated.ingredients[0].items.contains { $0.id == SeedRecipes.ingredientWaterId })
    }

    // MARK: - addIngredientGroup

    @Test("addIngredientGroup appends new group")
    func addIngredientGroupAppend() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredientGroup(afterGroupId: nil, header: "Spices", preassignedId: nil)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients.count == 2)
        #expect(updated.ingredients.last?.header == "Spices")
        #expect(updated.ingredients.last?.items.isEmpty == true)
    }

    @Test("addIngredientGroup inserts after specified group")
    func addIngredientGroupAfter() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addIngredientGroup(afterGroupId: SeedRecipes.ingredientGroupId, header: "Spices", preassignedId: nil)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients.count == 2)
        #expect(updated.ingredients[1].header == "Spices")
    }

    // MARK: - updateIngredientGroup

    @Test("updateIngredientGroup changes header of group")
    func updateIngredientGroup() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateIngredientGroup(id: SeedRecipes.ingredientGroupId, header: "Dry Ingredients")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        let group = updated.ingredients.first { $0.id == SeedRecipes.ingredientGroupId }
        #expect(group?.header == "Dry Ingredients")
    }

    // MARK: - removeIngredientGroup

    @Test("removeIngredientGroup removes the group and all its items")
    func removeIngredientGroup() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeIngredientGroup(id: SeedRecipes.ingredientGroupId)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients.isEmpty)
    }

    // MARK: - addStep

    @Test("addStep appends when afterId is nil")
    func addStepAppend() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(parentId: nil, afterId: nil, text: "Slice and serve", preassignedId: nil)]
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
            patches: [.addStep(parentId: nil, afterId: SeedRecipes.stepMixId, text: "Knead dough", preassignedId: nil)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.steps.count == 4)
        #expect(updated.steps[1].text == "Knead dough")
    }

    @Test("addStep with parentId inserts as sub-step")
    func addStepWithParent() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(parentId: SeedRecipes.stepMixId, afterId: nil, text: "Sift flour", preassignedId: nil)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        let parent = updated.steps.first { $0.id == SeedRecipes.stepMixId }
        #expect(parent?.subSteps?.count == 1)
        #expect(parent?.subSteps?.first?.text == "Sift flour")
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

    @Test("updateStep finds step at any depth in the tree")
    func updateStepRecursive() throws {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.updateStep(id: SeedRecipes.subStepAId, text: "Measure 2.5 cups flour")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        let parent = updated.steps.first { $0.id == SeedRecipes.stepMixId }
        let sub = parent?.subSteps?.first { $0.id == SeedRecipes.subStepAId }
        #expect(sub?.text == "Measure 2.5 cups flour")
    }

    // MARK: - removeStep

    @Test("removeStep deletes a todo step from the list")
    func removeStep() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeStep(id: SeedRecipes.stepMixId)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.steps.count == 2)
        #expect(!updated.steps.contains { $0.id == SeedRecipes.stepMixId })
    }

    @Test("removeStep with unknown ID throws")
    func removeStepUnknownIdThrows() {
        let recipe = SeedRecipes.sample()
        let badId = UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeStep(id: badId)]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
    }

    @Test("removeStep on done step throws")
    func removeStepDoneThrows() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeStep(id: SeedRecipes.stepDoneId)]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
    }

    @Test("removeStep removes sub-step from tree")
    func removeSubStepFromTree() throws {
        let recipe = SeedRecipes.sampleWithSubSteps()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.removeStep(id: SeedRecipes.subStepAId)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        let parent = updated.steps.first { $0.id == SeedRecipes.stepMixId }
        #expect(parent?.subSteps?.count == 1)
        #expect(parent?.subSteps?.contains { $0.id == SeedRecipes.subStepAId } == false)
    }

    // MARK: - setStepNotes

    @Test("setStepNotes sets notes on matching step")
    func setStepNotes() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.setStepNotes(stepId: SeedRecipes.stepMixId, notes: ["Use a wooden spoon", "Don't overmix"])]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        let step = updated.steps.first { $0.id == SeedRecipes.stepMixId }
        #expect(step?.notes == ["Use a wooden spoon", "Don't overmix"])
    }

    // MARK: - addNoteSection

    @Test("addNoteSection appends to notes array")
    func addNoteSection() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addNoteSection(afterId: nil, header: "Tips", items: ["Great for sandwiches"])]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.notes?.count == 1)
        #expect(updated.notes?.first?.header == "Tips")
        #expect(updated.notes?.first?.items == ["Great for sandwiches"])
    }

    // MARK: - Validation rejection (atomicity)

    @Test("Version mismatch throws and leaves recipe unchanged")
    func atomicityOnVersionMismatch() {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 99,
            patches: [.setTitle("should not apply")]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
        #expect(recipe.version == 1)
        #expect(recipe.title == "Simple Bread")
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
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [
                .addNoteSection(afterId: nil, header: nil, items: ["valid note"]),
                .updateIngredient(id: badId, text: "x"),
            ]
        )
        #expect(throws: PatchApplierError.self) {
            try PatchApplier.apply(patchSet: patchSet, to: recipe)
        }
        #expect(recipe.notes == nil)
        #expect(recipe.version == 1)
    }

    // MARK: - add-after ordering

    @Test("Multiple addIngredient after same ID preserves insertion order")
    func addIngredientOrderingMultiple() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [
                .addIngredient(groupId: SeedRecipes.ingredientGroupId, afterId: SeedRecipes.ingredientFlourId, text: "A"),
                .addIngredient(groupId: SeedRecipes.ingredientGroupId, afterId: SeedRecipes.ingredientFlourId, text: "B"),
            ]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients[0].items.count == 5)
        #expect(updated.ingredients[0].items[0].id == SeedRecipes.ingredientFlourId)
        let texts = updated.ingredients[0].items.map { $0.text }
        #expect(texts.contains("A"))
        #expect(texts.contains("B"))
    }

    @Test("addStep after specific ID inserts at correct position")
    func addStepOrderingAfter() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.addStep(parentId: nil, afterId: SeedRecipes.stepBakeId, text: "Check crust", preassignedId: nil)]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.steps.count == 4)
        #expect(updated.steps[2].text == "Check crust")
        #expect(updated.steps[3].id == SeedRecipes.stepDoneId)
    }

    // MARK: - setTitle

    @Test("setTitle updates recipe title and increments version")
    func setTitleUpdatesTitle() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.setTitle("Garlic Pasta")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.title == "Garlic Pasta")
        #expect(updated.version == 2)
        #expect(updated.id == recipe.id)
    }

    @Test("setTitle does not affect ingredients, steps, or notes")
    func setTitleDoesNotAffectOtherFields() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: 1,
            patches: [.setTitle("New Name")]
        )
        let updated = try PatchApplier.apply(patchSet: patchSet, to: recipe)
        #expect(updated.ingredients == recipe.ingredients)
        #expect(updated.steps == recipe.steps)
        #expect(updated.notes == recipe.notes)
    }
}

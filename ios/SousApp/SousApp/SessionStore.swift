import Combine
import Foundation
import SousCore

@MainActor
final class SessionStore: ObservableObject {
    @Published var recipe: Recipe?
    @Published var pendingPatchSet: PatchSet?
    @Published var validationResult: PatchValidationResult?

    // Stable UUIDs matching SousCore test fixtures
    private static let ingredientFlourId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let ingredientSaltId  = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let ingredientWaterId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private static let stepMixId  = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    private static let stepBakeId = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!
    private static let stepDoneId = UUID(uuidString: "00000000-0000-0000-0001-000000000003")!
    private static let recipeId   = UUID(uuidString: "00000000-0000-0000-FFFF-000000000001")!

    func loadSeedRecipe() {
        recipe = Recipe(
            id: Self.recipeId,
            version: 1,
            title: "Simple Bread",
            ingredients: [
                Ingredient(id: Self.ingredientFlourId, text: "2 cups flour"),
                Ingredient(id: Self.ingredientSaltId,  text: "1 tsp salt"),
                Ingredient(id: Self.ingredientWaterId, text: "3/4 cup water"),
            ],
            steps: [
                Step(id: Self.stepMixId,  text: "Mix dry ingredients", status: .todo),
                Step(id: Self.stepBakeId, text: "Bake at 375°F for 30 min", status: .todo),
                Step(id: Self.stepDoneId, text: "Let cool on rack", status: .done),
            ],
            notes: ["Original family recipe"]
        )
        pendingPatchSet = nil
        validationResult = nil
    }

    func injectValidPatch() {
        guard let recipe else { return }
        pendingPatchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [.addNote(text: "From UI")]
        )
        validationResult = nil
    }

    func injectInvalidPatch() {
        guard let recipe else { return }
        pendingPatchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [.updateIngredient(id: UUID(), text: "ghost ingredient")]
        )
        validationResult = nil
    }

    func validate() {
        guard let recipe, let pendingPatchSet else { return }
        validationResult = PatchValidator.validate(patchSet: pendingPatchSet, recipe: recipe)
    }

    func apply() {
        guard let recipe, let pendingPatchSet else { return }
        do {
            self.recipe = try PatchApplier.apply(patchSet: pendingPatchSet, to: recipe)
            self.pendingPatchSet = nil
            self.validationResult = nil
        } catch {
            self.validationResult = .invalid([])
        }
    }
}

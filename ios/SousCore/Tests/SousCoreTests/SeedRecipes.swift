import Foundation
@testable import SousCore

enum SeedRecipes {
    static let ingredientFlourId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let ingredientSaltId  = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let ingredientWaterId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    static let stepMixId  = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let stepBakeId = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!
    static let stepDoneId = UUID(uuidString: "00000000-0000-0000-0001-000000000003")!

    static let recipeId = UUID(uuidString: "00000000-0000-0000-FFFF-000000000001")!

    /// A simple bread recipe with known stable IDs for use in tests.
    static func sample() -> Recipe {
        Recipe(
            id: recipeId,
            version: 1,
            title: "Simple Bread",
            ingredients: [
                Ingredient(id: ingredientFlourId, text: "2 cups flour"),
                Ingredient(id: ingredientSaltId,  text: "1 tsp salt"),
                Ingredient(id: ingredientWaterId, text: "3/4 cup water"),
            ],
            steps: [
                Step(id: stepMixId,  text: "Mix dry ingredients", status: .todo),
                Step(id: stepBakeId, text: "Bake at 375°F for 30 min", status: .todo),
                Step(id: stepDoneId, text: "Let cool on rack", status: .done),
            ],
            notes: ["Original family recipe"]
        )
    }
}

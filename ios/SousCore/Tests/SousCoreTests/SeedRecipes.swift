import Foundation
@testable import SousCore

enum SeedRecipes {
    static let ingredientGroupId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    static let ingredientFlourId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let ingredientSaltId  = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let ingredientWaterId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    static let stepMixId  = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let stepBakeId = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!
    static let stepDoneId = UUID(uuidString: "00000000-0000-0000-0001-000000000003")!

    // Sub-step IDs used in sampleWithSubSteps()
    static let subStepAId = UUID(uuidString: "00000000-0000-0000-0002-000000000001")!
    static let subStepBId = UUID(uuidString: "00000000-0000-0000-0002-000000000002")!
    static let subStepDoneId = UUID(uuidString: "00000000-0000-0000-0002-000000000003")!

    static let recipeId = UUID(uuidString: "00000000-0000-0000-FFFF-000000000001")!

    /// A simple bread recipe where stepMixId has two sub-steps (A = todo, B = todo)
    /// and stepDoneId has one sub-step that is done (making the parent done by derivation).
    static func sampleWithSubSteps() -> Recipe {
        Recipe(
            id: recipeId,
            version: 1,
            title: "Simple Bread",
            ingredients: [
                IngredientGroup(id: ingredientGroupId, header: nil, items: [
                    Ingredient(id: ingredientFlourId, text: "2 cups flour"),
                    Ingredient(id: ingredientSaltId,  text: "1 tsp salt"),
                    Ingredient(id: ingredientWaterId, text: "3/4 cup water"),
                ]),
            ],
            steps: [
                Step(id: stepMixId, text: "Mix dry ingredients", status: .todo, subSteps: [
                    Step(id: subStepAId, text: "Measure flour", status: .todo),
                    Step(id: subStepBId, text: "Add salt", status: .todo),
                ]),
                Step(id: stepBakeId, text: "Bake at 375°F for 30 min", status: .todo),
                Step(id: stepDoneId, text: "Let cool on rack", status: .todo, subSteps: [
                    Step(id: subStepDoneId, text: "Place on rack", status: .done),
                ]),
            ]
        )
    }

    /// A simple bread recipe with known stable IDs for use in tests.
    static func sample() -> Recipe {
        Recipe(
            id: recipeId,
            version: 1,
            title: "Simple Bread",
            ingredients: [
                IngredientGroup(id: ingredientGroupId, header: nil, items: [
                    Ingredient(id: ingredientFlourId, text: "2 cups flour"),
                    Ingredient(id: ingredientSaltId,  text: "1 tsp salt"),
                    Ingredient(id: ingredientWaterId, text: "3/4 cup water"),
                ]),
            ],
            steps: [
                Step(id: stepMixId,  text: "Mix dry ingredients", status: .todo),
                Step(id: stepBakeId, text: "Bake at 375°F for 30 min", status: .todo),
                Step(id: stepDoneId, text: "Let cool on rack", status: .done),
            ]
        )
    }
}

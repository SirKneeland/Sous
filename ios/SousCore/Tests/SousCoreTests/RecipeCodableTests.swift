import XCTest
@testable import SousCore

final class RecipeCodableTests: XCTestCase {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - StepStatus

    func test_stepStatus_todo_roundTrip() throws {
        XCTAssertEqual(try roundTrip(StepStatus.todo), .todo)
    }

    func test_stepStatus_done_roundTrip() throws {
        XCTAssertEqual(try roundTrip(StepStatus.done), .done)
    }

    func test_stepStatus_unknownValue_throwsDecodingError() throws {
        let json = #""cooking""#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(StepStatus.self, from: json))
    }

    // MARK: - Ingredient

    func test_ingredient_roundTrip() throws {
        let ingredient = Ingredient(id: SeedRecipes.ingredientFlourId, text: "2 cups flour")
        XCTAssertEqual(try roundTrip(ingredient), ingredient)
    }

    // MARK: - Step

    func test_step_roundTrip_todo() throws {
        let step = Step(id: SeedRecipes.stepMixId, text: "Mix dry ingredients", status: .todo)
        XCTAssertEqual(try roundTrip(step), step)
    }

    func test_step_roundTrip_done() throws {
        let step = Step(id: SeedRecipes.stepDoneId, text: "Cool on rack", status: .done)
        XCTAssertEqual(try roundTrip(step), step)
    }

    func test_step_preservesDoneStatus() throws {
        let step = Step(id: UUID(), text: "Done step", status: .done)
        let decoded = try roundTrip(step)
        XCTAssertEqual(decoded.status, .done, "Done step status must survive round-trip")
    }

    // MARK: - Recipe

    func test_recipe_roundTrip_full() throws {
        let recipe = SeedRecipes.sample()
        XCTAssertEqual(try roundTrip(recipe), recipe)
    }

    func test_recipe_preservesDoneStepAfterRoundTrip() throws {
        let recipe = SeedRecipes.sample()
        let decoded = try roundTrip(recipe)
        let doneStep = decoded.steps.first { $0.id == SeedRecipes.stepDoneId }
        XCTAssertEqual(doneStep?.status, .done,
                       "Done step status must be preserved through serialisation")
    }

    func test_recipe_preservesVersion() throws {
        var recipe = SeedRecipes.sample()
        recipe.version = 42
        XCTAssertEqual(try roundTrip(recipe), recipe)
        XCTAssertEqual((try roundTrip(recipe)).version, 42)
    }

    func test_recipe_preservesNotes() throws {
        let recipe = SeedRecipes.sample()
        let decoded = try roundTrip(recipe)
        XCTAssertEqual(decoded.notes, recipe.notes)
    }

    func test_recipe_preservesIngredientOrder() throws {
        let recipe = SeedRecipes.sample()
        let decoded = try roundTrip(recipe)
        XCTAssertEqual(decoded.ingredients.map(\.id), recipe.ingredients.map(\.id))
    }

    func test_recipe_preservesStepOrder() throws {
        let recipe = SeedRecipes.sample()
        let decoded = try roundTrip(recipe)
        XCTAssertEqual(decoded.steps.map(\.id), recipe.steps.map(\.id))
    }
}

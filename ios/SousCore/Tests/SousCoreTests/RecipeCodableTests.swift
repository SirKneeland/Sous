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

    // MARK: - Step subSteps

    func test_step_withSubSteps_roundTrip() throws {
        let sub1 = Step(id: UUID(), text: "Sub A", status: .todo)
        let sub2 = Step(id: UUID(), text: "Sub B", status: .done)
        let parent = Step(id: UUID(), text: "Parent step", status: .todo, subSteps: [sub1, sub2])
        let decoded = try roundTrip(parent)
        XCTAssertEqual(decoded, parent)
        XCTAssertEqual(decoded.subSteps?.count, 2)
        XCTAssertEqual(decoded.subSteps?[0].text, "Sub A")
        XCTAssertEqual(decoded.subSteps?[1].text, "Sub B")
    }

    func test_step_leafStep_noSubStepsKey_decodesWithoutSubSteps() throws {
        // JSON without a "subSteps" key (old format / leaf step) must decode fine.
        let id = UUID()
        let json = #"{"id":"\#(id.uuidString)","text":"Mix","status":"todo"}"#
            .data(using: .utf8)!
        let step = try JSONDecoder().decode(Step.self, from: json)
        XCTAssertNil(step.subSteps)
        XCTAssertEqual(step.status, .todo)
    }

    func test_step_effectiveStatus_derivedFromSubSteps_allDone() {
        let sub1 = Step(text: "Sub A", status: .done)
        let sub2 = Step(text: "Sub B", status: .done)
        let parent = Step(text: "Parent", status: .todo, subSteps: [sub1, sub2])
        XCTAssertEqual(parent.effectiveStatus, .done, "Parent must be done when all sub-steps are done")
        XCTAssertEqual(parent.status, .done)
    }

    func test_step_effectiveStatus_derivedFromSubSteps_notAllDone() {
        let sub1 = Step(text: "Sub A", status: .done)
        let sub2 = Step(text: "Sub B", status: .todo)
        let parent = Step(text: "Parent", status: .todo, subSteps: [sub1, sub2])
        XCTAssertEqual(parent.effectiveStatus, .todo, "Parent must be todo when any sub-step is incomplete")
    }

    func test_step_cannotManuallyMarkDoneWithIncompleteSubSteps() {
        let sub1 = Step(text: "Sub A", status: .done)
        let sub2 = Step(text: "Sub B", status: .todo)
        var parent = Step(text: "Parent", status: .todo, subSteps: [sub1, sub2])
        parent.status = .done // should be a no-op
        XCTAssertEqual(parent.status, .todo, "Setting done on a parent with incomplete sub-steps must be ignored")
    }

    func test_step_noSubSteps_statusMutatesNormally() {
        var step = Step(text: "Leaf step", status: .todo)
        step.status = .done
        XCTAssertEqual(step.status, .done, "Leaf step status must be settable normally")
    }

    func test_step_withSubSteps_encodesStatusAsStoredValue() throws {
        // The serialised "status" key reflects _status (the stored value), not
        // effectiveStatus, so that the JSON is stable across sub-step changes.
        let sub = Step(text: "Sub", status: .done)
        let parent = Step(text: "Parent", status: .todo, subSteps: [sub])
        let data = try JSONEncoder().encode(parent)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["status"] as? String, "todo",
                       "Encoded status must reflect stored _status, not derived effectiveStatus")
    }

    // MARK: - MiseEnPlaceEntry

    func test_miseEnPlaceEntry_solo_roundTrip() throws {
        let entry = MiseEnPlaceEntry(
            id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
            content: .solo(instruction: "Dice the onion", isDone: true)
        )
        let decoded = try roundTrip(entry)
        XCTAssertEqual(decoded, entry)
        if case .solo(let instruction, let isDone) = decoded.content {
            XCTAssertEqual(instruction, "Dice the onion")
            XCTAssertTrue(isDone)
        } else {
            XCTFail("Expected .solo content after round-trip")
        }
    }

    func test_miseEnPlaceEntry_group_roundTrip() throws {
        let components = [
            MiseEnPlaceComponent(id: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!, text: "1 tsp cumin", isDone: true),
            MiseEnPlaceComponent(id: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!, text: "1 tsp paprika", isDone: false),
        ]
        let entry = MiseEnPlaceEntry(
            id: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000003")!,
            content: .group(vesselName: "Spice Bowl", components: components)
        )
        let decoded = try roundTrip(entry)
        XCTAssertEqual(decoded, entry)
        XCTAssertFalse(decoded.isDone, "Group is not done when only some components are done")
        if case .group(let vesselName, let decodedComponents) = decoded.content {
            XCTAssertEqual(vesselName, "Spice Bowl")
            XCTAssertEqual(decodedComponents.map(\.text), ["1 tsp cumin", "1 tsp paprika"])
            XCTAssertEqual(decodedComponents.map(\.isDone), [true, false])
        } else {
            XCTFail("Expected .group content after round-trip")
        }
    }

    func test_miseEnPlaceEntry_group_isDone_whenAllComponentsDone() throws {
        let components = [
            MiseEnPlaceComponent(text: "salt", isDone: true),
            MiseEnPlaceComponent(text: "pepper", isDone: true),
        ]
        let entry = MiseEnPlaceEntry(content: .group(vesselName: "Seasoning Bowl", components: components))
        XCTAssertTrue(entry.isDone, "Group must be done when all components are done")
    }

    // MARK: - Recipe backward compat (old [Step] miseEnPlace format)

    func test_recipe_miseEnPlace_backwardCompat_oldStepFormat() throws {
        // Build JSON in the old format where miseEnPlace was [Step] with text+status fields.
        let recipeId = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001")!
        let stepId   = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000002")!
        let json = """
        {
          "id": "\(recipeId.uuidString)",
          "version": 1,
          "title": "Old Recipe",
          "ingredients": [],
          "steps": [],
          "notes": [],
          "miseEnPlace": [
            { "id": "\(stepId.uuidString)", "text": "Chop the garlic", "status": "todo" }
          ]
        }
        """.data(using: .utf8)!

        let recipe = try JSONDecoder().decode(Recipe.self, from: json)
        XCTAssertNotNil(recipe.miseEnPlace, "miseEnPlace must decode from old format")
        XCTAssertEqual(recipe.miseEnPlace?.count, 1)
        guard let entry = recipe.miseEnPlace?.first else { XCTFail("Expected an entry"); return }
        XCTAssertEqual(entry.id, stepId, "Old step ID must be preserved as entry ID")
        if case .solo(let instruction, let isDone) = entry.content {
            XCTAssertEqual(instruction, "Chop the garlic")
            XCTAssertFalse(isDone, "todo status must map to isDone = false")
        } else {
            XCTFail("Old step must become a .solo entry")
        }
    }
}

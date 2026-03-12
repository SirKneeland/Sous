import XCTest
@testable import SousCore

final class PatchCodableTests: XCTestCase {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Patch cases

    func test_addIngredient_withAfterId() throws {
        let patch = Patch.addIngredient(text: "1 tsp yeast", afterId: SeedRecipes.ingredientFlourId)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addIngredient_withoutAfterId() throws {
        let patch = Patch.addIngredient(text: "1 tsp yeast", afterId: nil)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_updateIngredient() throws {
        let patch = Patch.updateIngredient(id: SeedRecipes.ingredientSaltId, text: "2 tsp salt")
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_removeIngredient() throws {
        let patch = Patch.removeIngredient(id: SeedRecipes.ingredientWaterId)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addStep_withAfterStepId() throws {
        let patch = Patch.addStep(text: "Knead for 5 min", afterStepId: SeedRecipes.stepMixId)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addStep_withoutAfterStepId() throws {
        let patch = Patch.addStep(text: "Knead for 5 min", afterStepId: nil)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_updateStep() throws {
        let patch = Patch.updateStep(id: SeedRecipes.stepBakeId, text: "Bake at 350°F for 25 min")
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_removeStep() throws {
        let patch = Patch.removeStep(id: SeedRecipes.stepMixId)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addNote() throws {
        let patch = Patch.addNote(text: "Family recipe — original 1942 version")
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_unknownPatchType_throwsDecodingError() throws {
        let json = #"{"type":"explodeRecipe"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Patch.self, from: json))
    }

    // MARK: - PatchSetStatus

    func test_patchSetStatus_roundTrip_pending() throws {
        XCTAssertEqual(try roundTrip(PatchSetStatus.pending), .pending)
    }

    func test_patchSetStatus_roundTrip_accepted() throws {
        XCTAssertEqual(try roundTrip(PatchSetStatus.accepted), .accepted)
    }

    func test_patchSetStatus_roundTrip_rejected() throws {
        XCTAssertEqual(try roundTrip(PatchSetStatus.rejected), .rejected)
    }

    func test_patchSetStatus_unknownValue_throwsDecodingError() throws {
        let json = #""expired""#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(PatchSetStatus.self, from: json))
    }

    // MARK: - PatchSet

    func test_patchSet_roundTrip_allPatchTypes() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            patchSetId: UUID(),
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [
                .addIngredient(text: "1 tsp yeast", afterId: nil),
                .updateIngredient(id: SeedRecipes.ingredientSaltId, text: "2 tsp salt"),
                .removeIngredient(id: SeedRecipes.ingredientWaterId),
                .addStep(text: "Knead for 5 min", afterStepId: SeedRecipes.stepMixId),
                .updateStep(id: SeedRecipes.stepBakeId, text: "Bake at 350°F for 25 min"),
                .addNote(text: "Round-trip test"),
            ],
            summary: "Test patch set",
            baseRecipeSnapshot: recipe
        )
        XCTAssertEqual(try roundTrip(patchSet), patchSet)
    }

    func test_patchSet_roundTrip_nilOptionals() throws {
        let recipe = SeedRecipes.sample()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [.addNote(text: "Minimal patch")],
            summary: nil,
            baseRecipeSnapshot: nil
        )
        let decoded = try roundTrip(patchSet)
        XCTAssertEqual(decoded, patchSet)
        XCTAssertNil(decoded.summary)
        XCTAssertNil(decoded.baseRecipeSnapshot)
    }

    func test_setTitle() throws {
        let patch = Patch.setTitle("Spaghetti Carbonara")
        XCTAssertEqual(try roundTrip(patch), patch)
    }
}

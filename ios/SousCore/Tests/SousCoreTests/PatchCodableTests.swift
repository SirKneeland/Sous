import XCTest
@testable import SousCore

final class PatchCodableTests: XCTestCase {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Ingredient patches

    func test_addIngredient_withGroupAndAfterId() throws {
        let patch = Patch.addIngredient(groupId: SeedRecipes.ingredientGroupId, afterId: SeedRecipes.ingredientFlourId, text: "1 tsp yeast")
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addIngredient_nilGroupAndAfterId() throws {
        let patch = Patch.addIngredient(groupId: nil, afterId: nil, text: "1 tsp yeast")
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

    func test_addIngredientGroup_withHeader() throws {
        let patch = Patch.addIngredientGroup(afterGroupId: SeedRecipes.ingredientGroupId, header: "Spices", preassignedId: nil)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addIngredientGroup_nilOptionals() throws {
        let patch = Patch.addIngredientGroup(afterGroupId: nil, header: nil, preassignedId: nil)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_updateIngredientGroup() throws {
        let patch = Patch.updateIngredientGroup(id: SeedRecipes.ingredientGroupId, header: "Dry Ingredients")
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_removeIngredientGroup() throws {
        let patch = Patch.removeIngredientGroup(id: SeedRecipes.ingredientGroupId)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    // MARK: - Step patches

    func test_addStep_withAfterStepId() throws {
        let patch = Patch.addStep(parentId: nil, afterId: SeedRecipes.stepMixId, text: "Knead for 5 min", preassignedId: nil)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addStep_withoutAfterStepId() throws {
        let patch = Patch.addStep(parentId: nil, afterId: nil, text: "Knead for 5 min", preassignedId: nil)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addStep_withParentId() throws {
        let patch = Patch.addStep(parentId: SeedRecipes.stepMixId, afterId: nil, text: "Sift flour", preassignedId: nil)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_addStep_withPreassignedId_roundTrips() throws {
        let preId = UUID()
        let patch = Patch.addStep(parentId: nil, afterId: nil, text: "Parboil potatoes:", preassignedId: preId)
        let decoded = try roundTrip(patch)
        XCTAssertEqual(decoded, patch)
        if case .addStep(_, _, _, let decodedPreId) = decoded {
            XCTAssertEqual(decodedPreId, preId)
        } else {
            XCTFail("Expected addStep")
        }
    }

    func test_updateStep() throws {
        let patch = Patch.updateStep(id: SeedRecipes.stepBakeId, text: "Bake at 350°F for 25 min")
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_removeStep() throws {
        let patch = Patch.removeStep(id: SeedRecipes.stepMixId)
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_setStepNotes() throws {
        let patch = Patch.setStepNotes(stepId: SeedRecipes.stepMixId, notes: ["Use cold water", "Don't overmix"])
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    // MARK: - Note section patches

    func test_addNoteSection() throws {
        let patch = Patch.addNoteSection(afterId: nil, header: "Tips", items: ["Store in airtight container"])
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_updateNoteSection() throws {
        let sectionId = UUID()
        let patch = Patch.updateNoteSection(id: sectionId, header: "Storage", items: ["Freeze up to 3 months"])
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    func test_removeNoteSection() throws {
        let patch = Patch.removeNoteSection(id: UUID())
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    // MARK: - setTitle

    func test_setTitle() throws {
        let patch = Patch.setTitle("Spaghetti Carbonara")
        XCTAssertEqual(try roundTrip(patch), patch)
    }

    // MARK: - Unknown type

    func test_unknownPatchType_throwsDecodingError() throws {
        let json = #"{"type":"explodeRecipe"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Patch.self, from: json))
    }

    // MARK: - Backward compat: decode legacy addNote as addNoteSection

    func test_legacyAddNote_decodesAsAddNoteSection() throws {
        let json = #"{"type":"addNote","text":"Great with wine"}"#.data(using: .utf8)!
        let patch = try JSONDecoder().decode(Patch.self, from: json)
        if case .addNoteSection(let afterId, let header, let items) = patch {
            XCTAssertNil(afterId)
            XCTAssertNil(header)
            XCTAssertEqual(items, ["Great with wine"])
        } else {
            XCTFail("Expected addNoteSection from legacy addNote")
        }
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
                .addIngredient(groupId: nil, afterId: nil, text: "1 tsp yeast"),
                .updateIngredient(id: SeedRecipes.ingredientSaltId, text: "2 tsp salt"),
                .removeIngredient(id: SeedRecipes.ingredientWaterId),
                .addStep(parentId: nil, afterId: SeedRecipes.stepMixId, text: "Knead for 5 min", preassignedId: nil),
                .updateStep(id: SeedRecipes.stepBakeId, text: "Bake at 350°F for 25 min"),
                .addNoteSection(afterId: nil, header: nil, items: ["Round-trip test"]),
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
            patches: [.setTitle("Minimal patch")],
            summary: nil,
            baseRecipeSnapshot: nil
        )
        let decoded = try roundTrip(patchSet)
        XCTAssertEqual(decoded, patchSet)
        XCTAssertNil(decoded.summary)
        XCTAssertNil(decoded.baseRecipeSnapshot)
    }
}

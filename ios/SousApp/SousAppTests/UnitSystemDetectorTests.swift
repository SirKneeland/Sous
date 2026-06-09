import XCTest
import SousCore
@testable import SousApp

// Note: These tests exercise the regex fallback path. The FoundationModels primary path
// requires device capabilities (iOS 26+, model downloaded) and cannot be unit-tested.

final class UnitSystemDetectorTests: XCTestCase {

    // MARK: - Helpers

    private func recipe(ingredients: [String] = [], steps: [String] = []) -> Recipe {
        let groupId = UUID()
        let group = IngredientGroup(
            id: groupId,
            header: nil,
            items: ingredients.map { Ingredient(text: $0) }
        )
        let stepList = steps.map { Step(text: $0) }
        return Recipe(
            id: UUID(),
            version: 1,
            title: "Test",
            ingredients: [group],
            steps: stepList
        )
    }

    // MARK: - Imperial-only input

    func test_detect_imperialOnly_returnsImperial() async {
        let r = recipe(
            ingredients: ["2 cups flour", "1/2 tsp salt", "3/4 cup water"],
            steps: ["Bake at 350°F for 30 min"]
        )
        let result = await UnitSystemDetector.detect(recipe: r)
        XCTAssertEqual(result, .imperial)
    }

    // MARK: - Metric-only input

    func test_detect_metricOnly_returnsMetric() async {
        let r = recipe(
            ingredients: ["200 grams spaghetti", "100ml olive oil"],
            steps: ["Heat to 180°C"]
        )
        let result = await UnitSystemDetector.detect(recipe: r)
        XCTAssertEqual(result, .metric)
    }

    // MARK: - Mixed input, imperial majority wins

    func test_detect_mixed_imperialMajority_returnsImperial() async {
        let r = recipe(
            ingredients: ["2 cups flour", "1 tbsp butter", "1 tsp salt", "200 grams sugar"],
            steps: ["Bake at 350°F"]
        )
        // 4 imperial hits (cups, tbsp, tsp, °F) vs 1 metric hit (grams)
        let result = await UnitSystemDetector.detect(recipe: r)
        XCTAssertEqual(result, .imperial)
    }

    // MARK: - No units → nil

    func test_detect_noUnits_returnsNil() async {
        let r = recipe(
            ingredients: ["3 eggs", "salt to taste", "a handful of herbs"],
            steps: ["Mix everything together", "Cook until done"]
        )
        let result = await UnitSystemDetector.detect(recipe: r)
        XCTAssertNil(result)
    }

    // MARK: - Full-word unit names (common in imported recipes)

    func test_detect_fahrenheitFullWord_returnsImperial() async {
        let r = recipe(
            ingredients: ["2 cups flour"],
            steps: ["Bake at 350 Fahrenheit"]
        )
        let result = await UnitSystemDetector.detect(recipe: r)
        XCTAssertEqual(result, .imperial)
    }

    func test_detect_celsiusFullWord_returnsMetric() async {
        let r = recipe(
            ingredients: ["200 grams flour"],
            steps: ["Heat to 180 Celsius"]
        )
        let result = await UnitSystemDetector.detect(recipe: r)
        XCTAssertEqual(result, .metric)
    }

    func test_detect_imperialCaseMixed_returnsImperial() async {
        let r = recipe(
            ingredients: ["2 Cup flour", "1 TBSP butter"],
            steps: ["Bake at 350°F"]
        )
        let result = await UnitSystemDetector.detect(recipe: r)
        XCTAssertEqual(result, .imperial)
    }

    // MARK: - Equal hits → nil (ambiguous)

    func test_detect_equalHits_returnsNil() async {
        // Exactly one imperial (cups) and one metric (grams)
        let r = recipe(
            ingredients: ["1 cup water", "100 grams butter"],
            steps: []
        )
        let result = await UnitSystemDetector.detect(recipe: r)
        XCTAssertNil(result)
    }
}

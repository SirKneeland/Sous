import Foundation
import FoundationModels
import SousCore

// MARK: - DetectedUnitSystem

enum DetectedUnitSystem {
    case imperial
    case metric
}

// MARK: - UnitSystemDetector

enum UnitSystemDetector {

    /// Inspects all ingredient and step text in the recipe and returns the
    /// dominant unit system, or nil if the recipe is ambiguous or unit-free.
    ///
    /// Primary path: Apple FoundationModels on-device LLM (iOS 26+).
    /// Fallback: regex-based counting of unit keywords.
    static func detect(recipe: Recipe) async -> DetectedUnitSystem? {
        if #available(iOS 26, macOS 26, *) {
            if let result = await detectWithFoundationModels(recipe) {
                return result
            }
        }
        return detectWithRegex(recipe)
    }

    // MARK: - FoundationModels path (iOS 26+)

    @available(iOS 26, macOS 26, *)
    private static func detectWithFoundationModels(_ recipe: Recipe) async -> DetectedUnitSystem? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }
        let text = collectText(from: recipe)
        guard !text.isEmpty else { return nil }
        let session = LanguageModelSession()
        let prompt = "Does the following recipe use imperial units (cups, tablespoons, ounces, pounds, °F, Fahrenheit), metric units (grams, kilograms, milliliters, liters, °C, Celsius), or neither? Reply with exactly one word: imperial, metric, or neither.\n\n\(text)"
        guard let response = try? await session.respond(to: prompt) else {
            return nil
        }
        let content = response.content.lowercased()
        if content.contains("imperial") { return .imperial }
        if content.contains("metric") { return .metric }
        return nil
    }

    // MARK: - Regex fallback

    private static func detectWithRegex(_ recipe: Recipe) -> DetectedUnitSystem? {
        let text = collectText(from: recipe)
        let imperialCount = countMatches(imperialPattern, in: text)
        let metricCount = countMatches(metricPattern, in: text)
        if imperialCount == 0 && metricCount == 0 { return nil }
        if imperialCount > metricCount { return .imperial }
        if metricCount > imperialCount { return .metric }
        return nil // equal — ambiguous
    }

    // MARK: - Private

    private static func collectText(from recipe: Recipe) -> String {
        let ingredientText = recipe.ingredients
            .flatMap { $0.items }
            .map { $0.text }
        let stepText = recipe.steps.map { $0.text }
        return (ingredientText + stepText).joined(separator: " ")
    }

    private static let imperialPattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"\b(oz|ounce|ounces|lb|lbs|pound|pounds|cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|quart|quarts|gallon|gallons|stick|sticks|fl\s+oz|fluid\s+ounce|fluid\s+ounces|fahrenheit)\b|°F|\b\d+\s*F\b"#,
            options: .caseInsensitive
        )
    }()

    private static let metricPattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"\b(gram|grams|kg|kilogram|kilograms|ml|milliliter|milliliters|millilitre|millilitres|liter|liters|litre|litres|dl|deciliter|deciliters|celsius)\b|\b\d+\s*g\b|°C"#,
            options: .caseInsensitive
        )
    }()

    private static func countMatches(_ regex: NSRegularExpression, in text: String) -> Int {
        regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }
}

import Foundation
import SousCore

// MARK: - MiseEnPlaceResponse

struct MiseEnPlaceResponse: Sendable {
    enum Entry: Sendable {
        case group(vesselName: String, components: [String])
        case solo(instruction: String)
    }

    let miseEnPlace: [Entry]
    let updatedSteps: [String]
}

// MARK: - MiseEnPlaceServiceProtocol

protocol MiseEnPlaceServiceProtocol: Sendable {
    func run(recipe: Recipe, apiKey: String) async throws -> MiseEnPlaceResponse
}

// MARK: - MiseEnPlaceServiceError

enum MiseEnPlaceServiceError: Error, Sendable {
    case missingAPIKey
    case networkError(Error)
    case httpError(Int)
    case malformedResponse
}

// MARK: - MiseEnPlaceService

struct MiseEnPlaceService: MiseEnPlaceServiceProtocol {

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model: String
    private let session: URLSession

    init(model: String = "gpt-5.4-mini", session: URLSession = .shared) {
        self.model = model
        self.session = session
    }

    func run(recipe: Recipe, apiKey: String) async throws -> MiseEnPlaceResponse {
        guard !apiKey.isEmpty else { throw MiseEnPlaceServiceError.missingAPIKey }

        let systemPrompt = """
            You are a culinary assistant helping to organize a recipe using the mise en place technique.

            Your task: identify ALL prep steps from the recipe's procedure — anything that should be done BEFORE active cooking begins.
            Prep steps include: chopping, dicing, mincing, slicing, measuring, marinating, soaking, preheating, bringing to room temperature, preparing equipment, etc.

            Return a JSON object with exactly these two keys:

            "miseEnPlace": an array of entries. Each entry is one of:
              - A GROUP entry: ingredients that are combined into a single vessel before cooking.
                { "type": "group", "vesselName": "<label>", "components": ["<item>", ...] }
                Name the vessel based on its contents and the most sensible container, using the format "[ingredient type] + [vessel]"
                (e.g. "Spice Bowl", "Marinade Bowl", "Meat Plate", "Sauce Bowl").
                Only number the vessel if the same vessel type appears more than once (e.g. "Spice Bowl 1", "Spice Bowl 2").
                Use a group entry when two or more ingredients are combined or measured together for the same step.
              - A SOLO entry: a single standalone prep instruction that doesn't involve combining ingredients into a vessel.
                { "type": "solo", "instruction": "<instruction>" }
                Use a solo entry for prep actions on a single ingredient (e.g. "Dice the onion", "Preheat oven to 375°F").

            "updatedSteps": array of strings — the remaining procedure steps after extracting prep.
              Reference grouped vessel names inline, followed by a parenthetical of the first 2 components only, plus "etc" if there are more.
              Example: "Add Spice Bowl (cumin, paprika, etc) and stir for 30 seconds." or "Add Egg Bowl (eggs, cream) and whisk." if there are only 2 components.

            Rules:
            - If a step is both prep and cooking (e.g. "chop the onions and add to pan"), split it: put the prep part in miseEnPlace and the cooking part in updatedSteps.
            - If there are no meaningful prep steps, return an empty array for "miseEnPlace" and return the original steps unchanged in "updatedSteps".
            - Return ONLY the JSON object. No explanation, no preamble.
            """

        let userMessage = buildRecipeText(recipe)

        let body: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw MiseEnPlaceServiceError.malformedResponse
        }
        request.httpBody = bodyData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MiseEnPlaceServiceError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw MiseEnPlaceServiceError.httpError(http.statusCode)
        }

        return try parseResponse(data)
    }

    // MARK: - Helpers

    private func buildRecipeText(_ recipe: Recipe) -> String {
        var lines: [String] = ["Recipe: \(recipe.title)", ""]
        if !recipe.ingredients.isEmpty {
            lines.append("Ingredients:")
            for ingredient in recipe.ingredients {
                lines.append("- \(ingredient.text)")
            }
            lines.append("")
        }
        lines.append("Procedure:")
        for (index, step) in recipe.steps.enumerated() {
            lines.append("\(index + 1). \(step.text)")
        }
        return lines.joined(separator: "\n")
    }

    private func parseResponse(_ data: Data) throws -> MiseEnPlaceResponse {
        // Parse the OpenAI envelope to extract choices[0].message.content
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = envelope["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any]
        else {
            throw MiseEnPlaceServiceError.malformedResponse
        }

        let rawEntries = parsed["miseEnPlace"] as? [[String: Any]] ?? []
        let updatedSteps = parsed["updatedSteps"] as? [String] ?? []

        guard !updatedSteps.isEmpty || rawEntries.isEmpty else {
            throw MiseEnPlaceServiceError.malformedResponse
        }

        let miseEnPlace: [MiseEnPlaceResponse.Entry] = rawEntries.compactMap { dict in
            guard let type = dict["type"] as? String else { return nil }
            switch type {
            case "group":
                guard let vesselName = dict["vesselName"] as? String,
                      let components = dict["components"] as? [String] else { return nil }
                return .group(vesselName: vesselName, components: components)
            case "solo":
                guard let instruction = dict["instruction"] as? String else { return nil }
                return .solo(instruction: instruction)
            default:
                return nil
            }
        }

        return MiseEnPlaceResponse(miseEnPlace: miseEnPlace, updatedSteps: updatedSteps)
    }
}

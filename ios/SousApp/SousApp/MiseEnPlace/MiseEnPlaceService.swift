import Foundation
import SousCore

// MARK: - MiseEnPlaceResponse

struct MiseEnPlaceResponse: Sendable {
    let miseEnPlace: [String]
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

    init(model: String = "gpt-4o-mini", session: URLSession = .shared) {
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
            - "miseEnPlace": array of strings — the prep steps extracted from the procedure (preserve the original wording closely)
            - "updatedSteps": array of strings — the remaining procedure steps after removing the prep steps (cooking-only instructions)

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

        let miseEnPlace = parsed["miseEnPlace"] as? [String] ?? []
        let updatedSteps = parsed["updatedSteps"] as? [String] ?? []

        guard !updatedSteps.isEmpty || miseEnPlace.isEmpty else {
            throw MiseEnPlaceServiceError.malformedResponse
        }

        return MiseEnPlaceResponse(miseEnPlace: miseEnPlace, updatedSteps: updatedSteps)
    }
}

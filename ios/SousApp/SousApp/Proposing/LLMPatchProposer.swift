import Foundation
import SousCore

// MARK: - LLMPatchProposer

/// OpenAI-backed proposer with JSON repair loop and validation retry.
/// `propose` is @MainActor so all `onStatus` callbacks and PatchValidator
/// calls stay on the main actor; URLSession suspensions release it during I/O.
struct LLMPatchProposer {

    private static let maxAttempts = 3
    private static let model = "gpt-4o-mini"
    private static let temperature: Double = 0.1

    // MARK: - Entry point

    @MainActor
    func propose(
        userText: String,
        recipe: Recipe,
        onStatus: (String) -> Void
    ) async -> PatchSet? {

        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
              !apiKey.isEmpty else {
#if DEBUG
            onStatus("LLM: missing OPENAI_API_KEY")
#endif
            return nil
        }

        var repairContext: String? = nil

        for attempt in 1...Self.maxAttempts {
#if DEBUG
            onStatus("LLM: proposing (\(attempt)/\(Self.maxAttempts))")
#endif

            // 1. Call OpenAI
            guard let rawContent = await callOpenAI(
                messages: buildMessages(userText: userText, recipe: recipe, repairContext: repairContext),
                apiKey: apiKey
            ) else { continue }

            // 2. Strict decode; on failure attempt JSON repair
            var dto = strictDecode(rawContent)
            if dto == nil {
#if DEBUG
                onStatus("LLM: JSON parse failed — repairing")
#endif
                dto = strictDecode(repairJSON(rawContent))
            }
            guard let dto else { continue }

            // 3. Map DTO → domain PatchSet
            let patchSet = dto.toDomain()

            // 4. Validate
            let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
            switch result {
            case .valid:
#if DEBUG
                onStatus("LLM: proposal valid")
#endif
                return patchSet

            case .invalid(let errors):
                let codes = errors.map { $0.code.rawValue }.joined(separator: ", ")
#if DEBUG
                onStatus("LLM: validation failed: \(codes) (retrying \(attempt)/\(Self.maxAttempts))")
#endif
                repairContext = buildRepairContext(recipe: recipe, errors: errors)

                if attempt == Self.maxAttempts {
#if DEBUG
                    onStatus("LLM: failed after \(Self.maxAttempts) attempts")
                    return patchSet   // DEBUG: surface invalid patchSet so review UI can show it
#else
                    return nil        // RELEASE: do not enter review; caller shows chat fallback
#endif
                }
            }
        }

#if DEBUG
        onStatus("LLM: failed after \(Self.maxAttempts) attempts")
#endif
        return nil
    }

    // MARK: - Message building

    private func buildMessages(
        userText: String,
        recipe: Recipe,
        repairContext: String?
    ) -> [[String: String]] {
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt(recipe: recipe)]
        ]
        if let repair = repairContext {
            messages.append(["role": "user", "content": repair])
            messages.append(["role": "assistant", "content": "Understood. I will output only valid JSON."])
        }
        messages.append(["role": "user", "content": userText])
        return messages
    }

    private func systemPrompt(recipe: Recipe) -> String {
        let ingredientList = recipe.ingredients
            .map { "  \($0.id.uuidString): \($0.text)" }
            .joined(separator: "\n")
        let stepList = recipe.steps
            .map { "  \($0.id.uuidString): [\($0.status == .done ? "done" : "todo")] \($0.text)" }
            .joined(separator: "\n")

        return """
        You are a cooking assistant that modifies recipes.
        Output ONLY valid JSON. No prose. No backticks. No markdown. No explanation.

        Current recipe:
          id: \(recipe.id.uuidString)
          version: \(recipe.version)
        Ingredients:
        \(ingredientList)
        Steps:
        \(stepList)

        Output exactly this JSON shape:
        {
          "baseRecipeId": "\(recipe.id.uuidString)",
          "baseRecipeVersion": \(recipe.version),
          "patches": [
            { "type": "addIngredient", "text": "...", "afterId": null },
            { "type": "updateIngredient", "id": "UUID", "text": "..." },
            { "type": "removeIngredient", "id": "UUID" },
            { "type": "addStep", "text": "...", "afterStepId": null },
            { "type": "updateStep", "id": "UUID", "text": "..." },
            { "type": "removeStep", "id": "UUID" },
            { "type": "addNote", "text": "..." }
          ]
        }

        Rules:
        - baseRecipeId must be "\(recipe.id.uuidString)"
        - baseRecipeVersion must be \(recipe.version)
        - Only reference IDs listed above
        - Never modify steps with status "done"
        - Include only patch types listed above; unknown types are forbidden
        """
    }

    private func buildRepairContext(recipe: Recipe, errors: [PatchValidationError]) -> String {
        let codes = errors.map { $0.code.rawValue }.joined(separator: ", ")
        let ingredientSnapshot = recipe.ingredients
            .map { "\($0.id.uuidString)=\($0.text)" }
            .joined(separator: ", ")
        let stepSnapshot = recipe.steps
            .map { "\($0.id.uuidString)=[\($0.status == .done ? "done" : "todo")]\($0.text)" }
            .joined(separator: ", ")
        return """
        The previous JSON was INVALID. Errors: \(codes)
        Recipe id=\(recipe.id.uuidString) version=\(recipe.version)
        Ingredients: \(ingredientSnapshot)
        Steps: \(stepSnapshot)
        Output ONLY valid JSON. No prose. No backticks.
        baseRecipeId must be \(recipe.id.uuidString), baseRecipeVersion must be \(recipe.version).
        """
    }

    // MARK: - Decode & repair

    private func strictDecode(_ raw: String) -> PatchSetDTO? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PatchSetDTO.self, from: data)
    }

    private func repairJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip backtick code fences
        if s.hasPrefix("```") {
            if let closeRange = s.range(of: "```", options: .backwards),
               closeRange.lowerBound != s.startIndex {
                s = String(s[s.index(s.startIndex, offsetBy: 3)..<closeRange.lowerBound])
            }
            // Strip language tag line (e.g. "json\n")
            if let newline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: newline)...])
            }
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Extract first complete JSON object
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            s = String(s[start...end])
        }
        // Remove trailing commas before } or ]
        s = s.replacingOccurrences(
            of: #",\s*([}\]])"#,
            with: "$1",
            options: .regularExpression
        )
        return s
    }

    // MARK: - Network

    private func callOpenAI(messages: [[String: String]], apiKey: String) async -> String? {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": Self.model,
            "temperature": Self.temperature,
            "messages": messages
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }

        return content
    }
}

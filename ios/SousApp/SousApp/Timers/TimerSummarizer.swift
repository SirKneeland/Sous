import Foundation
import FoundationModels

// MARK: - TimerSummarizer

/// Generates a short (6–8 word) summary of a recipe step for use in timer banners.
///
/// Strategy:
/// 1. On iOS 26+, attempt Apple's FoundationModels on-device language model.
/// 2. If unavailable or the call fails, fall back to taking the first 8 words of the step text.
enum TimerSummarizer {

    static func summarize(_ stepText: String) async -> String {
        if #available(iOS 26, macOS 26, *) {
            if let result = await summarizeWithFoundationModels(stepText) {
                return result
            }
        }
        return fallbackSummary(stepText)
    }

    // MARK: - FoundationModels path (iOS 26+)

    @available(iOS 26, macOS 26, *)
    private static func summarizeWithFoundationModels(_ stepText: String) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }
        let session = LanguageModelSession()
        let prompt = "Summarize this cooking step in 2 to 4 words. Focus only on the main action and ingredient (e.g. \"cook lamb\", \"warm flatbreads\", \"simmer garlic spices\"). Never include time, duration, or how-to details. Reply with only the short summary, nothing else. Step: \(stepText)"
        guard let response = try? await session.respond(to: prompt) else {
            return nil
        }
        let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Fallback

    static func fallbackSummary(_ stepText: String) -> String {
        let words = stepText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let taken = words.prefix(8)
        if taken.count < words.count {
            return taken.joined(separator: " ") + "…"
        }
        return taken.joined(separator: " ")
    }
}

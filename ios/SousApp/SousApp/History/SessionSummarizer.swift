import Foundation
import FoundationModels

// MARK: - SessionSummarizer

/// Generates a short title phrase summarizing what the user is cooking or exploring,
/// based on pre-canvas session chat history.
///
/// Strategy:
/// 1. On iOS 26+, attempt Apple's on-device FoundationModels language model.
/// 2. If unavailable or the call fails, return nil (callers show a static fallback).
enum SessionSummarizer {

    /// Returns a short summary phrase, or nil on failure / unavailability / no messages.
    static func summarize(messages: [ChatMessage]) async -> String? {
        let relevant = messages.filter { $0.role == .user || $0.role == .assistant }
        guard !relevant.isEmpty else { return nil }

        let chatText = relevant
            .map { "[\($0.role == .user ? "User" : "Sous")]: \($0.text)" }
            .joined(separator: "\n")

        if #available(iOS 26, macOS 26, *) {
            return await summarizeWithFoundationModels(chatText)
        }
        return nil
    }

    // MARK: - FoundationModels path (iOS 26+)

    @available(iOS 26, macOS 26, *)
    private static func summarizeWithFoundationModels(_ chatText: String) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession()
        let prompt = """
            Read this cooking session and write a single short phrase (under 60 characters) \
            capturing what the USER is cooking or exploring. Title-style phrasing only — \
            not a sentence, not a question. No quotes. No trailing punctuation.

            Rules:
            - User messages are the primary signal. Base the title on what the user said.
            - Assistant messages are supporting context only. The assistant's suggestions \
            have not been chosen by the user — do not treat them as facts about the session.
            - Never infer specific ingredients, techniques, or dishes the user did not mention.
            - If the user's messages are vague or exploratory, reflect that vagueness. \
            A broad title is better than a specific one the user did not commit to.
            - Only use specific dish or ingredient details if the user themselves stated them.

            Examples:
            - User said "I've got 1lb of chicken thighs, any ideas?" → "Chicken thighs, figuring it out"
            - User said "let's do a stir fry with what I have" → "Stir fry with what's on hand"
            - User said "make me something spicy with leftover chicken" → "Something spicy with leftover chicken"

            Session:
            \(chatText)
            """
        guard let response = try? await session.respond(to: prompt) else { return nil }
        var cleaned = response.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\u{2018}", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
        if let last = cleaned.last, ".!?,;:".contains(last) {
            cleaned = String(cleaned.dropLast())
        }
        let capped = String(cleaned.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
        return capped.isEmpty ? nil : capped
    }
}

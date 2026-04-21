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
            describing what the user seems to be cooking or exploring. Write it like a recipe \
            title — not a sentence, not a question. No quotes. No trailing punctuation. \
            Examples: "Weeknight pasta, tomato and anchovy", "Something spicy with leftover chicken".

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

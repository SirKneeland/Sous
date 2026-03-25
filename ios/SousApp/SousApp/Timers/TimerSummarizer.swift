import Foundation

// MARK: - TimerSummarizer

/// Generates a short (6–8 word) summary of a recipe step for use in timer banners.
///
/// Strategy:
/// 1. On iOS 26+, attempt Apple's FoundationModels on-device language model.
/// 2. If unavailable or the call fails, fall back to taking the first 8 words of the step text.
enum TimerSummarizer {

    static func summarize(_ stepText: String) async -> String {
        if #available(iOS 26.0, *) {
            if let result = await summarizeWithFoundationModels(stepText) {
                return result
            }
        }
        return fallbackSummary(stepText)
    }

    // MARK: - FoundationModels path (iOS 26+)

    @available(iOS 26.0, *)
    private static func summarizeWithFoundationModels(_ stepText: String) async -> String? {
        // Import is guarded by availability — use dynamic linking to avoid hard dependency
        // that would prevent building on older SDKs.
        // If FoundationModels is not present at build time, this whole branch is skipped.
        return nil // Placeholder: FoundationModels API not yet finalized in build SDK
        // TODO: When FoundationModels SDK is available, replace with:
        // let session = LanguageModelSession()
        // let prompt = "Summarize this cooking step in 6 to 8 words: \(stepText)"
        // let response = try? await session.respond(to: prompt)
        // return response?.content.trimmingCharacters(in: .whitespacesAndNewlines)
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

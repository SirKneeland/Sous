import Foundation
import FoundationModels

// MARK: - MemoryPersonConverter

/// Converts memory strings between second-person ("You love cheese") and
/// first-person ("I love cheese") for editing UX.
///
/// Strategy:
/// 1. On iOS 26+, attempt Apple's FoundationModels on-device language model.
/// 2. If unavailable or the call fails, fall back to naive prefix swap.
enum MemoryPersonConverter {

    // MARK: - One-shot (used by MemoriesView)

    static func toFirstPerson(text: String) async -> String {
        if #available(iOS 26, macOS 26, *) {
            if let result = await convertWithFoundationModels(text, prompt: firstPersonPrompt(text)) {
                return result
            }
        }
        return naiveToFirstPerson(text)
    }

    static func toSecondPerson(text: String) async -> String {
        if #available(iOS 26, macOS 26, *) {
            if let result = await convertWithFoundationModels(text, prompt: secondPersonPrompt(text)) {
                return result
            }
        }
        return naiveToSecondPerson(text)
    }

    // MARK: - Streaming (used by MemoryProposalToast)

    /// Each yielded value is the full cumulative text so far (grows token by token).
    /// Falls back to a single yield of the naive swap if the model is unavailable.
    @available(iOS 26, macOS 26, *)
    static func streamToFirstPerson(text: String) -> AsyncStream<String> {
        makeStream(prompt: firstPersonPrompt(text), fallback: naiveToFirstPerson(text))
    }

    @available(iOS 26, macOS 26, *)
    static func streamToSecondPerson(text: String) -> AsyncStream<String> {
        makeStream(prompt: secondPersonPrompt(text), fallback: naiveToSecondPerson(text))
    }

    // MARK: - FoundationModels helpers

    @available(iOS 26, macOS 26, *)
    private static func makeStream(prompt: String, fallback: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            let producerTask = Task {
                guard case .available = SystemLanguageModel.default.availability else {
                    continuation.yield(fallback)
                    continuation.finish()
                    return
                }
                let session = LanguageModelSession()
                let responseStream = session.streamResponse(to: prompt)
                do {
                    var lastContent = ""
                    for try await snapshot in responseStream {
                        let content = snapshot.content.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !content.isEmpty, content != lastContent else { continue }
                        lastContent = content
                        continuation.yield(content)
                    }
                    if lastContent.isEmpty {
                        continuation.yield(fallback)
                    } else {
                        var stripped = lastContent
                        if stripped.last == "." { stripped = String(stripped.dropLast()) }
                        if stripped != lastContent && !stripped.isEmpty { continuation.yield(stripped) }
                    }
                } catch {
                    continuation.yield(fallback)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in producerTask.cancel() }
        }
    }

    @available(iOS 26, macOS 26, *)
    private static func convertWithFoundationModels(_ text: String, prompt: String) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession()
        guard let response = try? await session.respond(to: prompt) else { return nil }
        var trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.last == "." { trimmed = String(trimmed.dropLast()) }
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Prompts

    private static func firstPersonPrompt(_ text: String) -> String {
        "Rewrite this one sentence in first person (starting with 'I'). Return only the rewritten sentence, nothing else: \(text)"
    }

    private static func secondPersonPrompt(_ text: String) -> String {
        "Rewrite this one sentence in second person (starting with 'You'). Return only the rewritten sentence, nothing else: \(text)"
    }

    // MARK: - Naive fallback

    static func naiveToFirstPerson(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("you ") { t = "I " + t.dropFirst(4) }
        if t.last == "." { t = String(t.dropLast()) }
        return t
    }

    static func naiveToSecondPerson(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("i ") { t = "You " + t.dropFirst(2) }
        if t.last == "." { t = String(t.dropLast()) }
        return t
    }
}

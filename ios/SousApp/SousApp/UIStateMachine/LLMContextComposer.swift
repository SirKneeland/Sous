import Foundation

// MARK: - LLMContextComposer

/// Composes the string that gets sent to the LLM as the user message.
///
/// If hidden context exists, it is prepended in a machine-readable block that
/// is not rendered to the user in the chat UI.
public enum LLMContextComposer {

    /// - Parameters:
    ///   - userText: The visible message the user typed.
    ///   - hidden: Silent system context (e.g. patch rejection facts).
    /// - Returns: A string ready to be sent as the LLM `user` turn.
    public static func composeUserMessage(userText: String, hidden: HiddenContext) -> String {
        guard !hidden.entries.isEmpty else {
            return userText
        }
        let block = "[[SYSCTX]]\n"
            + hidden.entries.joined(separator: "\n")
            + "\n[[/SYSCTX]]"
        return block + "\n" + userText
    }
}

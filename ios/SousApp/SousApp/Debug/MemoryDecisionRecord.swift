import Foundation

// MARK: - MemorySaveTrigger

/// How a pending memory proposal came to be saved. Passed from the proposal toast so the
/// debug log can distinguish a deliberate save from the six-second countdown saving by default.
/// Compiled in all builds because it appears in `AppStore` method signatures; only the
/// debug decision log ever reads it.
enum MemorySaveTrigger: String {
    case tappedSave = "tapped SAVE"
    case editedThenSaved = "edited, then saved"
    case countdownExpired = "countdown expired — saved automatically"
    case swipedAway = "swiped away — saved automatically"
}

#if DEBUG

// MARK: - MemoryDecisionRecord

/// One turn's memory decision: what the model proposed, if anything, and what became of it.
///
/// Kept as a rolling session log rather than a single latest value, because the question this
/// answers ("is memory saving overzealous?") is about the rate across a session, not one event.
struct MemoryDecisionRecord {

    enum Fate: Equatable {
        /// The model proposed nothing this turn.
        case noProposal
        /// Shown, still counting down when the export was taken.
        case pending
        /// Saved. Carries how, and the text as actually saved (which differs when edited).
        case saved(trigger: MemorySaveTrigger, savedText: String)
        /// Dismissed with SKIP before the countdown ran out.
        case skipped
        /// A later proposal arrived and replaced this one before it resolved.
        case supersededByLaterProposal

        var label: String {
            switch self {
            case .noProposal:               return "no proposal"
            case .pending:                  return "still on screen when this export was taken"
            case .saved(let trigger, _):    return "SAVED (\(trigger.rawValue))"
            case .skipped:                  return "skipped"
            case .supersededByLaterProposal: return "replaced by a later proposal before it resolved"
            }
        }
    }

    let timestamp: Date

    /// What prompted the turn: the user's message, or a description for turns with no typed
    /// input (a photo sent into chat, a silent serving rescale).
    let turnSource: String

    /// The proposal text exactly as the model returned it. Nil when nothing was proposed.
    let proposedText: String?

    /// An already-saved memory this proposal duplicates, if any. Computed on the app side —
    /// the prompt asks the model to skip these, but nothing enforces it.
    let duplicateOf: String?

    /// How many memories were in the prompt context for this turn.
    let memoriesInContextCount: Int

    var fate: Fate
}

// MARK: - Duplicate Detection

extension MemoryDecisionRecord {

    /// Returns the first saved memory the proposal duplicates, or nil.
    ///
    /// Deliberately blunt: case- and punctuation-insensitive equality, plus containment either
    /// way so "You avoid cilantro" matches "You avoid cilantro and dill". It is a debugging
    /// signal, not a dedupe rule — nothing in the app acts on it.
    static func duplicate(of proposal: String, among memories: [String]) -> String? {
        let needle = normalize(proposal)
        guard !needle.isEmpty else { return nil }
        return memories.first { existing in
            let hay = normalize(existing)
            guard !hay.isEmpty else { return false }
            return hay == needle || hay.contains(needle) || needle.contains(hay)
        }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
#endif

import Foundation
import SousCore

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Everything the UI needs to recover from a failed turn (Milestone 30).
///
/// Carried on the assistant bubble that reports the failure, rather than in a
/// separate AppStore field, so a RETRY offered before the app was backgrounded is
/// still there when the user comes back — it rides along in `SessionSnapshot`.
struct ChatFailureRecord: Codable, Sendable, Equatable {
    /// What went wrong, and whether it is worth retrying at all.
    let failure: ChatFailure
    /// The original turn, kept verbatim so RETRY re-sends what the user actually
    /// asked rather than an approximation. Nil when the turn cannot be rebuilt —
    /// a photo turn, for instance, whose prepared image is not retained.
    let retry: RetryPayload?

    struct RetryPayload: Codable, Sendable, Equatable {
        let userText: String
        let referencedItem: ReferencedItem?
        let isNewRecipe: Bool
    }

    /// True when the UI should show a RETRY control: the failure class allows it
    /// *and* there is a turn to send again.
    var canRetry: Bool { failure.isRetryable && retry != nil }
}

struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: MessageRole
    let text: String
    let timestamp: Date
    /// Relative path to an on-device JPEG, e.g. "<recipeID>/<messageID>.jpg".
    /// Nil for messages with no photo attachment.
    let photoPath: String?
    /// Non-nil when this bubble reports a failed turn. Optional so snapshots
    /// written before Milestone 30 still decode, and so the transcript can filter
    /// error chrome out of the conversation history sent to the model.
    let failure: ChatFailureRecord?

    init(
        role: MessageRole,
        text: String,
        timestamp: Date = .now,
        photoPath: String? = nil,
        failure: ChatFailureRecord? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.photoPath = photoPath
        self.failure = failure
    }

    /// Full memberwise init for cases where a stable ID is required before message creation.
    init(
        id: UUID,
        role: MessageRole,
        text: String,
        timestamp: Date = .now,
        photoPath: String? = nil,
        failure: ChatFailureRecord? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.photoPath = photoPath
        self.failure = failure
    }
}

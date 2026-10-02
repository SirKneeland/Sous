import Foundation

/// What the user can do about a failed chat turn.
///
/// This is the whole point of Milestone 30: a failure is not one thing. A dropped
/// connection and an expired subscription both end a turn, but only one of them is
/// worth a RETRY button — offering RETRY on the other just walks the user into the
/// same wall a second time.
public enum ChatFailureKind: Equatable, Sendable, Codable {
    /// Transient. The same turn, re-sent unchanged, has a good chance of working.
    case retryable
    /// The turn itself is the problem (malformed request, off-topic, unparseable
    /// answer). RETRY is still offered — the model is not deterministic — but the
    /// copy asks for a reword rather than promising a different outcome.
    case rephrase
    /// Nothing to retry. Something outside this turn has to change first: a
    /// subscription, a sign-in, an API key.
    case wall(ChatFailureWall)
}

/// Which wall was hit, so the UI can route to the right destination rather than
/// printing a dead-end sentence.
public enum ChatFailureWall: Equatable, Sendable, Codable {
    /// Recipe cap reached (proxy HTTP 402). Routes to the billing surface.
    case cap
    /// Session or API key rejected (HTTP 401/403). Routes to sign-in.
    case auth
    /// No API key configured at all (BYOK).
    case missingKey
}

/// A classified chat failure: what happened, what the user is told, and what they
/// can do about it.
///
/// Construct it with `ChatFailure.classify(_:)` — the mapping table is the single
/// place that decides retryability, and it is exhaustive over `LLMError` on purpose
/// so a new error case cannot be added without deciding what the user sees.
public struct ChatFailure: Equatable, Sendable, Codable {
    public let kind: ChatFailureKind
    /// User-facing copy, in Sous's voice. Never a raw API message.
    public let message: String

    public init(kind: ChatFailureKind, message: String) {
        self.kind = kind
        self.message = message
    }

    /// True when the UI should show a RETRY control under this failure.
    public var isRetryable: Bool {
        switch kind {
        case .retryable, .rephrase: return true
        case .wall:                 return false
        }
    }

    /// The wall this failure hit, if any.
    public var wall: ChatFailureWall? {
        if case .wall(let w) = kind { return w }
        return nil
    }

    // MARK: - Classification

    public static func classify(_ error: LLMError) -> ChatFailure {
        switch error {

        // ── Walls: retrying changes nothing ──────────────────────────────────
        case .capReached:
            return ChatFailure(
                kind: .wall(.cap),
                message: "You've used all the recipes in your plan for now."
            )
        case .auth:
            return ChatFailure(
                kind: .wall(.auth),
                message: "I couldn't verify your account. Try signing in again."
            )
        case .missingAPIKey:
            return ChatFailure(
                kind: .wall(.missingKey),
                message: "There's no API key set. Add one in Settings and I'll pick up where we left off."
            )

        // ── Transient: the same turn is worth sending again ───────────────────
        case .network:
            return ChatFailure(
                kind: .retryable,
                message: "I couldn't connect. Check your network and try again."
            )
        case .timeout:
            return ChatFailure(
                kind: .retryable,
                message: "That took too long to come back."
            )
        case .cancelled:
            return ChatFailure(
                kind: .retryable,
                message: "That got interrupted before I could answer."
            )
        case .server:
            return ChatFailure(
                kind: .retryable,
                message: "Something went wrong on my end."
            )
        case .rateLimited(let retryAfterSec):
            return ChatFailure(
                kind: .retryable,
                message: rateLimitMessage(retryAfterSec: retryAfterSec)
            )

        // ── The turn itself needs to change ───────────────────────────────────
        case .offTopic(let backendMessage):
            return ChatFailure(
                kind: .rephrase,
                message: backendMessage ?? "I'm your cooking assistant — ask me about a recipe, a technique, or an ingredient."
            )
        case .badRequest:
            return ChatFailure(
                kind: .rephrase,
                message: "I couldn't make sense of that one. Try wording it differently."
            )
        case .decodeNonJSON, .decodeInvalidJSON, .schemaInvalid,
             .validationRecoverable, .validationFatal, .recipeIdMismatchFatal:
            return ChatFailure(
                kind: .rephrase,
                message: "I had trouble putting my answer together."
            )
        case .validationExpired:
            return ChatFailure(
                kind: .rephrase,
                message: "The recipe changed while I was thinking."
            )
        }
    }

    /// A rate limit with a short, credible wait names the wait; anything longer or
    /// absent stays vague rather than promising a number we don't trust.
    private static func rateLimitMessage(retryAfterSec: Int?) -> String {
        guard let seconds = retryAfterSec, seconds > 0, seconds <= 120 else {
            return "I'm being asked to slow down. Try again in a moment."
        }
        let unit = seconds == 1 ? "second" : "seconds"
        return "I'm being asked to slow down. Try again in \(seconds) \(unit)."
    }
}

import Foundation

// MARK: - MultimodalSuggestion

/// A single structured suggestion from a zero-patch multimodal assistant response.
///
/// **Identity semantics:** `localId` is generated client-side (UUID) at decode time.
/// It is NOT backend-assigned, NOT persisted, and NOT stable across sessions or app launches.
/// It exists solely for SwiftUI `List` identity within one response lifecycle.
public struct MultimodalSuggestion: Equatable, Identifiable, Sendable {
    public let localId: UUID
    /// Satisfies `Identifiable`. Backed by `localId` — local-only, not backend-assigned.
    public var id: UUID { localId }
    /// Short, displayable label (e.g. "Reduce heat to medium").
    public let headline: String
    /// Optional expanded explanation shown on tap.
    public let detail: String?

    public init(localId: UUID = UUID(), headline: String, detail: String? = nil) {
        self.localId = localId
        self.headline = headline
        self.detail = detail
    }
}

// MARK: - MultimodalAssistantPayload

/// What a successful multimodal assistant response contains.
///
/// This type represents only genuine assistant-authored output.
/// Network errors, validation failures, and client-synthesized messages
/// must never appear here — those belong in `MultimodalFailure`.
///
/// **Patch safety invariant:** A `patchProposal` carries a `PatchSet` as proposed intent only.
/// It must be routed through `PatchValidator → user review → PatchApplier`.
/// Receipt of this type must never directly mutate recipe state.
///
/// **No-patch invariant:** `suggestionsOnly` carries zero `PatchSet` reference.
/// It must never create a `pendingPatchSet` or trigger patch review.
public enum MultimodalAssistantPayload: Equatable, Sendable {

    /// Conversational reply with zero or more structured suggestions.
    ///
    /// `suggestions` may be empty (pure conversational exchange with no actionable items).
    /// INVARIANT: must never create a `pendingPatchSet` or mutate recipe state.
    /// Maps to `LLMResult.noPatches` at the orchestrator boundary.
    case suggestionsOnly(
        assistantMessage: String,
        suggestions: [MultimodalSuggestion]
    )

    /// Proposed recipe edit from the assistant.
    ///
    /// INVARIANT: `patchSet` is proposed intent, not applied mutation.
    /// Must be routed through `PatchValidator → user review → PatchApplier` —
    /// the same path as all text-based LLM patch proposals.
    /// Maps to `LLMResult.valid` (after validation passes) at the orchestrator boundary.
    case patchProposal(
        assistantMessage: String,
        patchSet: PatchSet
    )
}

// MARK: - MultimodalFailure

/// A structured failure from the multimodal send pipeline.
///
/// Failures are separate from assistant payloads. A network error, auth failure,
/// or validation rejection is not a kind of assistant response.
///
/// The `retryable` / `terminal` distinction mirrors the existing `LLMError` taxonomy
/// used by `OpenAILLMOrchestrator`.
public enum MultimodalFailure: Equatable, Sendable {
    /// Network, timeout, decode, or recoverable validation error.
    /// The orchestrator may retry within its budget before surfacing this.
    case retryable(LLMError)

    /// Auth, fatal validation, recipe ID mismatch, or budget exhaustion.
    /// Must not be retried. Surfaces an error state; no recipe state mutation.
    case terminal(LLMError)
}

// MARK: - MultimodalSendOutcome

/// The result of one complete multimodal send attempt.
///
/// One success channel and one failure channel — no mixing.
/// Consumed exactly once by the store/coordinator; see `PhotoSendState` for lifecycle.
public enum MultimodalSendOutcome: Equatable, Sendable {
    case success(MultimodalAssistantPayload)
    case failure(MultimodalFailure)
}

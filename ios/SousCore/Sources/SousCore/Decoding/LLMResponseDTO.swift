import Foundation

// MARK: - Internal LLM Response DTOs
//
// All types are internal to SousCore.
// Exposed to callers only through PatchSetDecoder.DecodeResult.

// MARK: - LLMResponseDTO

/// Top-level envelope decoded from an LLM response string.
struct LLMResponseDTO: Equatable, Sendable {
    /// Short conversational reply from the assistant.
    let assistantMessage: String
    /// Proposed recipe mutations, or nil when the response is conversational only.
    let patchSet: LLMPatchSetDTO?
}

// MARK: - LLMPatchSetDTO

/// The structured patchSet payload within the LLM response.
struct LLMPatchSetDTO: Equatable, Sendable {
    let patchSetId: String
    let baseRecipeId: String
    let baseRecipeVersion: Int
    let patches: [LLMPatchOpDTO]
    let summary: LLMSummaryDTO?
}

// MARK: - LLMPatchOpDTO

/// A fully decoded patch operation. IDs are raw strings; UUID parsing happens at the
/// orchestrator boundary when converting to the canonical Patch enum.
enum LLMPatchOpDTO: Equatable, Sendable {
    case addIngredient(text: String, afterId: String?)
    case updateIngredient(id: String, text: String)
    case removeIngredient(id: String)
    case addStep(text: String, afterStepId: String?)
    case updateStep(id: String, text: String)
    case removeStep(id: String)
    case addNote(text: String)
    case setTitle(title: String)
}

// MARK: - LLMSummaryDTO

/// Optional human-readable summary attached to a patchSet.
struct LLMSummaryDTO: Equatable, Sendable {
    let title: String?
    let bullets: [String]?
}

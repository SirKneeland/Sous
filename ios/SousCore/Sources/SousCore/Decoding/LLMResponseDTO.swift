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
    /// Optional memory the model proposes to save. Nil when the model does not suggest a memory.
    let proposedMemory: String?
    /// When true (exploration phase only), the model has enough information to generate an
    /// excellent recipe and is signalling readiness. Absence or false means not yet ready.
    let suggestGenerate: Bool?
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
    case addIngredient(text: String, afterId: String?, groupId: String?)
    case updateIngredient(id: String, text: String)
    case removeIngredient(id: String)
    case addIngredientGroup(afterGroupId: String?, header: String?, clientId: String?)
    case updateIngredientGroup(id: String, header: String?)
    case removeIngredientGroup(id: String)
    /// `clientId` is a model-assigned temporary reference; `parentId` links to a parent step.
    case addStep(text: String, afterId: String?, parentId: String?, clientId: String?)
    case updateStep(id: String, text: String)
    case removeStep(id: String)
    case setTitle(title: String)
    case setStepNotes(stepId: String, notes: [String])
    case addNoteSection(afterId: String?, header: String?, items: [String])
    case updateNoteSection(id: String, header: String?, items: [String])
    case removeNoteSection(id: String)
}

// MARK: - LLMSummaryDTO

/// Optional human-readable summary attached to a patchSet.
struct LLMSummaryDTO: Equatable, Sendable {
    let title: String?
    let bullets: [String]?
}

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

/// Placeholder for a single patch operation.
/// PatchSetDecoder verifies each element is a JSON object and the array is non-empty.
/// Field-level typing (operation type, target IDs) is handled by the SousApp conversion layer.
struct LLMPatchOpDTO: Equatable, Sendable {}

// MARK: - LLMSummaryDTO

/// Optional human-readable summary attached to a patchSet.
struct LLMSummaryDTO: Equatable, Sendable {
    let title: String?
    let bullets: [String]?
}

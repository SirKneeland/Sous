import Foundation

// MARK: - MultimodalLLMRequest

/// Input snapshot for a multimodal orchestrator call.
///
/// Mirrors `LLMRequest` fields via composition. The `base` field carries all
/// recipe/context/prefs data; `image` adds the prepared image payload.
///
/// **Construction order:** `ImageAsset` must be preprocessed into `PreparedImage`
/// before this type is constructed. The `ImageAsset` should be released at that point.
/// This type never holds raw acquisition bytes.
///
/// Integration note: `MultimodalLLMRequest` is not yet wired into `LLMOrchestrator`.
/// That connection is a follow-up step.
public struct MultimodalLLMRequest: Sendable {

    /// All recipe, user message, prefs, and context fields — identical semantics to a
    /// standard text `LLMRequest`.
    public let base: LLMRequest

    /// Prepared (compressed/resized) image payload to include in the multimodal prompt.
    public let image: PreparedImage

    public init(base: LLMRequest, image: PreparedImage) {
        self.base = base
        self.image = image
    }
}

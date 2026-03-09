import Foundation

// MARK: - ImagePreparator

/// Converts an ephemeral `ImageAsset` into an upload-ready `PreparedImage`.
///
/// Implementations perform resizing, JPEG compression, and budget gating.
/// The protocol is synchronous: all work is CPU-bound; callers choose
/// which executor to dispatch onto.
///
/// **Boundary contract:**
/// - `ImageAsset` is consumed by this call. The caller should release it immediately after.
/// - On `.success`, the returned `PreparedImage` is the canonical upload payload.
/// - On `.failure`, recipe state and pending patch state are unaffected.
///   The failure maps to `MultimodalSendOutcome.failure(.retryable/terminal(...))` at the
///   call site — not into `MultimodalAssistantPayload`.
public protocol ImagePreparator: Sendable {
    func prepare(
        _ asset: ImageAsset,
        config: ImagePreparationConfig
    ) -> Result<PreparedImage, ImagePreparationFailure>
}

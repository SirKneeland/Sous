import Foundation
import SousCore

// MARK: - PhotoSendState

/// Ephemeral UI state for the photo capture → send lifecycle.
///
/// **Lives in SousApp, not SousCore.** This type is never imported by the core module.
///
/// **Transient terminal state:** `.done` is a one-shot terminal state.
/// Upon observing `.done(outcome)`, the store or coordinator must:
///   1. Dispatch the outcome to the appropriate channel (chat message, patch proposal, error).
///   2. Reset `PhotoSendState` to `.idle` immediately after dispatch.
///
/// `.done` must not be held as a persistent renderable state across renders.
/// Holding it risks stale replay or duplicate result handling.
///
/// **No image data retained:** `ImageAsset` and `PreparedImage` are never stored in this
/// enum. They exist only during `.preparing` and `.sending` respectively, at the call site,
/// and are released before the transition to `.done`.
public enum PhotoSendState: Equatable {
    /// No photo flow in progress.
    case idle

    /// Image resize/compress is in progress. `ImageAsset` is live at the call site.
    case preparing

    /// Network request is in flight. `PreparedImage` is live at the call site.
    case sending

    /// Terminal state. Contains the send outcome (success or failure).
    ///
    /// Consumed once, then reset to `.idle`. See type-level doc for consumption contract.
    case done(MultimodalSendOutcome)
}

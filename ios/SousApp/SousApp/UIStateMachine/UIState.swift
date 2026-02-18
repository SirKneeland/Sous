import Foundation
import SousCore

// MARK: - HiddenContext

/// Accumulates silent system context strings (e.g. patch rejection facts)
/// that must be prepended to the next LLM user message but never shown to the user.
public struct HiddenContext: Equatable, Sendable {
    public var entries: [String]

    public init(entries: [String] = []) {
        self.entries = entries
    }

    /// Returns a new HiddenContext with `entry` appended.
    public func appending(_ entry: String) -> HiddenContext {
        HiddenContext(entries: entries + [entry])
    }
}

// MARK: - UIState

public enum UIState: Equatable {
    /// No chat panel. Recipe canvas is visible.
    case recipeOnly(recipe: Recipe)

    /// Chat panel is open. User is composing a message.
    case chatOpen(recipe: Recipe, draftUserText: String, hidden: HiddenContext)

    /// An LLM response with a PatchSet has arrived; not yet validated.
    case patchProposed(recipe: Recipe, patchSet: PatchSet, validation: PatchValidationResult?, hidden: HiddenContext)

    /// Patch has been validated and is awaiting Accept or Reject from the user.
    case patchReview(recipe: Recipe, patchSet: PatchSet, validation: PatchValidationResult, hidden: HiddenContext)
}

// MARK: - UIEvent

public enum UIEvent {
    case openChat
    case closeChat
    case userDraftChanged(String)
    case patchReceived(PatchSet)
    case validatePatch
    case acceptPatch
    /// Discard the patch and return to chat. `userText` becomes the new draft.
    /// The rejection fact is embedded silently in `HiddenContext`.
    case rejectPatch(userText: String)
}

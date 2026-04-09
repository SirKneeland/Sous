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

// MARK: - UIState helpers

extension UIState {
    /// The recipe embedded in the current state, regardless of which state it is.
    public var recipe: Recipe {
        switch self {
        case .recipeOnly(let r):             return r
        case .chatOpen(let r, _, _):         return r
        case .patchProposed(let r, _, _, _): return r
        case .patchReview(let r, _, _, _):   return r
        }
    }

    /// Returns a copy of the current state with the recipe replaced.
    /// All other associated values (draft text, patchSet, hidden context, etc.) are preserved.
    public func replacingRecipe(_ newRecipe: Recipe) -> UIState {
        switch self {
        case .recipeOnly:
            return .recipeOnly(recipe: newRecipe)
        case .chatOpen(_, let draft, let hidden):
            return .chatOpen(recipe: newRecipe, draftUserText: draft, hidden: hidden)
        case .patchProposed(_, let ps, let validation, let hidden):
            return .patchProposed(recipe: newRecipe, patchSet: ps, validation: validation, hidden: hidden)
        case .patchReview(_, let ps, let validation, let hidden):
            return .patchReview(recipe: newRecipe, patchSet: ps, validation: validation, hidden: hidden)
        }
    }
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
    /// User taps a todo step to mark it done. One-way; done steps are immutable.
    case markStepDone(stepId: UUID)
    /// User taps a todo sub-step to mark it done. One-way; done sub-steps are immutable.
    case markSubStepDone(parentStepId: UUID, subStepId: UUID)
}

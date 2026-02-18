import Foundation
import SousCore

// MARK: - UIStateMachine

/// Pure deterministic reducer for app-layer UI state.
/// No stored state — all transitions are functions of (state, event) → state.
public enum UIStateMachine {

    public static func reduce(_ state: UIState, _ event: UIEvent) -> UIState {
        switch (state, event) {

        // MARK: recipeOnly transitions

        case (.recipeOnly(let recipe), .openChat):
            return .chatOpen(recipe: recipe, draftUserText: "", hidden: HiddenContext())

        // MARK: chatOpen transitions

        case (.chatOpen(let recipe, _, _), .closeChat):
            return .recipeOnly(recipe: recipe)

        case (.chatOpen(let recipe, _, let hidden), .userDraftChanged(let text)):
            return .chatOpen(recipe: recipe, draftUserText: text, hidden: hidden)

        case (.chatOpen(let recipe, _, let hidden), .patchReceived(let patchSet)):
            return .patchProposed(recipe: recipe, patchSet: patchSet, validation: nil, hidden: hidden)

        // MARK: patchProposed transitions

        case (.patchProposed(let recipe, let patchSet, _, let hidden), .validatePatch):
            let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
            return .patchReview(recipe: recipe, patchSet: patchSet, validation: result, hidden: hidden)

        // MARK: patchReview transitions

        case (.patchReview(let recipe, let patchSet, let validation, let hidden), .acceptPatch):
            guard case .valid = validation else {
                // Cannot apply an invalid patch — remain in patchReview unchanged.
                return state
            }
            guard let updated = try? PatchApplier.apply(patchSet: patchSet, to: recipe) else {
                return state
            }
            return .recipeOnly(recipe: updated)

        case (.patchReview(let recipe, let patchSet, _, let hidden), .rejectPatch(let userText)):
            let rejection = "PATCH_REJECTED: \(patchSet.patchSetId.uuidString)"
            let newHidden = hidden.appending(rejection)
            return .chatOpen(recipe: recipe, draftUserText: userText, hidden: newHidden)

        // MARK: unhandled combinations — no-op

        default:
            return state
        }
    }
}

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

        // MARK: markStepDone — user-initiated, works in any state, searches full step tree

        case (_, .markStepDone(let stepId)):
            let recipe = state.recipe
            let (updatedSteps, changed) = UIStateMachine.applyToSteps(recipe.steps, id: stepId) { step in
                guard step.effectiveStatus == .todo else { return }
                step.status = .done
            }
            guard changed else { return state }
            let updated = Recipe(
                id: recipe.id,
                version: recipe.version + 1,
                title: recipe.title,
                ingredients: recipe.ingredients,
                steps: updatedSteps,
                notes: recipe.notes,
                miseEnPlace: recipe.miseEnPlace
            )
            return state.replacingRecipe(updated)

        // MARK: markStepUndone — drain-phase cancellation only
        // Reverts a done step back to todo. Only reachable when the drain
        // animation is active; the UI guards the call site.

        case (_, .markStepUndone(let stepId)):
            let recipe = state.recipe
            let (updatedSteps, changed) = UIStateMachine.applyToSteps(recipe.steps, id: stepId) { step in
                guard step.effectiveStatus == .done else { return }
                step.status = .todo
            }
            guard changed else { return state }
            let updated = Recipe(
                id: recipe.id,
                version: recipe.version + 1,
                title: recipe.title,
                ingredients: recipe.ingredients,
                steps: updatedSteps,
                notes: recipe.notes,
                miseEnPlace: recipe.miseEnPlace
            )
            return state.replacingRecipe(updated)

        // MARK: unhandled combinations — no-op

        default:
            return state
        }
    }

    /// Searches `steps` recursively for a step with the given `id`, applies `mutation`, and
    /// returns the updated array along with a flag indicating whether a match was found.
    private static func applyToSteps(
        _ steps: [Step],
        id: UUID,
        mutation: (inout Step) -> Void
    ) -> (steps: [Step], changed: Bool) {
        var changed = false
        let result = steps.map { step -> Step in
            if changed { return step }
            if step.id == id {
                var copy = step
                mutation(&copy)
                changed = copy != step
                return copy
            }
            if let subs = step.subSteps, !subs.isEmpty {
                let (newSubs, subChanged) = applyToSteps(subs, id: id, mutation: mutation)
                if subChanged {
                    changed = true
                    return Step(id: step.id, text: step.text, status: step.status, subSteps: newSubs, notes: step.notes)
                }
            }
            return step
        }
        return (result, changed)
    }
}

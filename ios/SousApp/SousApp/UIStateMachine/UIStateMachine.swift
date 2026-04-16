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

        // MARK: markStepDone — user-initiated, works in any state

        case (_, .markStepDone(let stepId)):
            let recipe = state.recipe
            // No-op if step doesn't exist or is already done (done steps are immutable).
            guard recipe.steps.contains(where: { $0.id == stepId && $0.status == .todo }) else {
                return state
            }
            let updatedSteps = recipe.steps.map { step -> Step in
                guard step.id == stepId else { return step }
                return Step(id: step.id, text: step.text, status: .done)
            }
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
            guard recipe.steps.contains(where: { $0.id == stepId && $0.status == .done }) else {
                return state
            }
            let updatedSteps = recipe.steps.map { step -> Step in
                guard step.id == stepId else { return step }
                return Step(id: step.id, text: step.text, status: .todo)
            }
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

        // MARK: markSubStepDone — user-initiated, works in any state

        case (_, .markSubStepDone(let parentStepId, let subStepId)):
            let recipe = state.recipe
            guard let parentIdx = recipe.steps.firstIndex(where: { $0.id == parentStepId }),
                  let subs = recipe.steps[parentIdx].subSteps,
                  let subIdx = subs.firstIndex(where: { $0.id == subStepId })
            else { return state }
            let subStep = subs[subIdx]
            // No-op if already done (sub-steps are immutable once done).
            guard subStep.effectiveStatus == .todo else { return state }
            var updatedSubSteps = subs
            updatedSubSteps[subIdx] = Step(id: subStep.id, text: subStep.text, status: .done, subSteps: subStep.subSteps)
            let parent = recipe.steps[parentIdx]
            var updatedSteps = recipe.steps
            updatedSteps[parentIdx] = Step(id: parent.id, text: parent.text, status: parent.status, subSteps: updatedSubSteps)
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
}

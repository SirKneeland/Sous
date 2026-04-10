import Foundation

public enum PatchValidationError: Equatable, Sendable {
    case versionMismatch(expected: Int, got: Int)
    case invalidIngredientId(UUID)
    case invalidStepId(UUID)
    case stepDoneImmutable(UUID)
    case internalConflict(String)
    case recipeIdMismatch(expected: UUID, got: UUID)
    /// The referenced sub-step ID does not exist on its parent step.
    case invalidSubStepId(UUID)
    /// A completeSubStep was attempted on a parent step whose effectiveStatus is already .done.
    case parentStepDone(UUID)
    /// A patch introduces text containing an ingredient that matches a hard-avoid preference.
    case hardAvoidViolation(ingredient: String)

    public var code: PatchValidationErrorCode {
        switch self {
        case .versionMismatch:
            return .VERSION_MISMATCH
        case .recipeIdMismatch:
            return .INTERNAL_CONFLICT
        case .invalidIngredientId:
            return .INVALID_INGREDIENT_ID
        case .invalidStepId:
            return .INVALID_STEP_ID
        case .stepDoneImmutable:
            return .STEP_DONE_IMMUTABLE
        case .internalConflict:
            return .INTERNAL_CONFLICT
        case .invalidSubStepId:
            return .INVALID_SUBSTEP_ID
        case .parentStepDone:
            return .PARENT_STEP_DONE
        case .hardAvoidViolation:
            return .HARD_AVOID_VIOLATION
        }
    }
}

public enum PatchValidationErrorCode: String, Sendable {
    case VERSION_MISMATCH
    case INVALID_INGREDIENT_ID
    case INVALID_STEP_ID
    case STEP_DONE_IMMUTABLE
    case INTERNAL_CONFLICT
    case INVALID_SUBSTEP_ID
    case PARENT_STEP_DONE
    case HARD_AVOID_VIOLATION
}

public enum PatchValidationResult: Equatable, Sendable {
    case valid
    case invalid([PatchValidationError])
}

public enum PatchValidator {
    /// Returns the first hard-avoid keyword found as a case-insensitive substring in `text`, or nil.
    private static func hardAvoidMatch(in text: String, hardAvoids: [String]) -> String? {
        let lower = text.lowercased()
        return hardAvoids.first { lower.contains($0.lowercased()) }
    }

    public static func validate(patchSet: PatchSet, recipe: Recipe, hardAvoids: [String] = []) -> PatchValidationResult {
        var errors: [PatchValidationError] = []

        // Version check
        if patchSet.baseRecipeVersion != recipe.version {
            errors.append(.versionMismatch(expected: recipe.version, got: patchSet.baseRecipeVersion))
        }

        // Track IDs that will be removed mid-set to catch internal conflicts
        var removedIngredientIds: Set<UUID> = []
        var removedStepIds: Set<UUID> = []
        var removedSubStepIds: Set<UUID> = []

        for patch in patchSet.patches {
            switch patch {
            case .addIngredient(let text, let afterId):
                if let match = hardAvoidMatch(in: text, hardAvoids: hardAvoids) {
                    errors.append(.hardAvoidViolation(ingredient: match))
                }
                if let afterId = afterId {
                    let existsInRecipe = recipe.ingredients.contains { $0.id == afterId }
                    let alreadyRemoved = removedIngredientIds.contains(afterId)
                    if !existsInRecipe || alreadyRemoved {
                        errors.append(.invalidIngredientId(afterId))
                    }
                }

            case .updateIngredient(let id, let text):
                if let match = hardAvoidMatch(in: text, hardAvoids: hardAvoids) {
                    errors.append(.hardAvoidViolation(ingredient: match))
                }
                let existsInRecipe = recipe.ingredients.contains { $0.id == id }
                let alreadyRemoved = removedIngredientIds.contains(id)
                if !existsInRecipe || alreadyRemoved {
                    errors.append(.invalidIngredientId(id))
                }

            case .removeIngredient(let id):
                let existsInRecipe = recipe.ingredients.contains { $0.id == id }
                let alreadyRemoved = removedIngredientIds.contains(id)
                if !existsInRecipe || alreadyRemoved {
                    errors.append(.invalidIngredientId(id))
                } else {
                    removedIngredientIds.insert(id)
                }

            case .addStep(let text, let afterStepId, _):
                if let match = hardAvoidMatch(in: text, hardAvoids: hardAvoids) {
                    errors.append(.hardAvoidViolation(ingredient: match))
                }
                if let afterStepId = afterStepId {
                    let existsInRecipe = recipe.steps.contains { $0.id == afterStepId }
                    let alreadyRemoved = removedStepIds.contains(afterStepId)
                    if !existsInRecipe || alreadyRemoved {
                        errors.append(.invalidStepId(afterStepId))
                    }
                }

            case .updateStep(let id, let text):
                if let match = hardAvoidMatch(in: text, hardAvoids: hardAvoids) {
                    errors.append(.hardAvoidViolation(ingredient: match))
                }
                let alreadyRemoved = removedStepIds.contains(id)
                guard let step = recipe.steps.first(where: { $0.id == id }), !alreadyRemoved else {
                    errors.append(.invalidStepId(id))
                    break
                }
                if step.status == .done {
                    errors.append(.stepDoneImmutable(id))
                }
                
            case .removeStep(let id):
                let existsInRecipe = recipe.steps.contains { $0.id == id }
                let alreadyRemoved = removedStepIds.contains(id)
                if !existsInRecipe || alreadyRemoved {
                    errors.append(.invalidStepId(id))
                    break
                }

                // done steps are immutable
                if let step = recipe.steps.first(where: { $0.id == id }), step.status == .done {
                    errors.append(.stepDoneImmutable(id))
                    break
                }

                removedStepIds.insert(id)

            case .addNote:
                break

            case .setTitle:
                break

            case .addSubStep(let parentStepId, let text, let afterSubStepId):
                if let match = hardAvoidMatch(in: text, hardAvoids: hardAvoids) {
                    errors.append(.hardAvoidViolation(ingredient: match))
                }
                let parentRemoved = removedStepIds.contains(parentStepId)
                guard let parent = recipe.steps.first(where: { $0.id == parentStepId }), !parentRemoved else {
                    errors.append(.invalidStepId(parentStepId))
                    break
                }
                if let afterSubStepId = afterSubStepId {
                    let existsInParent = parent.subSteps?.contains { $0.id == afterSubStepId } ?? false
                    let alreadyRemovedSub = removedSubStepIds.contains(afterSubStepId)
                    if !existsInParent || alreadyRemovedSub {
                        errors.append(.invalidSubStepId(afterSubStepId))
                    }
                }

            case .updateSubStep(let parentStepId, let subStepId, _):
                let parentRemoved = removedStepIds.contains(parentStepId)
                guard let parent = recipe.steps.first(where: { $0.id == parentStepId }), !parentRemoved else {
                    errors.append(.invalidStepId(parentStepId))
                    break
                }
                let existsInParent = parent.subSteps?.contains { $0.id == subStepId } ?? false
                let alreadyRemovedSub = removedSubStepIds.contains(subStepId)
                if !existsInParent || alreadyRemovedSub {
                    errors.append(.invalidSubStepId(subStepId))
                }

            case .removeSubStep(let parentStepId, let subStepId):
                let parentRemoved = removedStepIds.contains(parentStepId)
                guard let parent = recipe.steps.first(where: { $0.id == parentStepId }), !parentRemoved else {
                    errors.append(.invalidStepId(parentStepId))
                    break
                }
                let existsInParent = parent.subSteps?.contains { $0.id == subStepId } ?? false
                let alreadyRemovedSub = removedSubStepIds.contains(subStepId)
                if !existsInParent || alreadyRemovedSub {
                    errors.append(.invalidSubStepId(subStepId))
                } else {
                    removedSubStepIds.insert(subStepId)
                }

            case .completeSubStep(let parentStepId, let subStepId):
                let parentRemoved = removedStepIds.contains(parentStepId)
                guard let parent = recipe.steps.first(where: { $0.id == parentStepId }), !parentRemoved else {
                    errors.append(.invalidStepId(parentStepId))
                    break
                }
                let existsInParent = parent.subSteps?.contains { $0.id == subStepId } ?? false
                let alreadyRemovedSub = removedSubStepIds.contains(subStepId)
                if !existsInParent || alreadyRemovedSub {
                    errors.append(.invalidSubStepId(subStepId))
                    break
                }
                if parent.effectiveStatus == .done {
                    errors.append(.parentStepDone(parentStepId))
                }
            }
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

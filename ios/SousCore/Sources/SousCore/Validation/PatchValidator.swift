import Foundation

public enum PatchValidationError: Equatable, Sendable {
    case versionMismatch(expected: Int, got: Int)
    case invalidIngredientId(UUID)
    case invalidStepId(UUID)
    case stepDoneImmutable(UUID)
    case internalConflict(String)
    case recipeIdMismatch(expected: UUID, got: UUID)

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
        }
    }
}

public enum PatchValidationErrorCode: String, Sendable {
    case VERSION_MISMATCH
    case INVALID_INGREDIENT_ID
    case INVALID_STEP_ID
    case STEP_DONE_IMMUTABLE
    case INTERNAL_CONFLICT
}

public enum PatchValidationResult: Equatable, Sendable {
    case valid
    case invalid([PatchValidationError])
}

public enum PatchValidator {
    public static func validate(patchSet: PatchSet, recipe: Recipe) -> PatchValidationResult {
        var errors: [PatchValidationError] = []

        // Version check
        if patchSet.baseRecipeVersion != recipe.version {
            errors.append(.versionMismatch(expected: recipe.version, got: patchSet.baseRecipeVersion))
        }

        // Track IDs that will be removed mid-set to catch internal conflicts
        var removedIngredientIds: Set<UUID> = []
        var removedStepIds: Set<UUID> = []

        for patch in patchSet.patches {
            switch patch {
            case .addIngredient(_, let afterId):
                if let afterId = afterId {
                    let existsInRecipe = recipe.ingredients.contains { $0.id == afterId }
                    let alreadyRemoved = removedIngredientIds.contains(afterId)
                    if !existsInRecipe || alreadyRemoved {
                        errors.append(.invalidIngredientId(afterId))
                    }
                }

            case .updateIngredient(let id, _):
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

            case .addStep(_, let afterStepId):
                if let afterStepId = afterStepId {
                    let existsInRecipe = recipe.steps.contains { $0.id == afterStepId }
                    let alreadyRemoved = removedStepIds.contains(afterStepId)
                    if !existsInRecipe || alreadyRemoved {
                        errors.append(.invalidStepId(afterStepId))
                    }
                }

            case .updateStep(let id, _):
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
            }
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

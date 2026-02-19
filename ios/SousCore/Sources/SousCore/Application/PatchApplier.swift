import Foundation

public enum PatchApplierError: Error, Equatable {
    case validationFailed([PatchValidationError])
}

public enum PatchApplier {
    public static func apply(patchSet: PatchSet, to recipe: Recipe) throws -> Recipe {
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        guard case .valid = result else {
            if case .invalid(let errors) = result {
                throw PatchApplierError.validationFailed(errors)
            }
            throw PatchApplierError.validationFailed([])
        }

        // Work on a mutable copy — atomic: either all succeed or we throw before returning
        var ingredients = recipe.ingredients
        var steps = recipe.steps
        var notes = recipe.notes

        for patch in patchSet.patches {
            switch patch {
            case .addIngredient(let text, let afterId):
                let newIngredient = Ingredient(text: text)
                if let afterId = afterId, let idx = ingredients.firstIndex(where: { $0.id == afterId }) {
                    ingredients.insert(newIngredient, at: idx + 1)
                } else {
                    ingredients.append(newIngredient)
                }

            case .updateIngredient(let id, let text):
                guard let idx = ingredients.firstIndex(where: { $0.id == id }) else {
                    // Validator already caught this — should not reach here
                    throw PatchApplierError.validationFailed([.invalidIngredientId(id)])
                }
                ingredients[idx].text = text

            case .removeIngredient(let id):
                ingredients.removeAll { $0.id == id }

            case .addStep(let text, let afterStepId):
                let newStep = Step(text: text, status: .todo)
                if let afterStepId = afterStepId, let idx = steps.firstIndex(where: { $0.id == afterStepId }) {
                    steps.insert(newStep, at: idx + 1)
                } else {
                    steps.append(newStep)
                }

            case .updateStep(let id, let text):
                guard let idx = steps.firstIndex(where: { $0.id == id }) else {
                    throw PatchApplierError.validationFailed([.invalidStepId(id)])
                }
                steps[idx].text = text
                
            case .removeStep(let id):
                steps.removeAll { $0.id == id }

            case .addNote(let text):
                notes.append(text)
            }
        }

        return Recipe(
            id: recipe.id,
            version: recipe.version + 1,
            title: recipe.title,
            ingredients: ingredients,
            steps: steps,
            notes: notes
        )
    }
}

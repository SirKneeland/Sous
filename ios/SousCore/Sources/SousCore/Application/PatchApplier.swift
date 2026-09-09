import Foundation

public enum PatchApplierError: Error, Equatable {
    case validationFailed([PatchValidationError])
}

public enum PatchApplier {
    private static func applyToStep(id: UUID, in steps: [Step], mutation: (inout Step) -> Void) -> [Step] {
        steps.map { step in
            var mutableStep = step
            if mutableStep.id == id {
                mutation(&mutableStep)
            } else if mutableStep.subSteps != nil {
                mutableStep.subSteps = applyToStep(id: id, in: mutableStep.subSteps!, mutation: mutation)
            }
            return mutableStep
        }
    }

    private static func removeStepFromTree(id: UUID, steps: [Step]) -> [Step] {
        steps.compactMap { step in
            if step.id == id { return nil }
            var mutableStep = step
            if let subs = mutableStep.subSteps {
                mutableStep.subSteps = removeStepFromTree(id: id, steps: subs)
            }
            return mutableStep
        }
    }

    public static func apply(patchSet: PatchSet, to recipe: Recipe) throws -> Recipe {
        let result = PatchValidator.validate(patchSet: patchSet, recipe: recipe)
        guard case .valid = result else {
            if case .invalid(let errors) = result {
                throw PatchApplierError.validationFailed(errors)
            }
            throw PatchApplierError.validationFailed([])
        }

        var newTitle = recipe.title
        var ingredients = recipe.ingredients
        var steps = recipe.steps
        var notes = recipe.notes
        var miseEnPlace = recipe.miseEnPlace

        for patch in patchSet.patches {
            switch patch {
            case .setTitle(let title):
                newTitle = title

            case .addIngredient(let groupId, let afterId, let text):
                let newIngredient = Ingredient(text: text)
                if let groupId = groupId, let gIdx = ingredients.firstIndex(where: { $0.id == groupId }) {
                    if let afterId = afterId, let iIdx = ingredients[gIdx].items.firstIndex(where: { $0.id == afterId }) {
                        ingredients[gIdx].items.insert(newIngredient, at: iIdx + 1)
                    } else {
                        ingredients[gIdx].items.append(newIngredient)
                    }
                } else {
                    if ingredients.isEmpty {
                        ingredients.append(IngredientGroup(items: [newIngredient]))
                    } else {
                        if let afterId = afterId, let iIdx = ingredients[0].items.firstIndex(where: { $0.id == afterId }) {
                            ingredients[0].items.insert(newIngredient, at: iIdx + 1)
                        } else {
                            ingredients[0].items.append(newIngredient)
                        }
                    }
                }

            case .updateIngredient(let id, let text):
                for gIdx in ingredients.indices {
                    if let iIdx = ingredients[gIdx].items.firstIndex(where: { $0.id == id }) {
                        ingredients[gIdx].items[iIdx].text = text
                        break
                    }
                }

            case .removeIngredient(let id):
                for gIdx in ingredients.indices {
                    ingredients[gIdx].items.removeAll { $0.id == id }
                }

            case .addIngredientGroup(let afterGroupId, let header, let preassignedId):
                let newGroup = IngredientGroup(id: preassignedId ?? UUID(), header: header, items: [])
                if let afterGroupId = afterGroupId, let idx = ingredients.firstIndex(where: { $0.id == afterGroupId }) {
                    ingredients.insert(newGroup, at: idx + 1)
                } else {
                    ingredients.append(newGroup)
                }

            case .updateIngredientGroup(let id, let header):
                if let idx = ingredients.firstIndex(where: { $0.id == id }) {
                    ingredients[idx].header = header
                }

            case .removeIngredientGroup(let id):
                ingredients.removeAll { $0.id == id }

            case .addStep(let parentId, let afterId, let text, let preassignedId):
                let stepId = preassignedId ?? UUID()
                let newStep = Step(id: stepId, text: text, status: .todo)
                if let parentId = parentId {
                    steps = applyToStep(id: parentId, in: steps) { parent in
                        var subs = parent.subSteps ?? []
                        if let afterId = afterId, let subIdx = subs.firstIndex(where: { $0.id == afterId }) {
                            subs.insert(newStep, at: subIdx + 1)
                        } else {
                            subs.append(newStep)
                        }
                        parent.subSteps = subs
                    }
                } else {
                    if let afterId = afterId, let idx = steps.firstIndex(where: { $0.id == afterId }) {
                        steps.insert(newStep, at: idx + 1)
                    } else {
                        steps.append(newStep)
                    }
                }

            case .updateStep(let id, let text):
                steps = applyToStep(id: id, in: steps) { step in
                    step.text = text
                }

            case .removeStep(let id):
                steps = removeStepFromTree(id: id, steps: steps)

            case .setStepNotes(let stepId, let notesList):
                steps = applyToStep(id: stepId, in: steps) { step in
                    step.notes = notesList
                }

            case .addMiseEnPlaceEntry(let afterId, let vesselName, let items, let preassignedId):
                let entryId = preassignedId ?? UUID()
                let newEntry: MiseEnPlaceEntry
                if let vesselName = vesselName {
                    let components = items.map { MiseEnPlaceComponent(text: $0) }
                    newEntry = MiseEnPlaceEntry(id: entryId, content: .group(vesselName: vesselName, components: components))
                } else {
                    // Validation guarantees exactly one item for a solo entry.
                    newEntry = MiseEnPlaceEntry(id: entryId, content: .solo(instruction: items.first ?? "", isDone: false))
                }
                if miseEnPlace == nil { miseEnPlace = [] }
                if let afterId = afterId, let idx = miseEnPlace!.firstIndex(where: { $0.id == afterId }) {
                    miseEnPlace!.insert(newEntry, at: idx + 1)
                } else {
                    miseEnPlace!.append(newEntry)
                }

            case .updateMiseEnPlaceEntry(let id, let text):
                if let idx = miseEnPlace?.firstIndex(where: { $0.id == id }) {
                    switch miseEnPlace![idx].content {
                    case .group(_, let components):
                        // Renaming the vessel leaves component check state untouched.
                        miseEnPlace![idx] = MiseEnPlaceEntry(id: id, content: .group(vesselName: text, components: components))
                    case .solo:
                        // The instruction changed, so the old "done" assertion no longer
                        // describes what is on the counter — reset it.
                        miseEnPlace![idx] = MiseEnPlaceEntry(id: id, content: .solo(instruction: text, isDone: false))
                    }
                }

            case .removeMiseEnPlaceEntry(let id):
                miseEnPlace?.removeAll { $0.id == id }

            case .addMiseEnPlaceComponent(let entryId, let afterId, let text):
                if let idx = miseEnPlace?.firstIndex(where: { $0.id == entryId }),
                   case .group(let vesselName, var components) = miseEnPlace![idx].content {
                    let newComponent = MiseEnPlaceComponent(text: text)
                    if let afterId = afterId, let cIdx = components.firstIndex(where: { $0.id == afterId }) {
                        components.insert(newComponent, at: cIdx + 1)
                    } else {
                        components.append(newComponent)
                    }
                    miseEnPlace![idx] = MiseEnPlaceEntry(id: entryId, content: .group(vesselName: vesselName, components: components))
                }

            case .updateMiseEnPlaceComponent(let id, let text):
                if let entries = miseEnPlace {
                    for idx in entries.indices {
                        guard case .group(let vesselName, var components) = entries[idx].content,
                              let cIdx = components.firstIndex(where: { $0.id == id }) else { continue }
                        // Text changed, so the existing check no longer describes what was
                        // prepped — reset it and let the cook re-check.
                        components[cIdx] = MiseEnPlaceComponent(id: id, text: text, isDone: false)
                        miseEnPlace![idx] = MiseEnPlaceEntry(
                            id: entries[idx].id,
                            content: .group(vesselName: vesselName, components: components)
                        )
                        break
                    }
                }

            case .removeMiseEnPlaceComponent(let id):
                if let entries = miseEnPlace {
                    for idx in entries.indices {
                        guard case .group(let vesselName, var components) = entries[idx].content,
                              components.contains(where: { $0.id == id }) else { continue }
                        components.removeAll { $0.id == id }
                        miseEnPlace![idx] = MiseEnPlaceEntry(
                            id: entries[idx].id,
                            content: .group(vesselName: vesselName, components: components)
                        )
                        break
                    }
                }

            case .addNoteSection(let afterId, let header, let items):
                let newSection = NoteSection(header: header, items: items)
                if let afterId = afterId, let idx = notes?.firstIndex(where: { $0.id == afterId }) {
                    notes?.insert(newSection, at: idx + 1)
                } else {
                    if notes == nil { notes = [] }
                    notes!.append(newSection)
                }

            case .updateNoteSection(let id, let header, let items):
                if let idx = notes?.firstIndex(where: { $0.id == id }) {
                    notes?[idx].header = header
                    notes?[idx].items = items
                }

            case .removeNoteSection(let id):
                notes?.removeAll { $0.id == id }
            }
        }

        return Recipe(
            id: recipe.id,
            version: recipe.version + 1,
            title: newTitle,
            ingredients: ingredients,
            steps: steps,
            notes: notes,
            miseEnPlace: miseEnPlace,
            // Prefer a servings value carried on the patchSet (e.g. the model rescaled the
            // recipe); otherwise preserve whatever the recipe already had.
            servings: patchSet.servings ?? recipe.servings
        )
    }
}

import SousCore

/// Deterministic mock proposer for development/testing.
/// Routes based on keywords in user text; never touches real LLM.
struct MockPatchProposer: PatchProposer {

    func propose(userText: String, recipe: Recipe) -> PatchSet {
        let lower = userText.lowercased()

        if lower.contains("invalid") {
            return invalidPatch(recipe: recipe)
        } else if lower.contains("yeast") {
            return yeastPatch(recipe: recipe)
        } else {
            return notePatch(recipe: recipe)
        }
    }

    // MARK: - Routes

    /// Intentionally invalid: wrong version + attempt to update a done step.
    private func invalidPatch(recipe: Recipe) -> PatchSet {
        PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version + 99,
            patches: [
                .updateStep(id: AppStore.stepDoneId, text: "mutating a done step"),
            ]
        )
    }

    /// Valid: add yeast ingredient + update salt quantity.
    private func yeastPatch(recipe: Recipe) -> PatchSet {
        PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [
                .addIngredient(text: "1 tsp yeast", afterId: AppStore.ingredientFlourId),
                .updateIngredient(id: AppStore.ingredientSaltId, text: "2 tsp salt"),
            ]
        )
    }

    /// Valid: add a note.
    private func notePatch(recipe: Recipe) -> PatchSet {
        PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [
                .addNote(text: "From chat"),
            ]
        )
    }
}

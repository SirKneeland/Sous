import { Recipe, Patch, ChangeSet } from '../types/recipe'

export interface PatchResult {
  recipe: Recipe
  appliedPatches: Patch[]
  rejectedPatches: Array<{ patch: Patch; reason: string }>
  changeSet: ChangeSet
}

/**
 * Applies patches to a recipe while enforcing immutability rules.
 * Done steps cannot be modified.
 */
export function applyPatches(recipe: Recipe, patches: Patch[]): PatchResult {
  const appliedPatches: Patch[] = []
  const rejectedPatches: Array<{ patch: Patch; reason: string }> = []

  // Track changes for highlighting
  const changedIngredientIds: string[] = []
  const addedIngredientIds: string[] = []
  const removedIngredientIds: string[] = []
  const changedStepIds: string[] = []
  const addedStepIds: string[] = []
  const addedNoteIndices: number[] = []

  let newRecipe = { ...recipe }
  // Deep clone for safe snapshot - ensures Reject works correctly
  const previousRecipe = structuredClone(recipe)

  for (const patch of patches) {
    const result = applySinglePatch(newRecipe, patch)
    if (result.success) {
      newRecipe = result.recipe
      appliedPatches.push(patch)

      // Track what changed based on patch type
      switch (patch.op) {
        case 'update_ingredient':
          changedIngredientIds.push(patch.id)
          break
        case 'add_ingredient':
          // Use the returned ID from applyAddIngredient
          if (result.addedIngredientId) addedIngredientIds.push(result.addedIngredientId)
          break
        case 'remove_ingredient':
          removedIngredientIds.push(patch.id)
          break
        case 'update_step':
          changedStepIds.push(patch.step_id)
          break
        case 'add_step':
          // Use the returned ID from applyAddStep
          if (result.addedStepId) addedStepIds.push(result.addedStepId)
          break
        case 'add_note':
          addedNoteIndices.push(newRecipe.notes.length - 1)
          break
      }
    } else {
      rejectedPatches.push({ patch, reason: result.reason })
    }
  }

  // Increment version if any patches were applied
  if (appliedPatches.length > 0) {
    newRecipe = { ...newRecipe, version: newRecipe.version + 1 }
  }

  const changeSet: ChangeSet = {
    changedIngredientIds,
    addedIngredientIds,
    removedIngredientIds,
    changedStepIds,
    addedStepIds,
    addedNoteIndices,
    patches: appliedPatches,
    previousRecipe
  }

  return { recipe: newRecipe, appliedPatches, rejectedPatches, changeSet }
}

type SinglePatchResult =
  | { success: true; recipe: Recipe; addedStepId?: string; addedIngredientId?: string }
  | { success: false; reason: string }

function applySinglePatch(recipe: Recipe, patch: Patch): SinglePatchResult {
  switch (patch.op) {
    case 'add_step':
      return applyAddStep(recipe, patch)
    case 'update_step':
      return applyUpdateStep(recipe, patch)
    case 'update_ingredient':
      return applyUpdateIngredient(recipe, patch)
    case 'add_ingredient':
      return applyAddIngredient(recipe, patch)
    case 'remove_ingredient':
      return applyRemoveIngredient(recipe, patch)
    case 'add_note':
      return applyAddNote(recipe, patch)
    default:
      return { success: false, reason: 'Unknown patch operation' }
  }
}

function applyAddStep(
  recipe: Recipe,
  patch: { op: 'add_step'; after_step_id: string | null; text: string }
): SinglePatchResult {
  const newStepId = `step-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`
  const newStep = { id: newStepId, text: patch.text, status: 'todo' as const }

  let newSteps: typeof recipe.steps

  if (patch.after_step_id === null) {
    // Add at the beginning
    newSteps = [newStep, ...recipe.steps]
  } else {
    const afterIndex = recipe.steps.findIndex(s => s.id === patch.after_step_id)
    if (afterIndex === -1) {
      return { success: false, reason: `Step ${patch.after_step_id} not found` }
    }
    newSteps = [
      ...recipe.steps.slice(0, afterIndex + 1),
      newStep,
      ...recipe.steps.slice(afterIndex + 1)
    ]
  }

  return {
    success: true,
    recipe: { ...recipe, steps: newSteps },
    addedStepId: newStepId
  }
}

function applyUpdateStep(
  recipe: Recipe,
  patch: { op: 'update_step'; step_id: string; text: string }
): SinglePatchResult {
  const step = recipe.steps.find(s => s.id === patch.step_id)

  if (!step) {
    return { success: false, reason: `Step ${patch.step_id} not found` }
  }

  // CRITICAL: Cannot modify done steps
  if (step.status === 'done') {
    return { success: false, reason: `Cannot modify completed step ${patch.step_id}` }
  }

  const newSteps = recipe.steps.map(s =>
    s.id === patch.step_id ? { ...s, text: patch.text } : s
  )

  return {
    success: true,
    recipe: { ...recipe, steps: newSteps }
  }
}

function applyUpdateIngredient(
  recipe: Recipe,
  patch: { op: 'update_ingredient'; id: string; text: string }
): SinglePatchResult {
  const ingredient = recipe.ingredients.find(i => i.id === patch.id)

  if (!ingredient) {
    return { success: false, reason: `Ingredient ${patch.id} not found` }
  }

  const newIngredients = recipe.ingredients.map(i =>
    i.id === patch.id ? { ...i, text: patch.text } : i
  )

  return {
    success: true,
    recipe: { ...recipe, ingredients: newIngredients }
  }
}

function applyAddIngredient(
  recipe: Recipe,
  patch: { op: 'add_ingredient'; text: string }
): SinglePatchResult {
  const newIngredientId = `ing-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`
  const newIngredient = { id: newIngredientId, text: patch.text, checked: false }

  return {
    success: true,
    recipe: { ...recipe, ingredients: [...recipe.ingredients, newIngredient] },
    addedIngredientId: newIngredientId
  }
}

function applyRemoveIngredient(
  recipe: Recipe,
  patch: { op: 'remove_ingredient'; id: string }
): SinglePatchResult {
  const ingredient = recipe.ingredients.find(i => i.id === patch.id && !i.removed)

  if (!ingredient) {
    return { success: false, reason: `Ingredient ${patch.id} not found` }
  }

  // Soft-delete: mark as removed instead of filtering out
  // This allows showing removed items during review
  const newIngredients = recipe.ingredients.map(i =>
    i.id === patch.id ? { ...i, removed: true } : i
  )

  return {
    success: true,
    recipe: { ...recipe, ingredients: newIngredients }
  }
}

function applyAddNote(
  recipe: Recipe,
  patch: { op: 'add_note'; text: string }
): SinglePatchResult {
  return {
    success: true,
    recipe: { ...recipe, notes: [...recipe.notes, patch.text] }
  }
}

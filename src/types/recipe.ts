export interface Ingredient {
  id: string
  text: string
  checked: boolean
  removed?: boolean  // Soft-delete flag for review flow
}

export interface Step {
  id: string
  text: string
  status: 'todo' | 'done'
}

export interface Recipe {
  id: string
  title: string
  ingredients: Ingredient[]
  steps: Step[]
  notes: string[]
  currentStepId: string | null
  version: number
}

// Patch operation types based on PatchingRules.md
export type Patch =
  | { op: 'add_step'; after_step_id: string | null; text: string }
  | { op: 'update_step'; step_id: string; text: string }
  | { op: 'update_ingredient'; id: string; text: string }
  | { op: 'add_ingredient'; text: string }
  | { op: 'remove_ingredient'; id: string }
  | { op: 'add_note'; text: string }
  | { op: 'replace_recipe'; title: string; ingredients: string[]; steps: string[] }

export interface LLMResponse {
  assistant_message: string
  patches: Patch[]
}

// Tracks which items were changed by a patch set
export interface ChangeSet {
  kind: 'patches' | 'replace_recipe'
  changedIngredientIds: string[]
  addedIngredientIds: string[]
  removedIngredientIds: string[]
  changedStepIds: string[]
  addedStepIds: string[]
  addedNoteIndices: number[]
  patches: Patch[]
  previousRecipe: Recipe
}

// Event sent to LLM when user rejects a suggestion
export interface RejectionEvent {
  type: 'user_rejected_suggestion'
  rejectedPatches: Patch[]
  reason?: string
  timestamp: number
}

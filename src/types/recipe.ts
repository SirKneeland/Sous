export interface Ingredient {
  id: string
  text: string
  checked: boolean
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

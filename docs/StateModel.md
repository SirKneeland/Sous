# State Model

The recipe is the single source of truth.

```ts
Recipe {
  id: string
  title: string
  ingredients: Ingredient[]
  steps: Step[]
  notes: string[]
  currentStepId: string | null
  version: number
}

Ingredient {
  id: string
  text: string
  checked: boolean
}

Step {
  id: string
  text: string
  status: "todo" | "done"
}
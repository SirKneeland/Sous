# State Model

The recipe is the single source of truth.

## State Layers

Sous maintains multiple layers of state. These layers have different responsibilities and should not be conflated.

1. **Recipe State (authoritative)**
   - The recipe is the single source of truth for what is being cooked.
   - All cooking progress that must be respected (e.g., completed steps) lives here.
   - Completed steps are immutable.

2. **Proposed Change State (ephemeral)**
   - AI-suggested changes that have not yet been approved by the user.
   - Represents intent (what the AI proposes), not fact (what the recipe is).
   - Applying proposed changes mutates Recipe State; rejecting them leaves Recipe State unchanged.

3. **Session/UI State (ephemeral)**
   - Chat messages and interaction context.
   - UI focus (cooking vs editing) and panel expansion/collapse.
   - May be persisted locally to survive reloads, but is not the source of truth for the recipe itself.

## Authoritative Recipe State

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
```

## Proposed Change State

Proposed changes are tracked separately from the recipe so the user can explicitly approve or reject them.

```ts
// A set of proposed patches awaiting user review.
ChangeSet {
  patches: Patch[]
  summary?: string
  createdAt?: number
}

// A patch represents a structured edit operation on the recipe.
// (See docs/PatchingRules.md for the full patch schema and constraints.)
Patch { /* ... */ }
```

## Session/UI State

Session/UI state captures conversational context and UI focus. It is derived from interaction and may be persisted locally,
while Recipe State remains the authoritative source of truth.

```ts
SessionState {
  recipeId: string
  chatMessages: ChatMessage[]
  pendingChangeSet: ChangeSet | null
  uiFocus: "cooking" | "editing"
  lastUpdatedAt?: number
}

ChatMessage {
  id: string
  role: "user" | "assistant"
  content: string
  timestamp: number
}
```
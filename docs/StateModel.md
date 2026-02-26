# State Model

The recipe is the single source of truth.

## State Layers

Sous maintains multiple layers of state. These layers have different responsibilities and should not be conflated.

1. **Recipe State (authoritative)**
   - The recipe is the single source of truth for what is being cooked.
   - All cooking progress that must be respected (e.g., completed steps) lives here.
   - Completed steps are immutable.

2. **User Defaults State (persistent, non-authoritative)**
   - Explicit, user-declared cooking invariants.
   - Persisted across sessions and devices.
   - Applied automatically to recipe creation and scaling.
   - Must never retroactively mutate Recipe State.
   - Can be overridden per recipe only by explicit user instruction.

3. **Proposed PatchSet State (ephemeral)**
   - AI-suggested changes that have not yet been approved by the user.
   - Represents intent (what the AI proposes), not fact (what the recipe is).
   - Applying a validated PatchSet mutates Recipe State; rejecting it leaves Recipe State unchanged.
   - Proposed PatchSets may reference User Defaults when generating patches, but approving a PatchSet must never mutate User Defaults unless explicitly requested.

4. **Session/UI State (ephemeral)**
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

## User Defaults State

User Defaults represent explicit, persistent constraints provided by the user.
They are not inferred and are not part of Recipe State.

```ts
UserDefaults {
  portions: number
  hardAvoids: string[]
  updatedAt?: number
}
```

Rules:
- UserDefaults are applied silently during recipe creation.
- UserDefaults must never alter completed recipe steps.
- Violations of hardAvoids require explicit user confirmation.

## Proposed PatchSet State

A PatchSet represents a single, atomic batch of AI-proposed edits. It is intent-only until explicitly accepted by the user.

```ts
type PatchSetStatus =
  | "proposed"     // received from server, not yet reviewed
  | "reviewing"    // user is in Patch Review Mode
  | "accepted"     // user accepted and patches were applied
  | "rejected"     // user rejected and patches were discarded
  | "expired";     // superseded or invalidated

PatchSet {
  patchSetId: string
  createdAtMs: number
  status: PatchSetStatus

  // Structured edit operations returned by the LLM
  patches: Patch[]

  // Optional structured summary for UI + model context
  summary?: {
    title?: string
    bullets?: string[]
    impacted?: {
      ingredientsAdded?: number
      ingredientsModified?: number
      ingredientsRemoved?: number
      stepsAdded?: number
      stepsModified?: number
      stepsRemoved?: number
    }
  }

  // Snapshot anchor for deterministic diff rendering
  baseRecipeId: string
  baseRecipeVersion: number

  // Optional full snapshot to correctly render removed elements
  baseRecipeSnapshot?: Recipe

  // Validation result produced by client-side deterministic validator
  validation: {
    isValid: boolean
    errors?: string[]
  }
}

// A patch represents a structured edit operation on the recipe.
// (See docs/PatchingRules.md for the full patch schema and constraints.)
Patch { /* ... */ }
```

## Session/UI State

Session/UI state captures conversational context, patch lifecycle state, and UI focus.
It may be persisted locally to survive reloads, but Recipe State remains the authoritative source of truth.

```ts
SessionState {
  recipe: Recipe
  // Recipe.version is the single authoritative version source (do not duplicate it elsewhere).

  chatMessages: ChatMessage[]

  // At most one active PatchSet may be pending review at a time.
  pendingPatchSet: PatchSet | null

  // Historical record of user decisions on patch sets (bounded list, e.g. last 10).
  patchHistory: PatchDecision[]

  // Hidden context to attach to the next LLM request.
  nextLLMContext?: {
    // Included exactly once with the next LLM request, then cleared.
    lastPatchDecision?: PatchDecision
  }

  ui: {
    mode: "cook" | "chat" | "patch_review"
    chatDetent?: "collapsed" | "medium" | "large"
  }

  lastUpdatedAt?: number
}

ChatMessage {
  id: string
  role: "user" | "assistant"
  content: string
  timestamp: number
}

// Records the user's explicit decision on a PatchSet.
PatchDecision {
  patchSetId: string
  decision: "accepted" | "rejected"
  decidedAtMs: number

  // Optional structured summary carried forward for LLM context.
  summary?: PatchSet["summary"]
}
```

---

## Determinism Rules

- Recipe State is mutated only by applying a validated PatchSet after explicit user acceptance.
- PatchSet application is atomic: fully applied or fully rejected.
- Rejecting a PatchSet leaves Recipe State unchanged.
- Completed steps (`status === "done"`) are immutable.
- nextLLMContext is included in exactly one subsequent LLM request and must then be cleared.
- Session/UI State must never be treated as authoritative for recipe data.
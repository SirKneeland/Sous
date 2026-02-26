# Patching Rules

Sous uses a strict **PatchSet** model. The AI never rewrites the full recipe.

It emits:

1. `assistant_message` — short conversational reply
2. `patchSet` — structured, machine-readable operations

`patchSet` represents a single, atomic batch of **proposed** changes and must not be applied to Recipe State until the user explicitly approves.

---

## PatchSet Contract

A response that modifies the recipe must include:

```ts
patchSet: {
  patchSetId: string
  baseRecipeVersion: number
  patches: Patch[]
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
}
```

Rules:

- A PatchSet is atomic. It is either fully applied or fully rejected.
- Only one PatchSet may be pending review at a time.
- A PatchSet must target the current `recipeVersion` via `baseRecipeVersion`.
- If `patchSet` is present, it must contain at least one patch.
- If the recipe has changed since generation, the PatchSet must be treated as expired.

---

## Sequential Evaluation Semantics

Patches are evaluated in the order provided.

Validation must simulate sequential application of patches against a copy of the current Recipe State.

Rules:

- Later patches may depend on earlier patches.
- Each patch must be valid relative to the simulated state at that point.
- If any patch invalidates a subsequent patch, the PatchSet is invalid.
- Validation decisions must be based on the simulated end-state.

This guarantees deterministic, order-safe behavior.

---

## Allowed Patch Operations

- `add_step(after_step_id, text)`
- `update_step(step_id, text)`  // only if status === "todo"
- `update_ingredient(id, text)`
- `add_ingredient(text)`
- `remove_ingredient(id)`
- `add_note(text)`

Additional constraints:

- Step IDs and ingredient IDs must refer to existing entities at the time of execution.
- Operations must be deterministic and order-safe.
- No operation may implicitly rewrite unrelated parts of the recipe.
- A patch must not create duplicate logical entities unless explicitly requested.

---

## Internal PatchSet Consistency Rules

Within a PatchSet:

- A patch may not reference an entity removed earlier in the same PatchSet.
- A patch may not update an entity that is removed later in the same PatchSet.
- Conflicting operations on the same entity within one PatchSet are invalid.
- The PatchSet must represent a valid state transition when applied sequentially.

If these conditions are not met, the PatchSet is invalid.

---

## Validation Rules

Client-side validation is mandatory before entering Patch Review Mode.

Validation must ensure:

- No patch modifies a step with status `done`.
- Ingredient IDs must exist (after sequential simulation).
- Removed ingredients are either:
  - No longer referenced in future steps, OR
  - Accompanied by updated steps (without touching done steps), OR
  - Accompanied by a note explaining the adjustment.
- Patches do not conflict internally.

Validation must classify failures into one of the following categories:

### 1. Recoverable (Repairable)

Examples:

- Non-existent IDs that can be resolved
- Duplicate adds
- No-op updates
- Ordering inconsistencies

The system may attempt automatic repair and retry the LLM.

### 2. Expired

- `baseRecipeVersion` does not match current recipe version
- Recipe changed after PatchSet generation

Expired PatchSets must be discarded and regenerated. No repair attempt.

### 3. Fatal (Non-repairable)

- Modifying a `done` step
- Implicit rewrite of unrelated state
- Internal cyclic or contradictory operations

Fatal PatchSets must be rejected immediately.

If validation fails fatally or expires:

- The PatchSet must be rejected automatically.
- The user must not enter Patch Review Mode.

---

## Rendering Requirements (Patch Review Mode)

Patch Review Mode must visually represent **all state transitions**:

For both Ingredients and Steps:

- Added → visibly highlighted as new
- Modified → visibly marked as edited (inline when possible)
- Removed → rendered as ghost/struck items in original position

The user must see the full end-state if accepted.

The recipe must not be partially updated before acceptance.

---

## When to Emit Zero Patches

If the user message is:

- Exploratory
- Ambiguous
- A question about tradeoffs
- A request that conflicts with hard constraints

The assistant must:

- Ask a clarifying question
- Return `patchSet: null` (or omit it)

Empty PatchSets are not allowed.

---

## Hard Rules

- AI may not modify any step with status `done`.
- If a change requires altering a done step:
  - Add a recovery step after the current step OR
  - Add a note explaining what to do.
- No silent patch application.
- No implicit state mutation outside PatchSet.

---

## User Defaults Constraints

Patches that generate or modify ingredients or steps must respect User Defaults:

- `hardAvoids` are hard constraints.
- `portions` affects quantitative scaling only.

The assistant must not introduce any hard-avoid item (or obvious derivatives) unless the user explicitly overrides it for this recipe.

If a request conflicts with `hardAvoids`, the assistant must ask for clarification and emit no PatchSet.

Portion sizing:

- May adjust ingredient quantities.
- May adjust future step quantities.
- Must never retroactively change completed steps.

---

## Patch Decision Context (Rejection / Acceptance)

When a user accepts or rejects a PatchSet:

- The decision must be recorded in Session State as a `PatchDecision`.
- The next LLM request must include structured metadata:

```ts
context: {
  llm?: {
    lastPatchDecision?: {
      patchSetId: string
      decision: "accepted" | "rejected"
      summary?: PatchSet["summary"]
    }
  }
}
```

This context:

- Is not user-visible.
- Must not be embedded into user text.
- Must only be included once (cleared after the next successful LLM response).

The purpose is to prevent the model from re-proposing the same rejected plan and to provide conversational continuity.

---

## Scope Boundary

Patching operations mutate **Recipe State only**.

Updating User Defaults, Accounts, or other persistent user data is handled via separate flows and is explicitly out of scope for PatchSet operations.
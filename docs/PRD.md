# Sous — Product Requirements Document

## Product Vision

Cooking with today’s AI tools is frustrating because chat is ephemeral and recipes are stateful. Every correction, substitution, or mistake forces users to scroll, reprint, or mentally reconcile versions.

Sous turns a recipe into a *living document* that an AI co-authors in real time. The user chats naturally (“I’m out of onions,” “Can this be spicier?” “I burned the garlic”), and the AI mutates a persistent recipe canvas accordingly—without rewriting history.

The result feels like cooking *with* a competent expert, not *talking to* one.

**Emotional promise:**  
“Cooking is fun because I have a competent expert with me.”

---

## Target User

A home cook who:
- Uses LLMs for recipes today
- Cooks with their phone on the counter
- Improvises mid-cook
- Frequently changes plans or makes mistakes

They are not trying to become a chef.  
They are trying to get dinner on the table without friction.

---

## Core Jobs-To-Be-Done

1. Decide what to cook.
2. Generate a recipe that fits constraints.
3. Adapt the recipe in the moment.
4. Never lose place or context.
5. Track progress through steps.
6. Recover gracefully from mistakes.
7. Avoid restating known constraints every time.

---

## UX Model

Phone-first, mode-based layout (not a true dual-pane split view).

Sous has three explicit UI modes:

1. **Cook Mode (default)**
2. **Chat Mode**
3. **Patch Review Mode**

The recipe canvas is always the single source of truth and the primary surface.
Chat is a temporary interaction mode layered on top of the recipe.

### Cook Mode

- Full recipe canvas visible and scrollable.
- Bottom composer collapsed ("Ask Sous…" + camera).
- No chat transcript visible.
- No scrim.

### Chat Mode

- Chat appears as a bottom sheet overlay.
- Recipe is dimmed using a scrim (semi-transparent black overlay).
- Recipe is not interactive while scrim is active.
- Only chat scrolls; recipe does not scroll in this mode.
- Chat sheet supports detents (collapsed / medium / large).

The scrim ensures clear hierarchy and prevents dual-surface scroll conflicts.

### Patch Review Mode

Patch Review Mode is a blocking decision state entered when the user taps “Review Changes.”

- Chat sheet collapses.
- Scrim disappears.
- Recipe becomes primary surface again.
- All proposed changes are rendered visually in-place (see Interaction Model).
- A fixed bottom action bar appears with two equal CTAs:
  - **Reject**
  - **Accept Changes**

The user must explicitly choose one.

---

## Recipe Canvas

Structure:
- Title
- Ingredients (checkable)
- Steps (numbered, large text, each with status: todo|done)
- Optional notes/tips

Rules:
- Users can mark steps “Done”.
- The AI is forbidden from editing any step marked `done`.
- If a user request would require altering a completed step:
  - The AI must add a recovery step or note *after* the current step.

---

## Interaction Model

User speaks naturally:
- “I forgot onions.”
- “I burned the garlic.”
- “Can this be spicier?”

AI responds with:
1. A short conversational reply.
2. A structured `patchSet` (if mutation is appropriate).

The AI must never emit a full recipe once a canvas exists.

### Patch Lifecycle

When the assistant proposes changes:

1. The response includes a `patchSet`.
2. The app stores it as `pendingPatchSet`.
3. The user remains in Chat Mode.
4. A visible “Review Changes” affordance appears.
5. Only one `patchSet` may be pending at a time; any new proposal must invalidate or replace the existing pending `patchSet`.

The user must explicitly enter Patch Review Mode.

Only one PatchSet may exist in a pending state at any time. The system must never queue multiple concurrent PatchSets. If a new PatchSet is generated while one is pending review, the existing PatchSet must be marked `expired` or explicitly replaced before the new one becomes active.

### Patch Review Rendering Requirements

Patch Review Mode must render full diff coverage for both Ingredients and Steps.

For each section:

- **Added items** → highlighted as new.
- **Modified items** → rendered in final proposed state with an “Edited” indicator.
- **Removed items** → rendered in original position as ghost/struck entries.

The user must see the complete end-state if accepted.

The recipe must not mutate until acceptance.

### Accept / Reject Behavior

**Accept Changes**
- Apply entire PatchSet atomically.
- Increment recipe version.
- Clear highlights.
- Exit to Cook Mode.

**Reject**
- Discard entire PatchSet.
- Clear highlights.
- Return to Chat Mode.

The rejection must be recorded in session state.

### Hidden Rejection Context

When a PatchSet is accepted or rejected, the decision must be recorded as a `PatchDecision` in session state.

On the next LLM request, the app must include structured metadata:

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

## Conversation State and Recipe Creation Gate

Sous has two high-level modes:

1. **Creation mode** (no recipe canvas yet)
2. **Cooking/Edit mode** (a recipe canvas exists)

Creation mode is split into two phases:

- **Exploration phase (default):** the assistant helps the user *decide what to cook* by asking 1–2 targeted questions and proposing a small menu of options. **No recipe canvas is created in this phase.**
- **Commit phase:** only after the user explicitly commits to an option (e.g., “Let’s do option 2”, “Generate that one”, or tapping an option card) may the assistant create the recipe canvas.

**Hard rule:** The assistant must never create a recipe canvas (or output a full recipe) unless the user has explicitly committed.

### Commit signals

Examples that count as commit:

- “Let’s do that / this one”
- “Make the French one”
- “Option 2”
- “Generate the recipe”
- A UI action like tapping a specific option card or a “Generate recipe” button

If the user is vague (“sure”, “ok”), the assistant should confirm which option they mean *without* generating the recipe yet.

### Exploration response shape

In Exploration phase, the assistant response should:

1. Reflect the request in one sentence.
2. Ask **1–2 branching questions** (max).
3. Provide **3–5 options** with short “why it fits” blurbs.
4. Invite the user to pick one or refine.

### Routing (implementation note)

Determine:

- `has_canvas`: whether a recipe canvas exists
- `intent`: explore | commit_to_option | edit_existing_recipe | cooking_help

Routing rules:

- If `has_canvas=false` and `intent=explore` → Exploration response shape (no canvas)
- If `has_canvas=false` and `intent=commit_to_option` → Generate recipe canvas (US-01)
- If `has_canvas=true` → Patch-based edits + “no past edits” rule
---

## Cooking Defaults (User-Declared Invariants)

Sous supports a small set of explicit, persistent user-declared defaults that are applied automatically to recipe creation.

Cooking Defaults are:
- Explicitly set by the user (never inferred)
- Persisted across sessions
- Applied silently to all new recipes
- Overridable per recipe only by explicit user instruction

### v1 Cooking Defaults

- **Portions** — total number of portions to cook (purely quantitative)
- **Hard-avoid ingredients or food categories** — must never appear unless explicitly overridden

These defaults are treated as **hard constraints**, not preferences.

### Override semantics

- Overrides apply only to the current recipe unless the user explicitly updates their defaults
- The assistant must never violate a hard-avoid without asking first
- Defaults must never retroactively modify completed recipe steps

---

## MVP Feature Set

- Mode-based bottom-sheet UI (Cook / Chat / Patch Review)
- AI-generated recipe
- Persistent recipe canvas
- Checkable steps
- Step state sent to model
- AI patching of:
  - Ingredients
  - Future steps
  - Notes
- Voice input (optional in v1)
- Cooking mode (single-step focus)
- Simple undo

Future versions of Sous may allow users to calibrate response tone and formatting, but such style preferences must never override recipe correctness or state safety.

---

## Non-Goals (v1)

Out of scope for v1:

- Social sharing
- Public recipe discovery
- Nutrition tracking
- Grocery delivery integrations
- Multi-canvas workspaces
- Collaboration with other users
- Monetization or paywalls
- Preference inference or long-term taste learning

> Monetization is a future goal (e.g. “Sous Pro”) and may unlock:
> - Voice-first cooking mode  
> - Photo input (“Does this look right?”)  
> - Higher-fidelity models  
> - Longer context & history  
> - Advanced coaching features  

v1 is about nailing the core magic:  
**a living recipe that never loses the cook’s place in reality.**
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

---

## UX Model

Dual-pane, phone-first layout:

- Top: **Recipe Canvas** (persistent living document)
- Bottom: **Chat / Input Pane**

The recipe canvas is the *single source of truth*.  
Chat never reprints the full recipe.

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
2. Structured patches that mutate the recipe canvas.

The AI never outputs a full recipe in chat.

 ## Interaction Model

 The AI never outputs a full recipe in chat.
 
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

## MVP Feature Set

- Dual-pane UI
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

> Monetization is a future goal (e.g. “Sous Pro”) and may unlock:
> - Voice-first cooking mode  
> - Photo input (“Does this look right?”)  
> - Higher-fidelity models  
> - Longer context & history  
> - Advanced coaching features  

v1 is about nailing the core magic:  
**a living recipe that never loses the cook’s place in reality.**
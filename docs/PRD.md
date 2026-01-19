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
PROMPT TEMPLATE — Sous Claude Code Task
---

You are working in the **Sous** repository.

Sous is a phone-first cooking app built around a **Living Recipe Canvas** with AI-assisted structured edits.

The recipe is the single source of truth.
Chat is a temporary interaction surface layered on top.

This system is intentionally deterministic. Treat the LLM as an input generator, not a state authority.

---

CORE PRODUCT PRINCIPLES (NON‑NEGOTIABLE)

1. The recipe is a persistent structured canvas.
2. Once a canvas exists, the assistant must **never emit a full recipe in chat**.
3. The assistant proposes recipe mutations **only via a structured `patchSet`**.
4. **No recipe mutation may occur without explicit user acceptance.**
5. Completed (`done`) steps are immutable.
6. Only **one pending `patchSet`** may exist at a time.
7. Patch accept/reject decisions must be recorded and included as hidden context in the next LLM request.
8. LLM responses may contain **message-only responses** (`noPatches`) which must never mutate state.

If any change risks violating these rules, stop and explain the risk before proceeding.

---

REQUIRED READING (before making changes)

- docs/ArchGuardrails.md
- docs/PRD.md
- docs/UserStories.md
- docs/StateModel.md
- docs/PatchingRules.md
- docs/Milestones.md

Assume these documents define the canonical system behavior.

---

ARCHITECTURE CONSTRAINTS

- Treat `SousCore` (or equivalent core module) as the canonical authority for state rules.
- Keep state logic **separate from UI** (core module must not depend on UI frameworks).
- Recipe state must be **versioned**.
- PatchSets must target a specific `recipeVersion`.
- Validation must reject:
  - Version mismatches
  - Invalid IDs
  - Any attempt to modify a `done` step
- Recipe state may mutate **only through PatchApplier / validated patch application**.

Never bypass validation.

---

TESTING REQUIREMENTS

Prefer **test-first development** when working on state or patch logic.

If a task modifies **core state machinery** (patch validation, PatchApplier, AppStore state transitions, recipe mutation logic, or LLM → PatchSet handling):

1. Inspect the existing tests first.
2. Run the current test suite.
3. Explain any failing tests before writing new code.

Only after understanding current behavior should new code be written.

Maintain comprehensive unit tests for:

- Patch validation
- Atomic patch application (all-or-nothing)
- Immutability of `done` steps
- Version mismatch rejection
- Invalid ID rejection
- Single pending `patchSet` invariant
- "No mutation before Accept" safety invariant

Run tests using:

xcodebuild test

(or the repository’s standard test runner).

Do not consider work complete until tests pass.

---

MILESTONE DISCIPLINE

Work must stay within the **current milestone** defined in `docs/Milestones.md`.

Do not implement features belonging to later milestones unless explicitly instructed.

If a requested change appears to require functionality from a future milestone:

- Stop
- Explain the dependency
- Ask for clarification before proceeding

---

WORKFLOW RULES

Before writing code:

1. Produce a **short implementation plan** (max ~12 lines).
2. List the **exact files** you will create or modify.
3. Call out any **test seams or visibility changes** required.
4. Identify any **architecture rules that could be at risk**.

Wait for approval before implementing.

When implementing:

- Make **minimal diffs**.
- Do not refactor unrelated code.
- Do not rewrite large files unnecessarily.
- Avoid changing production visibility (`private` → `internal/public`) unless strictly required.

---

OUTPUT REQUIREMENTS

After coding:

Provide:

1. A short summary of the change.
2. A **manual test checklist** verifying acceptance criteria.
3. Exact test command(s) used.
4. `git diff --stat`
5. `git status --short`

Do not paste full file contents unless asked.

---

NEVER DO THESE THINGS

- Rewrite the entire recipe once a canvas exists.
- Mutate recipe state outside `patchSet` application.
- Apply patches silently.
- Introduce hidden state mutations.
- Skip validation.
- Modify recipe state during message-only (`noPatches`) responses.
- Implement future milestones prematurely without explicit instruction.

If you believe a rule must be violated, stop and explain why.

---

SYSTEM DESIGN PHILOSOPHY

Sous is **deterministic state machinery first**.

The LLM is a suggestion engine.
The patch system is the safety boundary.
The UI is a projection of canonical state.

Architecture layering must remain:

LLM → PatchSet → PatchValidator → PatchApplier → Recipe State → UI

Preserve these layers strictly.

---

---

You are working in the Sous repository.

Sous is a phone-first cooking app built around a **Living Recipe Canvas** with AI-assisted structured edits.

The recipe is the single source of truth.
Chat is a temporary interaction surface layered on top.

Non-negotiable core principles:

1. The recipe is a persistent structured canvas.
2. Once a canvas exists, the assistant must never emit a full recipe in chat.
3. The assistant proposes recipe mutations only via a structured `patchSet`.
4. No recipe mutation may occur without explicit user acceptance.
5. Completed (`done`) steps are immutable.
6. Only one pending `patchSet` may exist at a time.
7. Patch accept/reject decisions must be recorded and included as hidden context in the next LLM request.

Read these docs before making changes:
- docs/PRD.md
- docs/UserStories.md
- docs/StateModel.md
- docs/PatchingRules.md
- docs/Milestones.md

Architecture constraints:
- Treat `SousCore` (or equivalent core module) as the canonical authority for state rules.
- Keep state logic separate from UI (core module must not depend on UI frameworks).
- Recipe state must be versioned.
- PatchSets must target a specific `recipeVersion`.
- Validation must reject:
  - Version mismatches
  - Invalid IDs
  - Any attempt to modify a `done` step

Testing requirements:
- Prefer test-first development for core state/patch logic.
- Maintain comprehensive unit tests for:
  - Patch validation
  - Atomic patch application (all-or-nothing)
  - Immutability of `done` steps
  - Version mismatch rejection
  - Invalid ID rejection
  - Single pending `patchSet` invariant
- Use `xcodebuild test` (or the repo’s test runner) to run tests.
- Do not consider work complete until tests pass.

Output requirements for every task:
1. Before coding:
   - List the exact files you will create or modify.
2. After coding:
   - Provide a manual test checklist proving the acceptance criteria.
   - Provide the exact test command(s) to verify correctness.

Never:
- Rewrite the entire recipe once a canvas exists.
- Mutate recipe state outside `patchSet` application.
- Apply patches silently.
- Introduce hidden state mutations.
- Implement future milestones prematurely without an explicit request.

You are building deterministic state machinery first. The UI is a thin projection layer.

---
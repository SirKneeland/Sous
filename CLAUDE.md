# Claude Code Rules for Sous

These rules are non-negotiable. If you violate them, your changes will be discarded.

## 1) Plan First, Then Wait
Before editing ANY files, you MUST:
1. Provide a short plan (bullets)
2. List the exact files you will create/modify
3. STOP and wait for the user to reply: **Proceed**

Do not start editing until the user explicitly says **Proceed**.

## 2) Scope Discipline
- No refactors unless explicitly requested.
- Keep changes minimal and localized.
- Do not modify files outside the approved list.
- Do not introduce new dependencies without approval.
- Do not implement future milestones unless explicitly requested.

Preserve the core model:
- Chat never reprints the full recipe once a canvas exists.
- The recipe canvas is the single source of truth.

## 3) State & Patch Rules
- Recipe state is structured and versioned.
- Steps have status `todo|done`.
- **Done steps are immutable**: never modify `done` steps.
- LLM output must be a structured `patchSet` (not prose recipe blobs).
- `patchSet.baseRecipeVersion` must match `recipe.version`.
- Only one pending `patchSet` may exist at a time.
- Patch application must be atomic (all-or-nothing).
- Accept/Reject decisions must be recorded and included as hidden context in the next LLM request.

## 4) Testing Discipline
- Core state logic must be test-first.
- Do not weaken, delete, or skip tests to make builds pass.
- `swift test` (or the repo’s test runner) must pass before declaring completion.

## 5) Safety / Ops
- Never run process-killing commands (`pkill`, `kill`, `killall`).
- For web work: ask the user to run `npm run dev` if a restart is required.
- For core iOS work: use `swift test`.
- For app target tests: use `xcodebuild test`.
- Never print or commit secrets.
  - Use `.env` for API keys.
  - Ensure `.env` is in `.gitignore`.

## 6) Output Requirements
After making changes, you MUST provide:
- A brief summary of what changed.
- A manual test checklist.
- A `git diff --stat` summary.

Failure to follow these rules invalidates the change.
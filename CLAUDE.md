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
- Preserve the “Chat + Living Recipe Canvas” model:
  - Chat never reprints the full recipe.
  - The recipe canvas is the single source of truth.

## 3) State & Patch Rules
- Recipe state is structured JSON.
- Steps have status `todo|done`.
- **Done steps are immutable**: never modify `done` steps.
- LLM output must be structured patches (no prose recipe blobs).

## 4) Safety / Ops
- Never run process-killing commands (`pkill`, `kill`, `killall`).
- If a server restart is needed, ask the user to run `npm run dev`.
- Never print or commit secrets.
  - Use `.env` for API keys
  - Ensure `.env` is in `.gitignore`

## 5) Output Requirements
After making changes, you MUST provide:
- A brief summary of what changed
- A manual test checklist
- A `git diff --stat` summary
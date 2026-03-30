# Claude Code Rules for Sous

## Who You're Working With

The operator is a non-technical Product Manager. They cannot read Swift or evaluate code directly. They verify work through:
- Tests passing
- Behavioral checklists they can run on their phone
- App behavior matching the PRD and UserStories.md

This means:
- Your plans must be understood by a non-engineer
- Your test checklists must be behavioral ("tap X, expect Y"), not code-level
- You are the only one who can catch implementation errors — do not assume the operator will

---

## Core Reference Documents

Always read the relevant docs before starting work:

- `PRD.md` — product vision, UX model, interaction rules
- `Milestones.md` — what's done, what's current, what's next. Never implement future milestones.
- `ArchGuardrails.md` — non-negotiable architecture invariants. Read before touching any patch, state, or LLM code.
- `PatchingRules.md` — the full patch contract
- `StateModel.md` — authoritative state definitions
- `UserStories.md` — acceptance criteria for every user-facing behavior
- `CODEBASE.md` — repo structure, module map, test commands. Read before navigating the codebase.

---

## Autonomy Model

**Default: proceed without asking permission.**

You are expected to plan, execute, test, and report — in one session — without waiting for approval at each step.

**Only stop and ask when:**
- The task is genuinely ambiguous and you cannot resolve it from the docs
- You are about to make a decision that affects more than the current milestone
- You discover something unexpected in the codebase that changes the scope of the task
- A test is failing and you cannot determine the correct fix without product input

**Never stop to ask about:**
- Which files to edit (figure it out)
- Whether to write tests (always yes)
- How to structure code that's consistent with existing patterns (follow what's there)

If you find yourself wanting to ask a routine clarifying question, make a reasonable documented assumption and proceed.

---

## Scope Rules

- Work only within the current milestone (check Milestones.md)
- No refactors unless explicitly requested
- No new dependencies without asking
- Do not touch files outside the scope of the task
- Do not implement anything from FUTURE or PLANNED milestones

---

## Architecture Rules (non-negotiable)

These are absolute. Read ArchGuardrails.md before any work touching state, patches, or LLM integration.

The short version:
- LLM never directly mutates recipe state
- All mutations go through PatchValidator → PatchApplier
- Recipe state changes only after explicit user Accept
- Done steps are immutable — forever
- Only one pending PatchSet at a time
- Patch application is atomic (all or nothing)
- PatchSets targeting a stale version must be rejected

Violating any of these is a critical bug, not a style issue.

---

## Testing Rules

- Core state logic is test-first
- Do not delete, skip, or weaken tests to make builds pass
- Run `swift test` before declaring any task complete
- If a test is failing on work you didn't touch, flag it — do not silently fix unrelated tests without noting it

---

## Safety Rules

- Never run `pkill`, `kill`, or `killall`
- Never print or commit secrets
- API keys go in `.env`; confirm `.env` is in `.gitignore`
- To restart web tooling: ask the operator to run `npm run dev`
- For core logic: `swift test`
- For app target: `xcodebuild test`

---

## Evals

The Sous repo has a live LLM eval suite at `/evals`. Claude Code must treat evals as a first-class responsibility alongside unit tests.

**When to write new eval cases:**
- Any time a new LLM behavior rule is added or changed in the system prompts (in OpenAILLMOrchestrator.swift)
- Any time a bug is found that involves unexpected model output
- Any time a new prompt type or routing path is introduced
- Any time a user-facing constraint is added (new preference type, new immutability rule, etc.)

**How to write a new eval case:**
- Add it to `/evals/cases/core-behaviors.json`
- Each case needs: name, description, promptType, recipeState, chatHistory, userMessage, and expected (with notes and shouldPatch)
- Use realistic but minimal recipe state
- - Set shouldPatch carefully: true if the response must contain a non-null 
  patchSet, false if it must not. The schemaScorer uses this to validate JSON 
  structure deterministically on every case.
- Announce the new case to the user: "I added eval case `[name]`: [one sentence description of what it tests]"

**How to run evals:**
- `cd evals && npm run eval`
- Braintrust API key and OpenAI API key must be present in `/evals/.env`
- Run evals after any system prompt change, before marking a task complete
- Report the summary scores to the user (copy the SUMMARY block from terminal output)
- If any previously-passing case regresses, flag it explicitly before proceeding

**Never:**
- Modify system prompts without running evals afterward
- Add a new LLM behavioral rule without a corresponding eval case
- Silently skip evals because keys aren't present — instead tell the user "Evals skipped: /evals/.env not found. Run manually with: cd evals && npm run eval"

---

## Definition of Done

A task is complete when:

1. `swift test` passes (all tests, no skips)
2. You have manually traced the happy path in your reasoning and it holds
3. The operator has a behavioral checklist they can execute on device

**Not done if:**
- Tests pass but you know an edge case isn't handled
- You've commented out a test to make the build green
- The checklist requires the operator to read code

---

## Output Format

After completing any task, provide:

**Summary** — plain English, one short paragraph, what changed and why

**What to verify on device** — numbered behavioral steps ("1. Open app. 2. Type 'make it spicier'. 3. Expect a patch review banner to appear.")

**Assumptions made** — anything you decided without explicit instruction
- Write assumptions in plain English for a non-technical PM — no Swift syntax, no framework jargon. If a technical concept is unavoidable, add a one-sentence plain English explanation in parentheses.

**Anything that needs a follow-up** — edge cases deferred, known gaps, things to watch

Do not provide a `git diff --stat` as the primary output. The operator cannot interpret it.

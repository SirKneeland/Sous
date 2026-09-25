# Claude Code Rules for Sous

## Who You're Working With

The operator is a non-technical Product Manager. They cannot read Swift or evaluate code directly. They verify work through:
- Tests passing
- **Your** report of what you observed running the app in the Simulator
- App behavior matching the PRD and UserStories.md

This means:
- Your plans must be understood by a non-engineer
- You verify behavior yourself in the Simulator — see "Verification" below
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
- `DesignSpec.md` — visual design decisions, component specs, and UX rules. Read before touching any view or layout.
- `PersonalityModes.md` — detailed behavioral spec for Minimal/Normal/Playful personality modes and their LLM prompt rules.
- `CODEBASE.md` — repo structure, module map, test commands. Read before navigating the codebase.
- `docs/KnownIssues.md` — running log of deferred bugs, flaky tests, and cleanup items. Read when working in an area that may be affected.
- `docs/BugTriage.md` — the in-app bug report backlog: how reports are filed from the phone, and the `backend/scripts/bugs.sh` commands for listing, reading, and resolving them. **Read its "what is NOT a bug" section before interpreting any diagnostic** — several honest quirks (a reconstructed prompt, two disagreeing timestamps, truncated captures) read like defects and are not. Read when the operator asks to pull or work through bug submissions.

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

## Networking Boundaries

There are two distinct network clients — never conflate them:

- `OpenAIClient` (`Networking/OpenAIClient.swift`) — direct OpenAI calls. Used today
  for every user. BYOK-eligible users (`entitlement == .byok`) will keep using this
  forever.
- `SousAPIClient` (`Networking/SousAPIClient.swift`) — the **Sous backend boundary**
  (accounts, entitlement, preferences/memories sync, usage summary). Attaches the
  Sous session token and clears it on 401. Entitlement is server-computed and
  read-only on the client — never compute it locally.
- `ProxyOpenAIClient` (`Networking/ProxyOpenAIClient.swift`) — as of **Project 3**,
  every **non-BYOK** user's OpenAI chat call routes through the Sous backend proxy
  (`POST /api/v1/proxy/chat`) via this `StreamingLLMClient`. BYOK users
  (`entitlement == .byok`) keep calling OpenAI directly via `OpenAIClient`. The
  fork lives in `AppStore.makeLLMClient(isNewRecipe:recipeId:)`; it sets
  `X-Sous-Is-New-Recipe` so the backend can meter recipe-cap usage. The proxy
  relays OpenAI's response shape verbatim, so the orchestrator is transport-agnostic.

**Backend env vars** (`backend/.env.example`): in addition to Supabase / JWT /
Apple keys, Project 3 adds `OPENAI_API_KEY` (server-side key the proxy forwards
with) and `ADMIN_API_KEY` (guards `GET /api/v1/admin/dashboard`, sent in the
`X-Admin-Key` header — never a user session token). Project 4 adds `APPLE_BUNDLE_ID`,
`APP_STORE_NOTIFICATION_SECRET` (optional constant-time gate on the notify webhook),
and `APPLE_ROOT_CA_FINGERPRINT` (optional override of the pinned Apple root).

## Billing / Entitlement (Project 4)

Entitlement is **server-computed** and read-only on the client (five states:
`byok / subscriber / trialing / grace / soft_wall`). Billing UI is driven by that
entitlement, never computed locally:
- `soft_wall` (trial expired by 14 days OR 14 recipes, or subscription lapsed past
  the 7-day grace) → **paywall** (`PaywallView`) on any generative attempt.
- `subscriber`/`grace` at the 100/month cap → **hard stop** (`CapReachedView`),
  shown in place of the new-recipe/import flow. Trial users who hit the trial cap
  see the paywall, never the hard stop.
- Voice mode is hidden during `trialing` and `soft_wall` (`BillingGate.isVoiceAvailable`).
- Purchases use StoreKit 2 (`StoreKitManager`); receipts are validated **server-side
  only** via `POST /subscription/validate` (Apple JWS verification in
  `backend/src/lib/appstore.ts`) — never client-side. A transaction is bound to one
  account (re-claim → 409). The proxy still returns 402 `cap_reached` as the hard
  backend enforcement; the client gates proactively from entitlement + usage so the
  user isn't sent to OpenAI just to bounce.
- `POST /subscription/notify` is the App Store Server Notifications v2 webhook
  (unauthenticated; trust = Apple JWS signature) that keeps subscription status in
  sync over the lifecycle.

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

## Verification

**You verify your own work in the iOS Simulator.** Do not hand the operator a checklist for
anything you can drive yourself — that workflow predates Simulator access and is retired.

**Getting past the sign-in gate.** Every screen sits behind Sign in with Apple, and most
need a recipe on the canvas. `DebugFixture` (DEBUG only) supplies both offline — no backend,
no Keychain, no LLM spend:

```
xcrun simctl launch <udid> com.donutindustries.SousApp -sous-fixture canvas
```

- `-sous-fixture canvas` — recipe on the canvas (servings picker, a single-value timer, a
  ranged timer, RESET / RESTORE ORIGINAL buttons)
- `-sous-fixture review` — recipe + pending patch, landing on the change-review screen
- `-sous-fixture explore` — no canvas, generate pill showing
- `-sous-fixture-entitlement byok|subscriber|trialing|grace|soft_wall` — defaults to
  `subscriber`; drives the OG badge and the billing walls

The fixture never fakes a `PatchValidationResult` — the validator runs for real, so a bad
fixture surfaces as an invalid patch rather than a review screen that lies.

Use the `mcp__Claude_Code_iOS_Simulator__*` tools:
- Call `attach` **first**, before building, so the operator can watch.
- `build` → `launch`, then drive the app: `tap`, `swipe`, `text`, `screenshot`, `inspect`.
- Prefer `inspect` over `screenshot` for reading labels, control state, and what's on screen.
  Use `screenshot` for colour, layout and anything visual.
- **Check both light and dark mode** for any visual change (`xcrun simctl ui <udid>
  appearance dark|light`). Sous has tokens that deliberately do not invert (green, voice
  palette, white-on-burgundy labels), so dark mode is where colour bugs actually surface.
- **`inspect` is unavailable** in this app build, so there is no accessibility tree to read:
  locate controls by capturing `xcrun simctl io <udid> screenshot out.png` and measuring
  pixels. The capture is @3x, so **device points = pixels ÷ 3**. Eyeballing fractions off a
  scaled screenshot mis-taps; measuring the target's bounding box does not. Sampling pixel
  colours this way also verifies a token exactly (`#2D6A4F`) rather than "looks green".

**Escalate to the operator only for what the Simulator genuinely cannot do:** real Sign in
with Apple, StoreKit sandbox purchases, camera capture, haptics, Siri/Realtime voice against
live audio, and anything needing their own account data or a physical device. Say which of
these blocked you rather than listing it as a task for them.

---

## Definition of Done

A task is complete when:

1. `swift test` passes (all tests, no skips)
2. You have manually traced the happy path in your reasoning and it holds
3. **You have run the change in the iOS Simulator and seen it work** — not reasoned that it
   should. Anything the Simulator cannot reach is named explicitly, with why.

**Not done if:**
- Tests pass but you know an edge case isn't handled
- You've commented out a test to make the build green
- You are asking the operator to verify something the Simulator could have verified
- You report what *should* happen rather than what you *saw*

---

## Output Format

After completing any task, provide:

**Summary** — plain English, one short paragraph, what changed and why

**What you verified** — what you actually ran in the Simulator and what you saw, including
both light and dark mode for any visual change. Then, separately, **what you could not
verify and why** — the short list of things needing the operator's own device or accounts.

**Assumptions made** — anything you decided without explicit instruction
- Write assumptions in plain English for a non-technical PM — no Swift syntax, no framework jargon. If a technical concept is unavoidable, add a one-sentence plain English explanation in parentheses.

**Anything that needs a follow-up** — edge cases deferred, known gaps, things to watch

Do not provide a `git diff --stat` as the primary output. The operator cannot interpret it.

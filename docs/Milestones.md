# Sous — Milestones

This document tracks the major product milestones for Sous.
Each milestone represents a coherent, user-visible capability rather than an implementation checklist.

Statuses:
- **DONE** — implemented and working in the codebase
- **CURRENT** — actively being worked on
- **PLANNED** — clearly defined next milestone
- **FUTURE** — intentionally deferred; shape may evolve


## Project State

**Last reconciled against the codebase:** 2026-09-29.

**Current milestone:** Milestone 24 — Accounts + Sync. All four backend projects are code
complete; what remains is operator setup in App Store Connect and Railway, plus a sandbox
purchase test on a real device. None of that is code.

**Recently completed:**
- Milestone 24 Projects 1–4 — backend, auth, proxy, billing (code complete)
- Milestone 22 — Step Timers
- Milestone 21 — Recipe Import
- The design system migration — not a numbered milestone; see `design/TOKEN-DECISIONS.md`

**Next milestone:**
- Milestone 23 — Post-Cook Ratings. The first feature to be built *through* the design system
  rather than migrated into it.

This section exists to make the active project phase immediately visible to humans and AI agents
without scanning the entire roadmap. **It drifted badly once** — in September 2026 it named a
finished milestone as current and pointed "next" at the wrong number, while three shipped
milestones were still marked PLANNED or FUTURE. If you are reading it, spend the thirty seconds
to confirm it against the code before trusting it, and correct it when it is wrong.


---

## Milestone 1 — Persistent Recipe Canvas
**Status:** DONE

**Goal:** Treat the recipe as a living document, not chat output.

Core capabilities:
- Recipe displayed in a persistent canvas
- Chat never reprints full recipes
- Ingredients and steps are structured
- Steps have state (`todo` / `done`)
- Completed steps are immutable


---

## Milestone 2 — Patch-Based Editing + User Control
**Status:** DONE

**Goal:** Give users control over AI-driven changes.

Core capabilities:
- AI proposes structured recipe patches
- User explicitly approves or rejects changes
- Visual highlighting of proposed changes
- Undo/history support
- AI cannot rewrite completed steps


---

## Milestone 3 — Real LLM Integration
**Status:** DONE

**Goal:** Replace all mock behavior with real AI calls safely.

Core capabilities:
- OpenAI-powered recipe generation and edits
- Structured JSON responses
- Retry and error handling
- Proper zero-state → recipe creation flow


---

## Milestone 4 — Multimodal + Conversational Cooking
**Status:** DONE

**Goal:** Make Sous a true cooking assistant, not just a text editor.

Core capabilities:
- Photo upload and image analysis
- Photo + question → suggestions (not forced patches)
- Inline suggestion UI with Apply / Dismiss
- Multi-turn conversational context
- Clarifying questions for ambiguous commands
- No "time travel" on completed steps


---

## Milestone 5 — Native iOS Migration: App Skeleton + Sous Core
**Status:** DONE

**Goal:** Start the native iOS app with a rock-solid core state model.

Core capabilities:
- New native iOS app project (SwiftUI)
- **Sous Core** module that owns the canonical state model
- Deterministic patch validation
- Clear user-facing error messages for invalid patches
- Development-only seed data for fast iteration

Explicit non-goals:
- Shipping to users
- LLM / multimodal integration
- Accounts, sync, or persistence beyond basic local dev


---

## Milestone 6 — Native iOS Migration: Recipe Canvas + Cooking Mode UX
**Status:** DONE

**Goal:** Rebuild the core cooking experience natively so it is fast, predictable, and touch-first.

Core capabilities:
- Persistent **Recipe Canvas** in SwiftUI
- Cooking mode optimized for real-world use
- One-tap "Mark step done"
- Completed steps visibly locked
- Smooth scrolling and stable list rendering

Explicit non-goals:
- Patch UI (apply/reject)
- LLM calls
- Camera/photo capture


---

## Milestone 7 — Native iOS Migration: Patch Review + User Control
**Status:** DONE

**Goal:** Preserve Sous's defining interaction model in native: AI proposes changes; user approves or rejects; the recipe canvas updates safely.

Core capabilities:
- Proposed changes UI integrated directly into the recipe canvas
- Apply / Reject at the patch-set level
- Visual highlighting of proposed changes
- Guardrails preventing modification of completed steps

Explicit non-goals:
- Multimodal
- Local persistence / restore
- Accounts


---

## Milestone 8 — Native iOS Migration: LLM Integration (OpenAI Client)
**Status:** DONE

**Goal:** Bring back real AI behavior using a native OpenAI client while preserving Sous's deterministic patching guarantees and safety model.

Core capabilities:
- Native OpenAI client responsible for recipe generation and structured patch editing
- `LLMClient` networking boundary for OpenAI API calls and decoding
- `LLMOrchestrator` responsible for prompt construction, retry, and repair loops
- Structured `PatchSet` JSON contract returned by the model
- Deterministic validation via `PatchValidator` before any recipe mutation
- Strict JSON decoding with defensive error handling
- Retry / timeout / offline-friendly error states
- Clear separation of assistant conversational messages vs structured recipe patches
- Debug telemetry for retries, validation failures, and missing API key states
- Settings screen for API key entry (accessible in all builds)

Explicit non-goals:
- On-device model execution
- Accounts/sync


---

## Milestone 9 — Native iOS Migration: Photo Capture + Multimodal Flow
**Status:** DONE

**Goal:** Make photo-based help feel native, reliable, and fast.

Core capabilities:
- Native camera capture + photo picker
- Client-side image resizing/compression before upload
- Preview → send → result flow returning suggestions or optional patches
- Graceful permission handling and fallbacks
- Payload-too-large and network failure handling

Explicit non-goals:
- Advanced photo UX polish


---

## Milestone 10 — Native iOS Migration: Local Session Persistence + Crash-Proofing
**Status:** DONE

**Goal:** Ensure Sous survives real iOS behavior without losing cooking progress.

Core capabilities:
- Persist in-progress session locally
- Recipe state
- Step progress (`todo` / `done`)
- Pending AI changes
- Minimal chat context (last 20 messages)
- Silent restore on app relaunch
- Crash-safe write strategy (atomic swap)
- Schema versioning with clean fallback

This milestone is about **trust**.


---

## Milestone 11 — New Recipe Flow
**Status:** DONE

**Goal:** Let the user start a fresh recipe from scratch without restarting the app, and refine the 0-to-recipe experience as the primary testable surface.

Core capabilities:
- "New" button clears the current session and recipe canvas
- Returns to the blank starting state (no canvas, exploration mode active)
- Starting prompt accepts text, photo, or both
- Session persistence from M10 handles the clean wipe correctly (no orphaned state)

Explicit non-goals:
- Saving or accessing previous recipes
- Any list or history UI


---

## Milestone 12 — Recent Recipes
**Status:** DONE

**Goal:** Let the user return to recipes they've worked on before.

Core capabilities:
- Recent recipes list (last N recipes, most recent first)
- Tap to resume a previous recipe session
- Each saved recipe is a self-contained session with its own recipe canvas and chat history. Resuming a recipe restores both.
- New recipe replaces current session or prompts if one is in progress
- Persistent storage of multiple recipe sessions

Explicit non-goals:
- Search or filtering
- Favourites or collections
- Cloud sync


---

## Milestone 13 — Chat Rendering
**Status:** DONE

**Goal:** Make chat feel like a real messaging interface — formatted, readable, and expressive.

Core capabilities:
- Markdown rendered in chat bubbles (bold, italic, bullet lists, numbered lists, headers)
- Long messages remain readable and scroll correctly
- No visual regressions in existing chat UI

Explicit non-goals:
- Image display in chat (deferred to a future paid feature)
- Custom fonts or branded typography (belongs in the design milestone)


---

## Milestone 14 — Tone and Model Behavior
**Status:** DONE

**Goal:** Make the AI feel like a genuinely helpful, warm, and opinionated cooking companion — not a corporate chatbot reading from a script.

Core capabilities:
- System prompt rewritten for natural, conversational tone
- AI offers opinions and makes recommendations rather than presenting every option with equal weight
- Exploration phase feels like talking to a knowledgeable friend, not selecting from a menu
- Clarifying questions feel natural, not robotic
- AI handles casual, incomplete, or messy user input gracefully without demanding rephrasing
- Consistent personality across creation, editing, and cooking modes

Explicit non-goals:
- User-configurable tone settings (belongs in a later milestone)
- Training or fine-tuning a custom model


---

## Milestone 15 — Persistent Preferences
**Status:** DONE

**Goal:** Let users tell Sous about themselves once, so they never have to repeat it.

Core capabilities:
- Preferences screen in Settings with the following fields:
  - Ingredients or foods to always avoid (hard constraints)
  - Default number of people to serve
  - Kitchen tools and equipment available (e.g. cast iron, induction plate, air fryer, stand mixer). 
  - Free-form custom instructions (e.g. "always give me stove settings for both gas and induction")
- Preferences applied silently to all new recipes
- Preferences visible and editable at any time
- Per-recipe overrides available via chat ("just for this one, fish is fine")
- Preferences never retroactively modify completed recipe steps

Explicit non-goals:
- Inferred or learned preferences (always explicit and user-declared)
- Preference sync across devices (belongs with accounts)


---

## Milestone 16 — Memories
**Status:** DONE

**Goal:** Let Sous remember things the user expresses in conversation, so preferences and context accumulate naturally over time.

Core capabilities:
- When the AI detects a memorable preference or fact in chat (e.g. "I hate cilantro", "I'm cooking for my kids tonight"), it proposes adding a memory. The proposal is not done in-line in the chat, it is done via a non-disruptive toast element
- A non-disruptive toast notification appears at the top of the chat showing what is being remembered
- User can immediately dismiss or edit the proposed memory before it is saved
- Memories are visible and editable in a dedicated section in Settings
- User can delete individual memories at any time
- Memories are included as context in future AI requests

Explicit non-goals:
- Automatic memory application without user visibility
- Memory sync across devices (belongs with accounts)
- Memories that override hard preferences set in Milestone 15


---

## Milestone 17 — Design
**Status:** DONE

**Goal:** Make Sous look and feel like a product someone would want to use, not a functional prototype.

Core capabilities:
- Cohesive visual identity applied across all screens
- Typography, color, spacing, and iconography treated as a system
- Recipe canvas feels premium and readable
- Chat feels warm and conversational
- Onboarding and blank state have personality
- Dark mode support

Also implemented as part of this milestone:
- **Unit system preference** — users can choose imperial or metric in Settings; the preference is applied silently to all new recipe generation. Defaults to imperial for US and UK locales, metric elsewhere.
- **Post-import unit conversion** — after importing a recipe, the app detects whether the recipe's units match the user's preference. If they differ, a modal offers to convert the whole recipe silently (no patch review). If no measurable units are detected, the modal is skipped entirely.

Explicit non-goals:
- Animations and transitions polish (can follow in a separate pass)
- Marketing or App Store assets


---

## Milestone 18 — Streaming Chat Responses
**Status:** DONE

**Goal:** Make the AI feel responsive and alive by streaming chat replies word by word as they are generated, rather than displaying them all at once after a delay.

Core capabilities:
- Chat responses stream in token by token in real time using OpenAI's streaming API
- The chat bubble appears immediately and fills in as text arrives
- A visible indicator shows the assistant is typing before the first token arrives
- Streaming applies to conversational replies only — recipe generation patches are still delivered as complete structured responses (streaming and JSON patch parsing are incompatible)
- Errors and timeouts are handled gracefully mid-stream
- No regression to existing patch flow, retry logic, or validation behavior

Explicit non-goals:
- Streaming recipe patch generation
- Streaming photo/multimodal responses

---
## Milestone 19 — Personality Modes
**Status:** DONE
**Goal:** Let users choose how Sous talks to them.

Core capabilities:

- A tone setting in the Preferences screen with three named modes: Minimal, Normal, and Playful
- Default is Normal (current behavior)
- Selected mode name passed explicitly to the LLM on every request alongside other preferences
- System prompt has distinct behavioral instructions per mode:

Minimal — no filler, no encouragement, no personality. Directions and direct answers only. Think a recipe card that talks.
Normal — current behavior: warm, opinionated, conversational without being extra
Playful — jokes, puns, irreverence, stronger opinions, allowed to chirp you when you burn the garlic


- Mode applies across all phases: exploration, cooking, patch proposals, recovery
- In Playful mode, the AI mirrors the user's vocabulary and humor when it appears naturally in conversation (e.g. invented words, recurring jokes, personal shorthand). Minimal mode suppresses this. Normal mode mirrors lightly.

Explicit non-goals:

- Per-recipe tone overrides (global setting only for now)
- User-defined custom tone via free text (the existing custom instructions field covers that)
- Visual or animated personality expression
---

## Milestone 20 — TestFlight Alpha + Instrumentation
**Status:** DONE

**Goal:** Ship a usable alpha to real users with enough observability to fix issues quickly.

Core capabilities:
- TestFlight distribution
- Basic instrumentation
- Error logging
- Performance signals
- In-app feedback

Explicit non-goals:
- Monetization
- Growth loops

---

## Milestone 21 — Recipe Import
**Status:** DONE

**Goal:** Let users bring any existing recipe into Sous from a photo, screenshot, or pasted text, and immediately start cooking with it.

**Core capabilities:**
- "Talk to a recipe" CTA on the zero state screen as the primary entry point
- Three import sources: camera, photo library, paste text
- AI extracts the recipe faithfully — title, ingredients, steps — without editorializing
- Uncertain or illegible lines flagged inline with `[??]`
- Canvas generated immediately on extraction; no pre-generation confirmation step
- First AI chat message after canvas load invites the user to adapt the recipe (serving size, substitutions, etc.)
- All subsequent edits follow the existing patch flow
- New routing intent: `import_existing_recipe` — skips exploration phase entirely

**Explicit non-goals:**
- URL import (pasting a recipe website link)
- User-editable correction step before canvas generation
- Batch import


---
## Milestone 22 — Step Timers
**Status:** DONE

*(Corrected 2026-09-29: this was still marked PLANNED long after it shipped. `Timers/` holds the
parser, manager, persistence and summariser; `StepTimeParserTests` covers the detection; the
banners were migrated into the design system as surface 1 of that work.)*

**Goal:** Let users start a countdown directly from a recipe step, so they never lose track of cooking time.

Core capabilities:
- Inline time detection in step text with highlighted affordance and timer SF Symbol
- Exact time → timer starts immediately; range time → duration picker pre-filled with lower bound
- Maximum 3 concurrent timers; attempting a 4th fires an error haptic
- Fixed banner stack above chat button showing step summary, live countdown, and edit control
- Tapping a running banner scrolls to and highlights the relevant step
- Step completion blocked while its timer is running (error haptic on attempt)
- Local notification fires when timer expires with app backgrounded
- Timer done state: large terracotta panel with step summary and "TIMER DONE"; dismisses to step highlight
- Active timer state persists across app background and relaunch
- On-device short step summary via FoundationModels (iOS 18.1+) with truncation fallback

Explicit non-goals:
- Live Activities (explicitly deferred to a future milestone)
- Timer history or logs
- Timers surviving device restart
---

## Milestone 23 — Post-Cook Ratings
**Status:** PLANNED

**Goal:** Let users reflect on how a cook went, creating a feedback loop that makes Sous more useful over time.

Core capabilities:
- After completing a recipe (all steps marked done), a rating prompt appears
- Two separate ratings: recipe quality and the user's own execution
- Optional free-text note
- Ratings stored with the recipe session
- Ratings visible when browsing recent recipes

Explicit non-goals:
- Using ratings to automatically alter future recipe generation
- Sharing ratings publicly
- Aggregate or community ratings


---



---

## Milestone 24 — Accounts + Sync
**Status:** IN PROGRESS (delivered as the 4-project backend plan — see `docs/BackendEngineeringPlan.md`)

**Goal:** Establish durable user accounts so preferences, memories, and recipes persist across devices and reinstalls.

Project tracking:
- **Project 1 — Backend Foundation — ✅ Code complete** (Supabase schema, Hono API, auth/config/entitlement endpoints).
- **Project 2 — iOS Auth Integration — ✅ Code complete.** Sign in with Apple gates the app; session token in Keychain; Account section in Settings; preferences + memories sync to the backend on change and hydrate (server-wins) on sign-in; BYOK users keep direct OpenAI routing with an OG badge. Backend sync endpoints (`/sync/preferences`, `/sync/memories`, `/sync/profile`) implemented.
- **Project 3 — API Proxy + Instrumentation — ✅ Code complete.** Non-BYOK users' OpenAI calls route through the Sous backend proxy (`/proxy/chat`), which records `usage_events`, enforces the recipe cap (402 when reached), and runs conservative off-topic + abuse detection. Settings shows live usage counts. BYOK users are unaffected (direct OpenAI). Operator-only admin dashboard (`/admin/dashboard`) surfaces cost, active users, cap-hit rate, and flagged accounts. Operator setup pending: set `OPENAI_API_KEY` + `ADMIN_API_KEY` on Railway and re-run `db/schema.sql`.
- **Project 4 — Billing + Paywall — ✅ Code complete.** StoreKit 2 monthly subscription (`StoreKitManager`) with server-side receipt validation (`POST /subscription/validate`, Apple JWS verification) and the App Store Server Notifications v2 webhook (`POST /subscription/notify`) keeping subscription status in sync over the lifecycle (renew / expire / grace / refund). Full-screen `PaywallView` (soft wall / Settings "Upgrade"), `CapReachedView` whale-UX hard stop at the 100/month paid cap, voice mode blocked during trial. Entitlement-driven UI; the proxy still hard-enforces the cap (402). Operator setup pending: create the App Store Connect subscription + sandbox tester, set `APP_STORE_NOTIFICATION_SECRET` on Railway, point the notification URLs at `/api/v1/subscription/notify`, and sandbox-test the purchase on device.

Core capabilities:
- User accounts ✅
- Preferences and memories synced to account ✅
- Usage instrumentation + recipe-cap metering ✅ (Project 3)
- Subscription billing + paywall + trial enforcement ✅ (Project 4)
- Recipe history synced to account ⬜ (deferred — `/sync/recipes` still a stub)
- First-run account setup flow ✅ (sign-in gate)

Explicit non-goals:
- Social features
- Sharing recipes with other users


---

## Milestone 25 — Planning, Shopping, and Prep
**Status:** FUTURE

Potential capabilities:
- Shopping lists
- Ingredient availability checks
- Recipe scaling
- Prep timelines


---

## Milestone 26 — Voice & Hands-Free Cooking
**Status:** PARTIALLY DELIVERED — needs the operator's call on what counts as done

*(Corrected 2026-09-29.)* Voice mode ships today: `Voice/` holds the Realtime API client, the
coordinator and its five states (ready, listening, thinking, speaking, patchPending), a voice
system prompt, and the voice bar UI with its own colour palette. It is entitlement-gated —
hidden during `trialing` and `soft_wall`.

What is **not** confirmed against the original bullets below is step navigation and
context-aware recovery. Those need judging against how the feature actually behaves in a real
kitchen, which is a product call, not something readable from the code.

Potential capabilities:
- Voice input/output
- Step navigation
- Timers
- Context-aware recovery


---

## Milestone 27 — Monetization
**Status:** SUPERSEDED — delivered early, under Milestone 24 Project 4

*(Corrected 2026-09-29.)* Monetization was deferred here, then overtaken: the StoreKit 2
subscription, server-side receipt validation, the paywall, the trial, the grace period and the
100-a-month hard cap all landed as Project 4 of the backend plan. This milestone is kept for its
Pro-feature list, which is still an open question, not a delivered thing.

Notes:
- Monetization was originally deferred here; see Milestone 24 Project 4 for what shipped
- Possible Pro features: inline image display, generated images, voice-first cooking mode, higher-fidelity models, longer context and history, advanced coaching
    


---

## Milestone 28 — Save to Memory: Fixes
**Status:** PLANNED

**Goal:** Make memory saving something the user chooses, rather than something that happens to
them — and fix the correctness bugs found while instrumenting it.

The memory decision log (`Debug/MemoryDecisionRecord.swift`) was added precisely because this
system "gets goofy a bit." Its own documentation states the question it exists to answer: *is
memory saving overzealous?* This milestone is answering that question and acting on it.

Core capabilities:
- **Decide the default.** Today a proposal saves itself when the six-second countdown expires,
  and saves itself again if the user swipes it away. Both of those are opt-out — the user gets a
  memory by ignoring a toast. The log's `MemorySaveTrigger` cases already distinguish a deliberate
  SAVE from the two automatic ones, so the actual rate is measurable rather than guessed at.
  Decide from that data whether the default flips to save-nothing-unless-tapped.
- **Fix the person mismatch.** The eval suite asks the model for a third-person `proposed_memory`
  while the shipped Swift prompt requires second person. See `docs/KnownIssues.md`. One of the two
  is wrong and they disagree today.
- **Tighten what qualifies.** Review real proposals from the log and sharpen the prompt's bar for
  what counts as a durable preference versus a passing remark about tonight's dinner.
- **Make the toast's timing legible.** If a countdown can save, the user has to be able to see it
  running and stop it. If it cannot save, the countdown may not need to exist at all.
- **Eval coverage** for every rule changed here, per the repo's eval policy.

Explicit non-goals:
- Changing where memories are stored or how they sync
- Automatic memory application without user visibility — Milestone 16's non-goal still stands
- The decisioning engine itself — that is Milestone 29

---

## Milestone 29 — On-Device Memory Decisioning
**Status:** PLANNED — *technology to be confirmed with the operator (see note)*

**Goal:** Move the judgement call of *is this worth remembering?* off the main chat model and onto
something cheaper, faster, and more consistent.

**Note on the name.** The operator asked for this as "Jev-powered" decisioning. That term appears
nowhere in this repo and is not resolved yet, so this milestone is written around the shape of the
work rather than the technology. Fill in the engine before starting, and rename the milestone.

Why this is separate from Milestone 28: that one fixes the *behaviour* of the existing system
using the model already in play. This one changes *what does the deciding*. Doing them together
would make it impossible to tell which change caused which effect.

Core capabilities:
- Route the "should this be remembered, and as what" decision to the chosen engine, keeping the
  main orchestrator's contract unchanged
- A/B the new decisioning against today's behaviour on real logged turns before it becomes default
- Fall back to current behaviour when the engine is unavailable, rather than silently proposing
  nothing
- Eval cases covering the new routing path, per the repo's eval policy

Explicit non-goals:
- Changing the memory *proposal UI* — that is Milestone 28
- Routing anything other than memory decisioning to this engine, for now

---

## Milestone 30 — Chat Error Handling and Retry
**Status:** DONE (chat) — voice mode deferred, see "Still open" below

**Goal:** Make a failed message something the user can recover from in one tap, instead of a dead
end that loses what they typed.

Core capabilities:
- A visible **RETRY** control on any message that failed, re-sending the original turn
- Retry logic that distinguishes what is worth retrying automatically (a dropped connection, a
  rate limit, a timeout) from what is not (a refusal, a cap-reached 402, an invalid key)
- The user's text is never lost to a failure — it survives in the composer or the failed bubble
- Error copy that says what happened and what to do, in Sous's voice, not the raw API message
- Distinct handling for the billing errors that already exist: a 402 cap-reached is a wall, not a
  network blip, and must not be retried into the same wall
- Voice mode gets the same treatment: `VoiceModeCoordinator` already models `socketClosed` and
  `timeout` and currently has its own recovery path

Explicit non-goals:
- Offline queueing of messages to send later
- Retrying a turn that already partially mutated recipe state — the patch contract governs that

**What shipped (2026-09-29):**
- `ChatFailure.classify` (SousCore) sorts every `LLMError` into *retryable* (transient
  transport), *rephrase* (the turn itself is the problem) or *wall* (cap, auth, missing key),
  and owns the user-facing sentence. The orchestrator's old copy map now delegates to it, so
  the wording and the decision about whether RETRY appears can never disagree.
- A failed turn carries its own recovery on the chat bubble (`ChatFailureRecord`): the
  classified failure plus the original turn, verbatim. RETRY re-sends that turn unchanged;
  it rides along in `SessionSnapshot`, so a retry offered before backgrounding is still
  there on return.
- Walls get a route, not a dead end: a 402 cap offers SEE OPTIONS (through the same
  `gateGenerative` fork every other entry point uses), a 401/403 offers SIGN IN AGAIN, and a
  missing BYOK key offers no button because the copy points at Settings.
- **The proxy no longer collapses every 4xx into `.badRequest`.** 402 is now `capReached`
  and 400 `off_topic` keeps the backend's own copy. Without this, "never retry into the same
  wall" was not expressible.
- The pre-canvas recipe-creation stream, which previously dead-ended on a hardcoded network
  sentence, now goes through the same classifier — except when the stream already began
  writing a recipe, which is the non-goal above.
- Failure bubbles are filtered out of the conversation history sent to the model, so error
  chrome never teaches it to apologise.
- Fixtures `-sous-fixture chatRetry` and `chatWall`.

**Still open:**
- **Voice mode.** `VoiceModeCoordinator` keeps its own recovery path. The classifier is
  transport-agnostic and ready for it; this was deferred deliberately to keep the milestone
  to one surface.
- No automatic retry layer was added. The orchestrator already backs off internally on
  transient errors; a second one would double token spend on every blip to save one tap.

---

## Milestone 31 — Recipe Export as PDF
**Status:** PLANNED

**Goal:** Let a user take a recipe out of Sous — to print, to keep, or to send to someone who
does not have the app.

Core capabilities:
- Export the current recipe as a PDF from the canvas
- The PDF carries Sous's design system — New York titles, the burgundy section headers, the
  square checkboxes — rather than a generic system-font dump. This is the first surface where
  the design tokens have to render outside SwiftUI, which is the interesting part of the work
- Includes ingredients, mise en place, and procedure; excludes chat transcript and timers
- Shares through the standard iOS share sheet
- Handles a long recipe across multiple pages without orphaning a section header

Explicit non-goals:
- Export formats other than PDF
- Editing or re-importing an exported file
- Exporting the whole recipe history at once

---

## Milestone 32 — Motion and Transitions
**Status:** PLANNED

**Goal:** Make the app feel considered in motion, the way it now does at rest.

The design system settled colour, type and iconography. Motion was never part of it — every
transition in the app is either a SwiftUI default or a one-off, which is exactly the state the
palette was in before the migration.

Core capabilities:
- A small set of named motion tokens — durations and easing curves — living alongside the colour
  and type tokens, so a transition is chosen from a scale rather than invented per screen
- Applied to the transitions users meet most: the chat sheet, the history drawer, the patch
  review screen, the timer banners arriving and leaving, and the memory toast
- Motion respects **Reduce Motion**; the system's accessibility setting is honoured everywhere
- Extend `design/check-tokens.py` to catch hand-written durations, the same way it catches
  hand-written colours today
- Document the decisions in `design/TOKEN-DECISIONS.md` as the next numbered entries

Explicit non-goals:
- Animated illustrations or decorative motion
- Live Activities — still deferred, per Milestone 22

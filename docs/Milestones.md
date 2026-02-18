# Sous — Milestones

This document tracks the major product milestones for Sous.
Each milestone represents a coherent, user-visible capability rather than an implementation checklist.

Statuses:
- **DONE** — implemented and working in the codebase
- **CURRENT** — actively being worked on
- **PLANNED** — clearly defined next milestone
- **FUTURE** — intentionally deferred; shape may evolve


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
- Server-side API key handling
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
- No “time travel” on completed steps


---

## Milestone 5 — Native iOS Migration: App Skeleton + Sous Core  
**Status:** CURRENT

**Goal:** Start the native iOS app with a rock-solid core state model (recipe canvas + patch rules) so we can build a zero-jank UX without changing Sous’s behavioral contract.

Core capabilities:
- New native iOS app project (SwiftUI)
- **Sous Core** module that owns the canonical state model:
  - Recipe, ingredients, steps (`todo` / `done`)
  - “Completed steps are immutable” enforcement
  - Pending patch / change-set representation
- Deterministic patch validation:
  - Reject patches that target `done` steps
  - Reject invalid IDs / schema violations
  - Clear user-facing error messages for invalid patches
- Development-only seed data for fast iteration (no LLM required yet)

Explicit non-goals:
- Shipping to users
- LLM / multimodal integration
- Accounts, sync, or persistence beyond basic local dev


---

## Milestone 6 — Native iOS Migration: Recipe Canvas + Cooking Mode UX  
**Status:** PLANNED

**Goal:** Rebuild the core cooking experience natively so it is fast, predictable, and touch-first.

Core capabilities:
- Persistent **Recipe Canvas** in SwiftUI
- Cooking mode that optimizes for real-world use:
  - Big, readable steps
  - Clear current step focus
  - One-tap “Mark step done”
  - Completed steps visibly locked
- Bottom composer area (ask + actions) that does not fight the keyboard
- Correct iOS safe-area behavior (no viewport hacks)
- Smooth scrolling and stable list rendering (step IDs remain stable)

Explicit non-goals:
- Patch UI (apply/reject)
- LLM calls
- Camera/photo capture


---

## Milestone 7 — Native iOS Migration: Patch Review + User Control  
**Status:** PLANNED

**Goal:** Preserve Sous’s defining interaction model in native: AI proposes changes; user approves or rejects; the recipe canvas updates safely.

Core capabilities:
- “Proposed changes” UI for patch sets
- Apply / Reject at the patch-set level
- Visual highlighting of proposed changes in the recipe canvas
- Undo support for applied patch sets (bounded)
- Guardrails:
  - No rewriting completed steps
  - No silent patch application

Explicit non-goals:
- Multimodal
- Local persistence / restore
- Accounts


---

## Milestone 8 — Native iOS Migration: LLM Integration (Server-Backed)  
**Status:** PLANNED

**Goal:** Bring back real AI behavior using the existing server-backed approach while keeping the native app deterministic and safe.

Core capabilities:
- Native client calls existing backend endpoints for:
  - New recipe generation
  - Edits that return structured patches
- Strict JSON decoding with defensive error handling
- Retry / timeout / offline-friendly error states
- Clear separation of:
  - Assistant conversational messages
  - Structured patches for the recipe

Explicit non-goals:
- On-device model execution
- Accounts/sync


---

## Milestone 9 — Native iOS Migration: Photo Capture + Multimodal Flow  
**Status:** PLANNED

**Goal:** Make photo-based help feel native, reliable, and fast.

Core capabilities:
- Native camera capture + photo picker
- Client-side image resizing/compression before upload
- Preview → send → result flow that returns:
  - Suggestions (non-patch) OR
  - Optional patches with Apply / Dismiss
- Graceful permission handling and fallbacks
- Payload-too-large and network failure handling

Explicit non-goals:
- Advanced photo UX polish (that comes later)


---

## Milestone 10 — Native iOS Migration: Local Session Persistence + Crash-Proofing  
**Status:** PLANNED

**Goal:** Ensure Sous survives real iOS behavior (backgrounding, termination, reloads) without losing cooking progress.

Core capabilities:
- Persist in-progress session locally:
  - Recipe state
  - Step progress (`todo` / `done`)
  - Pending AI changes (unapplied patches)
  - Minimal chat context for continuity
- Silent restore on app relaunch
- Data model migrations (forward-compatible schema changes)
- Crash-safe write strategy (atomic writes / journaling)

This milestone is about **trust**.


---

## Milestone 11 — Native iOS Migration: TestFlight Alpha + Instrumentation  
**Status:** PLANNED

**Goal:** Ship a usable alpha to real users with enough observability to fix issues quickly.

Core capabilities:
- TestFlight distribution (internal → external)
- Basic instrumentation:
  - Key funnel events (create recipe, apply patch, mark step done, send photo)
  - Error logging for patch validation failures and network/LLM failures
  - Performance signals for UI jank and time-to-interactive
- Lightweight in-app “Send feedback” affordance (logs + context)
- Guardrails for privacy and data minimization

Explicit non-goals:
- Monetization
- Growth loops


---

## Milestone 12 — Accounts + Cooking Defaults  
**Status:** PLANNED

**Goal:** Establish durable, user-facing accounts to protect user data long-term, and eliminate repeated restatement of basic cooking constraints via explicit, persistent Cooking Defaults.

This milestone formalizes user ownership and trust. Accounts are user-visible, support logout and multi-device use, and provide a stable foundation for future features.

Core capabilities:
- User-facing accounts with durable identity and data ownership
  - Clear mental model of ownership (“my recipes, my defaults”)
  - Explicit login / logout support
  - Designed to safely persist user data long-term
- Persistent storage of user-declared Cooking Defaults:
  - Default portion count
  - Hard-avoid ingredients or food categories (string-based, conservative matching)
- First-run setup flow to collect defaults (skippable)
- Editable defaults via settings or explicit command
- Defaults automatically applied to all new recipe generation
- Explicit override semantics:
  - Per-recipe overrides do not mutate defaults
  - Defaults change only when user explicitly requests it
- AI must not violate hard-avoids without asking for confirmation

Explicit non-goals:
- Preference inference or learning
- Soft preferences (e.g. "likes garlic-forward food")
- Skill tracking or outcome logging


---

## Milestone 13 — LLM Behavior Calibration (Style + Adaptation)  
**Status:** PLANNED

**Goal:** Make Sous’s responses feel aligned with the user’s communication style while preserving correctness and state safety.

Core capabilities:
- Explicit user-configurable style preferences (e.g. concise vs detailed, opinionated vs exploratory)
- Optional, bounded style inference from recent interactions
- Consistent tone and formatting across sessions
- Improved intent sensitivity (when to explain vs when to direct)
- Style must never override correctness or patching rules

Explicit non-goals:
- Training custom models
- Long-term behavioral learning without user control
- Style changes that affect recipe state integrity


---

## Milestone 14 — Camera Reliability + Photo UX  
**Status:** PLANNED

**Goal:** Make photo-based assistance reliable and confidence-inspiring on iPhone.

Core capabilities:
- Graceful permission handling
- Client-side image resizing/compression
- No payload-too-large failures
- Smooth preview → send → suggestion flow

This milestone is about **confidence**.


---

## Milestone 15 — Planning, Shopping, and Prep  
**Status:** FUTURE

**Goal:** Move Sous earlier in the cooking lifecycle.

Potential capabilities:
- Shopping list generation
- Ingredient availability checks
- Recipe scaling before cooking
- Prep timelines and planning assistance


---

## Milestone 16 — Voice & Hands-Free Cooking  
**Status:** FUTURE

**Goal:** Support hands-busy, eyes-busy cooking scenarios.

Potential capabilities:
- Voice input and output
- “Next step” and “repeat that”
- Timers and reminders
- Context-aware recovery guidance


---

## Milestone 17 — Monetization  
**Status:** FUTURE

**Goal:** Sustain development without compromising core UX.

Notes:
- No monetization decisions yet
- Possible Pro features may include voice mode, advanced photo analysis, or planning tools
- Explicitly deferred until product value is fully validated
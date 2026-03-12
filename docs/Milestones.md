# Sous — Milestones

This document tracks the major product milestones for Sous.
Each milestone represents a coherent, user-visible capability rather than an implementation checklist.

Statuses:
- **DONE** — implemented and working in the codebase
- **CURRENT** — actively being worked on
- **PLANNED** — clearly defined next milestone
- **FUTURE** — intentionally deferred; shape may evolve


## Project State

**Current milestone:** Milestone 12 — Recent Recipes

**Recently completed:**
- Milestone 11 — New Recipe Flow
- Milestone 10 — Native iOS Migration: Local Session Persistence + Crash-Proofing
- Milestone 9 — Native iOS Migration: Photo Capture + Multimodal Flow

**Next milestone:**
- Milestone 13 — Native iOS Migration: TestFlight Alpha + Instrumentation

This section exists to make the active project phase immediately visible to humans and AI agents without scanning the entire roadmap.


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
**Status:** CURRENT

**Goal:** Let the user return to recipes they've worked on before.

Core capabilities:
- Recent recipes list (last N recipes, most recent first)
- Tap to resume a previous recipe session
- New recipe replaces current session or prompts if one is in progress
- Persistent storage of multiple recipe sessions

Explicit non-goals:
- Search or filtering
- Favourites or collections
- Cloud sync


---

## Milestone 13 — Native iOS Migration: TestFlight Alpha + Instrumentation
**Status:** PLANNED

**Goal:** Ship a usable alpha to real users with enough observability to fix issues quickly.

Core capabilities:
- TestFlight distribution
- Basic instrumentation
- Error logging
- Performance signals
- In‑app feedback

Explicit non-goals:
- Monetization
- Growth loops


---

## Milestone 14 — Accounts + Cooking Defaults
**Status:** PLANNED

**Goal:** Establish durable user accounts and persistent cooking defaults.

Core capabilities:
- User accounts
- Persistent cooking defaults
- First-run setup flow
- Editable defaults
- Explicit override semantics

Explicit non-goals:
- Preference inference
- Soft preferences
- Skill tracking


---

## Milestone 15 — LLM Behavior Calibration (Style + Adaptation)
**Status:** PLANNED

**Goal:** Align AI responses with the user's communication style while preserving correctness and safety.

Core capabilities:
- Style preferences
- Bounded style inference
- Consistent tone
- Improved intent sensitivity

Explicit non-goals:
- Training custom models
- Uncontrolled behavioral learning


---

## Milestone 16 — Camera Reliability + Photo UX
**Status:** PLANNED

**Goal:** Make photo-based assistance reliable and confidence-inspiring.

Core capabilities:
- Permission handling
- Image resizing/compression
- Smooth preview → send flow


---

## Milestone 17 — Planning, Shopping, and Prep
**Status:** FUTURE

Potential capabilities:
- Shopping lists
- Ingredient availability checks
- Recipe scaling
- Prep timelines


---

## Milestone 18 — Voice & Hands-Free Cooking
**Status:** FUTURE

Potential capabilities:
- Voice input/output
- Step navigation
- Timers
- Context-aware recovery


---

## Milestone 19 — Monetization
**Status:** FUTURE

Notes:
- Monetization intentionally deferred
- Possible Pro features later

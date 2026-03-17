# Sous — Milestones

This document tracks the major product milestones for Sous.
Each milestone represents a coherent, user-visible capability rather than an implementation checklist.

Statuses:
- **DONE** — implemented and working in the codebase
- **CURRENT** — actively being worked on
- **PLANNED** — clearly defined next milestone
- **FUTURE** — intentionally deferred; shape may evolve


## Project State

**Current milestone:** Milestone 19 — Personality Modes

**Recently completed:**
- Milestone 18 — Streaming Chat Responses
- Milestone 17 — Design
- Milestone 16 — Memories

**Next milestone:**
- Milestone 20 — Post-Cook Ratings

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

## Milestone 20 — Post-Cook Ratings
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

## Milestone 21 — TestFlight Alpha + Instrumentation
**Status:** PLANNED

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

## Milestone 22 — Accounts + Sync
**Status:** PLANNED

**Goal:** Establish durable user accounts so preferences, memories, and recipes persist across devices and reinstalls.

Core capabilities:
- User accounts
- Preferences and memories synced to account
- Recipe history synced to account
- First-run account setup flow

Explicit non-goals:
- Social features
- Sharing recipes with other users


---

## Milestone 23 — Planning, Shopping, and Prep
**Status:** FUTURE

Potential capabilities:
- Shopping lists
- Ingredient availability checks
- Recipe scaling
- Prep timelines


---

## Milestone 24 — Voice & Hands-Free Cooking
**Status:** FUTURE

Potential capabilities:
- Voice input/output
- Step navigation
- Timers
- Context-aware recovery


---

## Milestone 25 — Monetization
**Status:** FUTURE

Notes:
- Monetization intentionally deferred
- Possible Pro features: inline image display, generated images, voice-first cooking mode, higher-fidelity models, longer context and history, advanced coaching
    

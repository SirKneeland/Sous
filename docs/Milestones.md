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

## Milestone 5 — iPhone-First UX + Phone-Loadable URL  
**Status:** CURRENT

**Goal:** Make Sous usable on a real iPhone during actual cooking.

Core capabilities:
- App loads via public HTTPS URL (e.g. Vercel)
- Mobile-first, recipe-focused layout
- Recipe always anchored at the top
- Chat always anchored at the bottom
- Cooking-focused mode hides chat history
- Persistent bottom action bar:
  - “Ask Sous…” (text)
  - Camera shortcut
- Chat expands upward when engaged; collapses back to cooking mode
- Proper handling of iOS safe areas and viewport units
- Desktop UX remains unchanged

Explicit non-goals:
- Session persistence
- Camera reliability hardening
- Native iOS app work
- Authentication / accounts


---

## Milestone 6 — Session Persistence  
**Status:** PLANNED

**Goal:** Ensure Sous can survive real-world iOS behavior (reloads, evictions).

Core capabilities:
- Persist in-progress cooking session locally
- Resume recipe, step progress, and pending AI changes after reload
- Persist limited chat history for continuity
- Silent restore on app load
- Durable storage suitable for iOS (e.g. IndexedDB)

This milestone is about **trust**.


---

## Milestone 7 — Camera Reliability + Photo UX  
**Status:** PLANNED

**Goal:** Make photo-based assistance reliable and confidence-inspiring on iPhone.

Core capabilities:
- Reliable iPhone camera capture in web/PWA
- Graceful permission handling
- Client-side image resizing/compression
- No payload-too-large failures
- Smooth preview → send → suggestion flow

This milestone is about **confidence**.


---

## Milestone 8 — Planning, Shopping, and Prep  
**Status:** FUTURE

**Goal:** Move Sous earlier in the cooking lifecycle.

Potential capabilities:
- Shopping list generation
- Ingredient availability checks
- Recipe scaling before cooking
- Prep timelines and planning assistance


---

## Milestone 9 — Voice & Hands-Free Cooking  
**Status:** FUTURE

**Goal:** Support hands-busy, eyes-busy cooking scenarios.

Potential capabilities:
- Voice input and output
- “Next step” and “repeat that”
- Timers and reminders
- Context-aware recovery guidance


---

## Milestone 10 — Monetization  
**Status:** FUTURE

**Goal:** Sustain development without compromising core UX.

Notes:
- No monetization decisions yet
- Possible Pro features may include voice mode, advanced photo analysis, or planning tools
- Explicitly deferred until product value is fully validated
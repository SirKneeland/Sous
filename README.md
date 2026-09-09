# Sous

A native iOS cooking assistant that treats a recipe as a living document, not chat output.

You talk to Sous like a knowledgeable friend — "I'm out of onions," "I burned the garlic," 
"can this be spicier?" — and it mutates the recipe canvas in real time rather than 
reprinting the whole thing. Changes are proposed as structured patches you explicitly 
accept or reject. Completed steps are immutable.

## What it does

- **Recipe canvas** — persistent, structured, and stateful. The single source of truth.
- **Patch-based editing** — the AI proposes changes; you approve or reject them.
- **Exploration → commit flow** — helps you decide what to cook before generating anything.
- **Persistent preferences** — dietary constraints, equipment, and custom instructions 
  applied silently to every recipe.
- **Memories** — remembers things you mention in conversation across sessions.
- **Recent recipes** — resume any previous session with its recipe and chat history intact.

## Status

Active development. Currently working toward TestFlight alpha (Milestone 19).

## Stack

- SwiftUI (iOS)
- OpenAI API (structured JSON output + patch validation)
- Local persistence via atomic file writes

## Evals

The `/evals` directory contains a live LLM eval suite that tests model behavior against the real system prompts.

**Setup:**
```
cd evals
cp .env.example .env
# Fill in BRAINTRUST_API_KEY and OPENAI_API_KEY
```

**Run:**
```
cd evals && npm run eval
```

**View results:** Braintrust dashboard, project "sous"

Evals test LLM behavior against the real system prompts — things like: does the model correctly refuse to patch a done step, does it respect dietary preferences, does it route ambiguous requests correctly. They run via Braintrust and are written as JSON cases in `/evals/cases/core-behaviors.json`.

## Local development

### Skipping Sign in with Apple

Debug builds can bypass Sign in with Apple, which is useful on a fresh simulator
(erasing a simulator clears the Keychain and the stored session with it).

This requires a backend running with the dev bypass enabled — set
`BYPASS_APPLE_VERIFY=true` with `NODE_ENV` set to anything other than
`production`. The bypass is hard-disabled in production and must stay that way:
enabling it on a public deployment would let anyone mint a session for any
account by POSTing a username. Against the production backend the bypass fails
with the normal 401, and the app shows "Sign in failed."

With such a backend running, the supplied token is treated as the Apple `sub`
verbatim, so varying the handle yields distinct test users (`<handle>@example.test`).

**By hand:** the Debug sign-in screen shows a handle field and a
"Skip sign-in (Debug)" button below the Apple button. The handle persists
across launches.

**Unattended** (simulator automation, UI tests) — either:
```
SOUS_DEV_SIGNIN=alice
```
```
-sous-dev-signin alice
```
Auto sign-in only runs when the app is already signed out, so an existing
session is never disturbed.

All of this is wrapped in `#if DEBUG` and is absent from Release builds. See
`ios/SousApp/SousApp/Debug/DebugSignIn.swift` and `backend/src/lib/apple.ts`.

## Docs

Project documentation lives in `/docs`: PRD, milestones, state model, design spec,
user stories, and codebase overview.
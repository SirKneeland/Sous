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

## Docs

Project documentation lives in `/docs`: PRD, milestones, state model, design spec, 
user stories, and codebase overview.
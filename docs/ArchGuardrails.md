

# Sous — Architecture Guardrails

This document defines the **non-negotiable invariants** of the Sous system architecture.

These rules exist to protect deterministic behavior when integrating an unreliable component (the LLM).

Any change that risks violating these rules must be treated as a **critical architecture review point**.

---

# Core Philosophy

Sous is **deterministic state machinery first**.

The system layers are:

LLM → PatchSet → PatchValidator → PatchApplier → Recipe State → UI

Each layer has a strict responsibility:

- **LLM**: Suggests possible edits.
- **PatchSet**: Structured description of proposed edits.
- **PatchValidator**: Verifies safety and correctness.
- **PatchApplier**: Applies validated edits atomically.
- **Recipe State**: Canonical source of truth.
- **UI**: Projection of canonical state.

The LLM must **never directly mutate recipe state**.

---

# Recipe State Invariants

1. The recipe canvas is the **single source of truth**.

2. Recipe state may mutate **only through PatchApplier**.

3. All patch applications must pass through **PatchValidator**.

4. Recipe state must be **versioned**.

5. Every PatchSet must include:

- `baseRecipeId`
- `baseRecipeVersion`

6. PatchSets targeting a stale version must be rejected.

7. Recipe mutation must be **atomic**.

Partial patch application is forbidden.

---

# Patch Proposal Rules

1. The assistant proposes edits **only via PatchSet**.

2. Once a recipe canvas exists, the assistant must **never output a full recipe**.

3. Only **one pending PatchSet** may exist at a time.

4. PatchSets must be explicitly **Accepted** or **Rejected** by the user.

5. PatchSets may **never auto-apply**.

6. Patch proposals must never modify **completed (`done`) steps**.

---

# Safety Invariant: No Mutation Before Accept

The most important invariant in Sous:

**Recipe state must never change until the user explicitly accepts a PatchSet.**

System flow:

User message

↓

LLM generates response

↓

PatchSet proposed

↓

Patch validated

↓

User reviews diff

↓

User accepts

↓

PatchApplier mutates recipe state

Any mutation before Accept is a **critical bug**.

---

# Message‑Only LLM Responses

The LLM may return a **message-only response**.

This occurs when clarification is needed or when no recipe change is required.

These responses are represented as:

`LLMResult.noPatches`

Rules:

- Message-only responses must **never mutate recipe state**.
- They must **not create a pending PatchSet**.
- They must **not block future user messages**.

---

# Patch Expiration Rules

A PatchSet must be rejected if:

- `baseRecipeVersion` does not match current recipe version
- `baseRecipeId` does not match

These conditions produce:

- `ExpiredPatch`
- `RecipeIdMismatch`

Expired patches must **never mutate recipe state**.

---

# State Machine Guardrails

The AppStore state machine must enforce:

- Only one pending patch
- No mutation outside Accept flow
- Rejected patches fully cleared
- Expired patches discarded

Transitions must remain explicit.

Implicit state mutation is forbidden.

---

# LLM Integration Rules

The LLM is treated as **an unreliable component**.

Therefore the system must assume:

- malformed JSON
- missing fields
- incorrect patch structures
- hallucinated IDs

Protection layers:

1. Strict JSON decoding
2. Patch validation
3. Self-repair attempts
4. Retry policy
5. Fallback behavior

At no point may the LLM bypass the patch validation boundary.

---

# Testing Requirements

The following invariants must always be covered by tests:

- No mutation before Accept
- Reject does not mutate state
- Expired patches do not mutate state
- RecipeId mismatch does not mutate state
- Done steps are immutable
- Patch application is atomic

Breaking any of these tests indicates a **system safety regression**.

---

# LLM System Prompt Guardrail

Any change to the LLM system prompts (in `OpenAILLMOrchestrator.swift`) must be accompanied by:

1. A corresponding eval case added to `/evals/cases/core-behaviors.json`
2. A passing eval run (`cd evals && npm run eval`) before the change is considered complete

A system prompt change without a green eval run is **not done**.

---

# When Modifying the Architecture

Before changing any code touching:

- PatchValidator
- PatchApplier
- AppStore state transitions
- LLM orchestration

You must verify:

1. No mutation occurs before Accept
2. Patch validation still guards all mutation
3. Version mismatches are rejected
4. Done-step immutability is preserved

If any invariant becomes uncertain, stop and investigate.

---

# Summary

Sous is designed around a simple principle:

**The LLM suggests. The user decides. The system mutates state safely.**

The patch system is the safety boundary that makes this possible.

Protect it carefully.
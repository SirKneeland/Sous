# Known Issues

Running log of deferred bugs, flaky tests, and cleanup items. Add an entry any time a task flags something without fixing it. This is not a roadmap — no feature ideas here.

---

## VoiceTests.test_error_decodesWithPayload fails

- **Area:** `ios/SousCore/Sources/SousCore/` — WIP Voice / RealtimeAPITypes.swift
- **Type:** Pre-existing bug
- **Flagged:** 2026-06-08

The error-event decoder in `RealtimeAPITypes.swift` reads from a nested `error` container, but the test feeds flat JSON. The test fails as written. Deferred until the real Realtime API error-event shape is confirmed and the Voice feature moves out of WIP status. Do not delete the test — it documents the intended decode contract.

---

## AppStoreTests.test_cancellation_preventsStateUpdates is flaky

- **Area:** `ios/SousApp/SousAppTests/AppStoreTests.swift`
- **Type:** Flaky test
- **Flagged:** 2026-06-08

Timing-sensitive test that fails occasionally in parallel CI runs but passes reliably in isolation. Root cause is the `drainMain()` yield count being insufficient when async hops are added to the send path. Known fix: bump the yield count in `drainMain()` (currently ≥10 after M18 streaming hops). If `sendWithLLM` gains additional suspension points in a future milestone, bump again. Candidate for replacement with a deterministic wait mechanism.

---

## Unused UIStateMachine transition: recipeOnly + patchReceived → patchProposed

- **Area:** `ios/SousApp/SousApp/UIStateMachine/UIStateMachine.swift`
- **Type:** Cleanup
- **Flagged:** 2026-06-08

This transition was left in place during unit-conversion work to avoid touching patch review code. It is now unreachable: the import flow bypasses patch review entirely by calling `PatchApplier.apply()` directly and setting `uiState = .recipeOnly` inline. The transition is dead code. Safe to remove in a housekeeping pass, but doing so requires verifying no other call site fires `patchReceived` from a `recipeOnly` state.

---

## PhotoSendCoordinator: userPrefs and nextLLMContext not wired

- **Area:** `ios/SousApp/SousApp/Attachment/PhotoSendCoordinator.swift:139–140`
- **Type:** Cleanup / incomplete wiring
- **Flagged:** 2026-06-08

Two `// TODO: Prompt 5` comments mark hardcoded stubs: `userPrefs` is always an empty `LLMUserPrefs(hardAvoids: [])` and `nextLLMContext` is always `nil` in the multimodal path. This means user preferences (hard avoids, serving size, etc.) and cross-turn rejection context are silently dropped for photo-based requests. Deferred during multimodal wiring; should be connected at the same time user prefs are plumbed more broadly.

---

## Memory proposal toast z-order vs. scroll-reveal nav bar (regressed twice)

- **Area:** `ios/SousApp/SousApp/Views/ChatSheetView.swift` — `transcript` / `mainChatView`
- **Type:** Recurring visual bug — check manually after any chat sheet view hierarchy refactor
- **Flagged:** 2026-06-11

The memory proposal toast has clipped behind the scroll-reveal nav bar gradient twice. Root cause each time: declaration order in the overlay chain. The fix is that the toast overlay must be declared **after** the nav bar overlay, and both must be in the same stacking context. Currently, the nav gradient overlay sits on the `ScrollViewReader` returned by `transcript`, and the toast overlay follows it on the same view — ensuring the toast renders on top. If the chat sheet view hierarchy is ever restructured, verify this order is preserved.

No UI test coverage exists for this. After any refactor of `ChatSheetView`, manually trigger a memory proposal and confirm the "REMEMBERING THIS" header is fully visible with no clipping from the gradient.

---

## OpenAIClient: json_schema response format not wired

- **Area:** `ios/SousApp/SousApp/Networking/OpenAIClient.swift:76`
- **Type:** Cleanup
- **Flagged:** 2026-06-08

A `// TODO` marks the response format field as stubbed — `json_schema(name:)` is not yet wired because the full schema definition was not available at the time. Currently falls back to unstructured JSON output, which works because the two-pass decoder handles malformed output. Low urgency but worth formalizing when the schema stabilizes.

---

## Eval suite: `patch-removes-ingredient` is prompt-sensitive

- **Area:** `evals/cases/core-behaviors.json`, `evals/run.ts`
- **Type:** Flaky eval / prompt fragility
- **Flagged:** 2026-09-07 (updated same day)

While adding the mise en place patch operations, `patch-removes-ingredient` and
`patch-rescales-servings` were measured repeatedly under identical and
near-identical prompts. Both sat on a knife edge: the model sometimes answers with a
clarifying question instead of a patchSet ("which substitute do you want?", "what does
it currently serve?"), which scores 0 on `schemaScorer`.

`patch-rescales-servings` has since been rewritten and is stable (10/10 runs). Its root
cause was concrete: the case declared `servings: 4` but neither the eval runner nor
`OpenAILLMOrchestrator` serialised the recipe's own yield into RECIPE CONTEXT, so the
model never saw it and asking "what does it currently serve?" was reasonable. Both now
emit a `servings:` line, and the case uses a dish that scales cleanly (sheet-pan thighs
rather than one whole chicken, which forced a "second bird or bigger bird?" judgement).

`patch-removes-ingredient` remains mildly flaky (roughly 4 of 5 runs pass) — the model
occasionally asks which substitute the user wants instead of picking one. If it becomes
noisy enough to obscure real regressions, the same treatment applies: remove the
ambiguity from the case rather than lean harder on the prompt.

Two lessons from that investigation, worth keeping for future prompt work:

1. Anything added inside the numbered RULES list competes with rule 7 ("emit patchSet
   when the user's message implies a recipe change") and can suppress patching
   suite-wide. Prefer the tail of the prompt for narrow, conditional guidance.
2. A context line reporting an *absent* section ("miseEnPlace: none …") also suppressed
   patching, apparently by drawing attention to what the context lacks. RECIPE CONTEXT
   now omits the mise en place line entirely when there is no section, matching how
   `notes` is handled.

Run-to-run variance on the suite as a whole is roughly ±5 points on `schemaScorer` even
with an unchanged prompt. Judge one prompt change against several runs, not one.

---

## Eval prompts in `evals/run.ts` have drifted from `OpenAILLMOrchestrator.swift`

- **Area:** `evals/run.ts`
- **Type:** Maintenance
- **Flagged:** 2026-09-07

`SYSTEM_PROMPT_HAS_CANVAS` in the eval runner is a hand-copied mirror of the Swift
prompt and is now several changes behind: it still lists `add_substep` /
`update_substep` / `complete_substep` / `add_note` instead of the current step-tree and
note-section operations, and it still asks for third-person `proposed_memory` while the
Swift prompt (and the `proposed-memory-second-person` case) require second person —
which is why that case fails on both the current and the pre-change prompt. The mise en
place work mirrored only its own additions rather than resyncing the whole prompt, to
avoid moving many cases at once. A deliberate resync pass is worth scheduling.

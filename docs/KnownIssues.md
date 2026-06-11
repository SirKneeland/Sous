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

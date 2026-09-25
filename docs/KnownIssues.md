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

## AppStoreTests.test_noPatches_doesNotBlockFutureSends is flaky

- **Area:** `ios/SousApp/SousAppTests/AppStoreTests.swift`
- **Type:** Flaky test
- **Flagged:** 2026-09-20

Failed once in a full `xcodebuild test` run while landing the in-app bug report sheet,
then passed in isolation and on a re-run of the full suite. That change does not touch
the `AppStore` send path, so this is the same `drainMain()` timing sensitivity as
`test_cancellation_preventsStateUpdates` above, surfacing in a second test. Same known
fix applies; the better fix is replacing `drainMain()`'s fixed yield count with a
deterministic wait, which would retire both entries at once.

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

---

## Import diagnostic export captures OCR text but not the source photo

- **Area:** `ios/SousApp/SousApp/Debug/ImportDebugRecord.swift`, `ios/SousApp/SousApp/Debug/DebugDiagnosticExport.swift`
- **Type:** Deferred improvement
- **Flagged:** 2026-09-20

Section 7 of the 5-tap diagnostic export ("Last Import Attempt") records the OCR text read
from a photo import, plus the photo's pixel dimensions and approximate JPEG byte size — but
not the photo itself. That is enough to tell what Vision *read*, and not enough to tell why
it read it wrongly: a blurry, cropped, skewed, or badly-lit page produces plausible-looking
OCR text with no indication that the image was the problem.

Deferred deliberately on 2026-09-20 to keep the first version small. The agreed shape when
it is picked up: do **not** embed the image in the Markdown (it bloats the file and makes it
unpasteable). Instead pass two items to the share sheet — the `.md` file and a JPEG of the
source photo — so the photo travels alongside the dump and can be dropped from the share when
it isn't wanted. `ImportDebugRecord` would need to retain the `UIImage` (or encoded JPEG
data) rather than only its description, and `DebugDiagnosticExporter.export()` would need to
write the second file and add it to `activityItems`. Debug builds only, as now.

---

## Buttons are hand-built on every screen — no shared SwiftUI button

- **Area:** `ios/SousApp/SousApp/` — ~40 call sites across Views, Billing, Import
- **Type:** Cleanup / consistency
- **Flagged:** 2026-09-20 (surfaced while building the Figma Button component)

There is no shared button view. Each screen assembles its own from `Font.sousButton`
plus ad-hoc padding, fills and borders, which has produced five styles and three
inconsistencies. The Figma **Button** component is the agreed target shape: Primary
(burgundy fill), Inverse (ink fill, flips in dark mode), Secondary (ink border),
Secondary Accent (burgundy border), Text (burgundy label only).

Two of the three inconsistencies were fixed on **2026-09-24**, ahead of the extraction,
because they were visible defects rather than structural debt:

1. ~~**Label colour on burgundy.**~~ Fixed. START (`AdjustTimerSheet`,
   `DurationPickerSheet`), SET (`ServingsPickerSheet`) and the generate pill
   (`ChatSheetView`) now use `Color.white` (`text/onInverse`) instead of the flipping
   background colour that turned the label near-black in dark mode. A fifth site this
   entry had missed — the **OG badge** in `SettingsView` — had the same defect and was
   fixed with it; at 11pt it measured 3.89:1 in dark mode, and the Figma **Badge**
   component already specified `text/onInverse`.
2. ~~**ALL CAPS rule.**~~ Fixed. "Make this recipe" → "MAKE THIS RECIPE", "Reset Recipe" →
   "RESET RECIPE", "Restore Original Recipe" → "RESTORE ORIGINAL RECIPE".
3. **Letter-spacing — still open.** Roughly 35 buttons use none; four add `kerning` 0.5 or
   1.2 (`CapReachedView.swift:87` and `:100`, `PaywallView.swift:115`,
   `SettingsView.swift:183`). The token — and the Figma component — use none. Left for the
   extraction itself, since all four sit on screens being redesigned against the system
   (paywall, cap reached) and the kerning should come off as those screens are rebuilt.

The extraction itself — one shared button view — is still outstanding.

Also note only Inverse and Secondary have a disabled appearance in code; Primary,
Secondary Accent and Text have none, so the Figma component deliberately omits them.

---

## ~~The same checklist row is implemented three times~~ — done 2026-09-24

- **Area:** `ios/SousApp/SousApp/Views/RecipeCanvasView.swift`,
  `ios/SousApp/SousApp/Views/SousChecklistRow.swift`
- **Type:** Cleanup / consistency — **resolved**

`SousChecklistRow` and `SousChecklistText` now carry the shared part: the checkbox nudged
2pt down, 12pt from `sousBody` text that mutes and strikes when done and bolds when
current. Five call sites use them (ingredients, leaf steps, mise en place solo, group
header and component). Verified as a pixel-for-pixel no-op on the canvas — 0 of 3,017,412
pixels changed.

**The extraction is deliberately narrower than this entry originally proposed.** Only the
*appearance* is shared. Swipe actions, list-row insets, the timer-highlight fill and the
drain-and-collapse animation genuinely differ per section and stayed at the call sites;
folding them in would have meant one view with about a dozen flags, which is harder to
read than the callers it replaced. The rows agree on how they look and disagree on how
they behave, and only the first half is worth centralising.

**The indent mismatch was mis-diagnosed here.** The original note compared *declared*
values — 16pt per level for sub-steps, 20pt for nested prep tasks. The rendered gap was
bigger: the prep task's indent was a spacer *inside* the row's `HStack`, so it also picked
up the 12pt item spacing, putting its checkbox at 52pt against the sub-step's 36pt. Making
both declare 20 would have left them 12pt apart. `SousChecklistRow` applies the indent as
leading padding instead, and both now measure 39.7pt on device against 19.7pt for a
top-level row.

Group header letter-spacing is fixed too: the ingredient group header now uses `kerning(1.2)`
like every other header.

---

## No destructive colour token; voice bar uses raw white-opacity literals

- **Area:** `ios/SousApp/SousApp/Views/AdjustTimerSheet.swift:158`, `Voice/VoiceBarView.swift`
- **Type:** Cleanup
- **Flagged:** 2026-09-20

"Delete Timer" is drawn with SwiftUI's system red at 80% opacity. Sous has no red in
its palette, so there is nothing in `design/tokens.json` for it, and
`design/check-tokens.py` does not catch it — the check only rejects hand-built hex
values, not system colours. Decide on a `status/destructive` token when a second
destructive action appears (account deletion is the likely trigger).

The voice bar similarly uses `Color.white.opacity(0.08 / 0.15 / 0.2)` directly for its
button fills, borders and waveform. Only the 0.2 border is tokenised
(`voice/exitBorder`); the rest are literals.

---

## Dark-mode contrast on burgundy buttons is 4.47:1, just under AA

- **Area:** `ios/SousApp/SousApp/Views/SousTheme.swift` — `sousTerracotta` dark value
- **Type:** Accessibility
- **Flagged:** 2026-09-20

White on the dark-mode burgundy (`#C45068`) measures 4.47:1, marginally below the
4.5:1 WCAG AA threshold for normal text; 14pt semibold does not qualify as large text.
It is still the best of the options — cream is 3.88:1 and the near-black alternative
3.89:1 — so white was chosen deliberately. Fixing it properly means lightening the
dark-mode burgundy, which changes the nav bar, CTAs and voice bar together. Worth a
deliberate pass rather than a spot fix.

Disabled filled buttons (cream on `#9A9590`) sit at about 2.6:1. WCAG exempts disabled
controls, so this is recorded for awareness, not as a defect.


---

## The SOUS wordmark is set at four different trackings

- **Area:** `ios/SousApp/SousApp/` — `HistoryDrawer.swift:51`, `ChatSheetView.swift:105`,
  `ContentView.swift:94`, `Auth/SignInView.swift:28`, `Billing/PaywallView.swift:70`
- **Type:** Cleanup / consistency
- **Flagged:** 2026-09-24 (surfaced while building the Figma Sign In and Paywall screens)

The app draws its own name five times, at three different letter-spacings:

| Where | Kerning |
|---|---|
| History drawer header | none |
| Chat blank state | none |
| Loading state (`ContentView`) | 2 |
| Sign in | 2 |
| Paywall | 3 |

The Figma **Wordmark** component uses none, matching the two oldest sites, and the Sign In and
Paywall screens were built from it — so those two screens currently show less tracking than the
code does. Nothing is broken; the logotype is just inconsistent in a way you notice when the
screens sit side by side.

Picking a value is a design decision, not a reconciliation, so it was left alone. Worth settling
in one pass: choose one tracking, put it in the Wordmark component, and make all five sites use
it. At 34pt bold serif in capitals a little tracking usually reads better, so 2 is the likelier
answer than 0 — but that is a judgement to make by looking, not by argument.

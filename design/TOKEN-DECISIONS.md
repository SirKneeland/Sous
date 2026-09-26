# Token Reconciliation — Decisions Needed

**Status:** awaiting sign-off. Nothing in the app has been changed.
**Companion file:** `design/tokens.json` — the proposed single source of truth.

Sous currently keeps design decisions in three places that disagree: `docs/DesignSpec.md`
(the intent), `SousTheme.swift` (the shipped values), and individual view files (values that
never became tokens). This document resolves every disagreement so `tokens.json` can become
the one true source.

**Default rule used below:** where the spec and the code disagree on a value, **the code
wins** — those are the pixels that shipped and were approved on a real device, whereas the
spec numbers were never verified against the build. Exceptions are called out.

---

## Part 1 — Conflicts to sign off

### 1. Cream (primary background) — *invisible difference*

| | Value |
|---|---|
| DesignSpec.md says | `#F5F0E8` |
| App actually renders | `#F2EFE9` |

**Recommendation: keep `#F2EFE9`.** The difference is about 1% brightness — not perceptible
side by side. The code value appears in three places in the app; the spec value appears in
zero. Changing the spec is free; changing the app means re-approving every screen.

---

### 2. Ink (primary text and strong borders) — *invisible difference*

| | Value |
|---|---|
| DesignSpec.md says | `#1A1A18` (very slightly warm black) |
| App actually renders | `#1A1A1A` (neutral black) |

**Recommendation: keep `#1A1A1A`.** Worth noting the spec's version is intentional — a warm
black that fits the "warmth earned through color" principle. But the difference is 2 units on
one channel out of 255. Invisible. Not worth a code change.

---

### 3. Separator (divider lines) — *invisible difference*

| | Value |
|---|---|
| DesignSpec.md says | `#D5CFC6` |
| App actually renders | `#D0CBC3` |

**Recommendation: keep `#D0CBC3`.** Same reasoning as above.

---

### 4. Caption size and casing — *visible difference*

| | Value |
|---|---|
| DesignSpec.md says | 12pt, ALL CAPS |
| App actually renders | 11pt, sentence case, no letter-spacing |

**Recommendation: keep 11pt sentence case, and fix the spec.** The all-caps caption rule was
never implemented anywhere, and applying it now would change every timestamp and revision
number in the app. If you *want* all-caps timestamps, that's a design change to schedule, not
a reconciliation.

---

### 5. Section header weight — *barely visible*

| | Value |
|---|---|
| DesignSpec.md says | Medium |
| App actually renders | Semibold |

**Recommendation: keep Semibold.** At 11pt all-caps, semibold is the more legible of the two,
and it is what every section header in the app already uses.

---

### 6. Recipe title weight — ⚠️ *clearly visible, your call*

| | Value |
|---|---|
| DesignSpec.md says | Semibold |
| App actually renders | Bold |

**This one you can actually see.** At 28pt in a serif face, bold versus semibold is a real
difference in how heavy the recipe title feels at the top of the canvas.

**Recommendation: keep Bold**, because it ships today — but this is the one color/type conflict
where I'd want you to look at a screen before deciding. Semibold would read as more refined and
less shouty; bold reads as more confident. Say the word and I'll flip it.

---

### 7. Voice bar background — ⚠️ *visible, and structural*

| | Value |
|---|---|
| DesignSpec.md says | Fixed deep burgundy `#712B13` in both light and dark mode |
| App actually renders | Brand burgundy — `#8B2E3F` in light mode, `#C45068` in dark mode |

This is not just a different color, it is a different *behavior*. The spec wants the voice bar
to be one fixed color always. The code has it follow the app's light/dark setting.

**Recommendation: keep the code's behavior** (brand burgundy, mode-aware). It keeps the voice
bar visually part of the same app as the nav bar, and it means one fewer color to maintain.
The spec's `#712B13` is a deeper, browner red that exists nowhere in the build.

---

### 8. Monospace font — ⚠️ *the spec is being violated 18 times*

`docs/DesignSpec.md` says, twice and emphatically: never use a monospaced font anywhere.
The app uses one in **18 places**:

| Where | What |
|---|---|
| [AdjustTimerSheet.swift](ios/SousApp/SousApp/Views/AdjustTimerSheet.swift) | Countdown readout, hour/minute pickers |
| [DurationPickerSheet.swift](ios/SousApp/SousApp/Views/DurationPickerSheet.swift) | Duration digits |
| [ServingsPickerSheet.swift](ios/SousApp/SousApp/Views/ServingsPickerSheet.swift) | Servings digits |
| [TimerBannerStack.swift](ios/SousApp/SousApp/Views/TimerBannerStack.swift) | Running timer banner |
| [TimerDoneBanner.swift](ios/SousApp/SousApp/Views/TimerDoneBanner.swift) | Timer-complete readout |
| [RecipeCanvasView.swift:889](ios/SousApp/SousApp/Views/RecipeCanvasView.swift:889) | Inline timer affordances |
| [VoiceBarView.swift](ios/SousApp/SousApp/Voice/VoiceBarView.swift) | State labels — "ready", "listening", "speaking" |

There is a good reason for most of these: in a monospaced font every digit is the same width,
so a countdown ticking from 9:59 to 10:00 doesn't make the text jump around. That is a genuine
functional need, not a style slip.

**Recommendation: amend the spec to permit monospace in exactly two named roles** —
*numeric readouts* (timers, durations, servings) and *voice bar state labels* — and keep the
ban everywhere else. This legitimises what's already shipping and still blocks mono from
leaking into body text.

The voice bar labels are the weaker case, since "listening" isn't a number. If you'd rather
those move to SF Pro, that's a small, contained change.

---

### 9. Colors the spec invented that don't exist

`docs/DesignSpec.md` names a "burgundy secondary" family — fill `#D4929E`, border `#BA6E7A`,
text `#5C1522`, plus three dark-mode counterparts. **None of these appear anywhere in the
app.** The spec also states that section headers on the recipe canvas use `#5C1522`; they
actually use brand burgundy.

**Recommendation: delete them from the spec.** They describe an app that was never built. If
the intent was a lighter burgundy for step numbers inside highlighted rows, that's a feature
to design, not a token to reconcile.

---

## Part 2 — Audit: values that need to become tokens

These are real colors sitting in view files instead of the theme. No decision needed — they
just need to move. Listed so you can see the size of the job.

| File | Line | What's hardcoded | Becomes |
|---|---|---|---|
| [SousAppApp.swift](ios/SousApp/SousApp/SousAppApp.swift:44) | 44–58 | Cream, ink, and separator re-typed for the UIKit nav bar | `background.canvas`, `text.primary`, `border.subtle` |
| [TimerAffordanceText.swift](ios/SousApp/SousApp/Views/TimerAffordanceText.swift:125) | 125–134 | Ink and burgundy re-typed a third time | `text.primary`, `accent.primary` |
| [VoiceBarView.swift](ios/SousApp/SousApp/Voice/VoiceBarView.swift:7) | 7–9 | The entire voice palette, defined privately | `voice.labelBright`, `voice.labelSpeaking`, `voice.labelWarm` |
| [ChatSheetView.swift](ios/SousApp/SousApp/Views/ChatSheetView.swift:217) | 217 | `#757471` photo-sheet backdrop | `background.scrim` |
| [HistoryDrawer.swift](ios/SousApp/SousApp/Views/HistoryDrawer.swift:64) | 64 | `#1A1A1A` settings button fill | `background.surfaceInverse` |

One file is deliberately excluded: [TexturePreviewView.swift:30](ios/SousApp/SousApp/Views/TexturePreviewView.swift:30)
builds colors from live slider values. That's a developer tool for tuning the paper texture, not
product UI — it should keep its raw values.

**Good news from the audit.** Two things are already perfectly consistent and need no work:
every border in the app is 1pt (36 uses, zero exceptions), and corner radius is used only
three times in the entire codebase. The square, bordered, shadowless language in the spec is
genuinely what shipped.

---

## Part 3 — Scale consolidation (done, 2026-09-20)

Reconciliation fixed the values; this pass fixed the scales. A scan of all 64
`.system(size:)` declarations found they were three unrelated things, not one type scale:

| Kind | Sites | Outcome |
|---|---|---|
| Icon sizing (SF Symbols) | 35 | Consolidated from 11 sizes to 5 |
| Monospace | 19 | Named as 7 roles; **no value changed** |
| Design tokens already | 6 | Kept |
| Inline non-mono text | 4 | Named as tokens; one moved 1pt |

**Correction to an earlier claim in this file.** An earlier draft reported "15 distinct font
sizes" as type-scale sprawl. That figure conflated icon sizing with typography and overstated
the problem — only 4 of the 64 sites were ordinary inline text.

### 10. Monospace kept at every existing size

The 19 mono sites span 32 / 24 / 22 / 15 / 14 / 13pt, and each size does a distinct job — a
countdown has to read across a kitchen, a wheel label must not compete with the digits it
labels. They became seven named tokens (`sousReadoutLarge`, `sousReadout`, `sousPickerValue`,
`sousPickerLabel`, `sousTimerBanner`, `sousVoiceLabel`, `sousVoiceButton`) with **no value
changed**. Consolidating them would have made timers harder to read to make a table tidier.

### 11. Two monospace uses did not qualify and were changed

Decision 8 permits monospace only in numeric readouts and voice bar state labels. Two uses
failed that test:

- **"Delete Timer"** in the adjust-timer sheet was 13pt mono. It's a button label, not a
  readout. Now `sousButtonQuiet` — SF Pro at the same 13pt regular, so it stays as
  de-emphasised as the code comment intends.
- **Two canvas icons** carried `design: .monospaced`, which SF Symbols ignore entirely. The
  modifier was dead code and is gone.

### 12. Icon scale: eleven sizes to five

`SousIconSize` is now `small 11 / medium 14 / large 16 / xLarge 22 / huge 32`, chosen from the
sizes already most common so the fewest icons move. **13 of 35 sites changed, none by more
than 2pt.** The two 2pt movers are the mic button and the onboarding arrow (18pt → 16pt), and
the import mode icon (20pt → 22pt).

Icons are applied with `Font.sousIcon(.medium, weight: .semibold)`.

---

### 13. Spacing stays as it is, and converges opportunistically

20 distinct padding values remain in the app. **No sweep will be done.** Unlike a font size,
changing padding moves layout — it reflows rows, shifts what fits above the fold, and can push
content under a nav bar — so a bulk migration would mean re-verifying every screen for a
tidiness win.

The 8-step scale in `tokens.json` is therefore marked **`advisory`**, not `proposed` or
`shipped`. The rule is opportunistic: **when you touch a view's spacing for any other reason,
snap the values you touch to the nearest step.** Leave the rest alone. Over a few milestones of
normal UI work the odd values (2, 6, 10, 13, 14, 18) disappear on their own, with each change
verified as part of the work that prompted it.

The scale is `4 / 8 / 12 / 16 / 20 / 24 / 32 / 40`, where 20pt is the content gutter — already
the app's dominant rhythm at 52 uses.

The check script deliberately does **not** enforce spacing. Adding that check would fail the
build on every untouched view and turn an advisory into a blocker.

---

## Design system: state of play

Components live in `design/figma-components.js`, built by the local plugin (`figma/`) and
verified by `node design/test-figma-plugin.js`. Every screen below is assembled only from
components — if a screen can't be built from them, the components are wrong.

**Built:** Checkbox, Button, Icon Button, Section Header, Ingredient Group Header, List Row,
Recipe Title, Bottom Bar, Chat Bubble, Composer Bar, Chat Header, Wordmark, Recent Recipe Row,
Apple Sign In Button, Benefit Row, Picker Sheet.

**Screens assembled:** Recipe Canvas, Chat, Zero State, Sidebar.

**Screens: twelve built** — Recipe Canvas, Chat, Zero State, Sidebar, Settings,
Change Suggestion, Voice Mode, Talk to a Recipe, Preferences, **Sign In**, **Paywall**,
**Cap Reached**.

### 14. Apple's sign-in button is square, and its mark is not redrawn (2026-09-24)

**Square.** `ASAuthorizationAppleIDButton` exposes `cornerRadius` as a public, documented
property — *"Set a custom corner radius to be used by this button."* So squaring it is
sanctioned by Apple, not a workaround, and the button now matches the rest of Sous. What
Apple's guidelines actually protect is the mark and the wording, and neither is touched.

SwiftUI's `SignInWithAppleButton` offers no way to set the radius, so `SignInView` wraps the
UIKit control in a small `UIViewRepresentable` (`AppleSignInButton`). Verified on device:
354 × 50pt at a 24pt gutter, all four corners filled.

This corrects an earlier draft of this decision, which claimed Apple's guidelines forbade
altering the button's proportions and specified an 8pt radius on that basis. They do not.

**The mark is still not redrawn.** Apple renders it; reproducing it in Figma would be
inaccurate. There is also a practical limit: `apple.logo` is not in `design/sf-symbols.json`,
and the desktop plugin API cannot look a symbol up by name — adding it would spend one of a
very small monthly allowance of Figma MCP calls to draw something we would not alter anyway.
The component reserves the space and states the geometry; Apple supplies the glyph.

---

**A rule worth keeping:** iOS chrome stays iOS-shaped. Sheets, segmented pickers, toggles,
steppers, the DONE pill and the back button are all rounded, and deliberately so — a square
switch reads as broken, not consistent. Everything Sous draws itself stays square. Each of
those components says so in its own notes.

**Coverage audit (2026-09-24)** — every user-facing surface in the app, and whether the
design system covers it. Done as a deliberate step: the nine screens built so far came from
the operator's list, not from a sweep of the codebase.

*Covered:* recipe canvas, chat sheet, zero state, history drawer, settings, patch review,
voice bar, import chooser, preferences, **sign in**, **paywall**, **cap reached**,
**the three wheel sheets** (one **Picker Sheet** component).

*Not yet in the library — worth a pass, roughly in order of how often a user meets them:*

| Screen / surface | Source | Why it matters |
|---|---|---|
| **Memories** | `Views/MemoriesView.swift` | Reached from Settings; a list with edit and swipe-delete |
| **Timer banners** | `TimerBannerStack`, `TimerDoneBanner` | The only monospace readouts outside the canvas |
| **Import: the other modes** | `Import/RecipeImportSheet.swift` | Camera, library, paste, loading and error states — only the chooser is built |
| **Photo acquisition** | `Acquisition/PhotoAcquisitionSheet.swift` | Camera/library picker sheet |
| **Mise en place confirmation** | `RecipeCanvasView` (modal) | Small modal, uses the Small checkbox that nothing else uses |
| **In-chat furniture** | `ChatSheetView` | Memory proposal toast, attachment strip, quoted-context chip, generate pill, thinking/streaming bubbles |
| **API key callout** | `Views/APIKeyCallout.swift` | Onboarding nudge for BYOK users |

*Deliberately out of scope:* everything under `Debug/` and `RowLayoutDebugPreview` — developer
tools, not product surfaces.

**The timer sheets did collapse (2026-09-25)**, as predicted — three sheets into one **Picker
Sheet** with a `Wheels=One / Two` variant, plus Title, Left, Right, Readout and Footer as
properties. Servings is one wheel with CANCEL · SET; a new timer is two with CANCEL · START;
adjusting a running one is two with the readout on for the live countdown, PAUSE in place of
CANCEL, and the footer on for Delete Timer.

Two things the collapse settled:

- **The bordered box is the component, not the two halves.** Both actions live inside one ink
  border split by a hairline, which is exactly why the shared SwiftUI button skipped these
  sheets. The component now says so, rather than leaving it as a note in KnownIssues.
- **Wheel labels belong to the variant, not to a property.** One wheel always counts people;
  two always count hours and minutes. If that stops being true they become properties — the
  component's own notes say so.

The in-chat furniture is the remaining cluster most likely to collapse the same way.

**Cap Reached needed no new components (2026-09-25).** It was built from the close button,
both button styles and the static section header — all of which already existed for the
Paywall. That is the coverage audit's own prediction coming true, and a useful signal: when a
screen can be assembled without inventing anything, the component set is holding. The harness
asserts it, so a future change that sneaks a new part into this screen will fail rather than
pass quietly.

**Deferred deliberately:**
- **Foundations pages** (colour swatches, type specimen, spacing bars).
- **Light/dark in one collection** — needs a paid Figma plan; the plugin merges automatically
  once modes are available.
- **Publishing the library** to other files — also needs a paid plan.
- **The paper texture** the app lays over the cream background is not reproduced in Figma.
- **The blur-and-fade strip** at the top of the blank-state transcript is not reproduced.

**App-code debt this work surfaced** is in `docs/KnownIssues.md`.

**Two extractions landed (2026-09-25)**, both driven by components built here:

- **`SousChecklistRow` / `SousChecklistText`** — the checkbox-and-text pairing behind
  ingredients, steps and mise en place. Five call sites; verified as a pixel-for-pixel no-op.
  It also settled the nesting indent, which the original note had mis-diagnosed: sub-steps and
  nested prep tasks now both sit at 39.7pt against 19.7pt for a top-level row.
- **`SousButton` / `SousButtonLabel`** — the five styles from the **Button** component, across
  13 call sites.

Both are deliberately narrower than "one view for everything". The rows share how they *look*
and differ in how they *behave* (swipe actions, list insets, the timer highlight), so only the
appearance was centralised. Paired rows inside a shared bordered container — the picker sheets,
the mise en place modal — and the split **Bottom Bar** stayed out, because the container is the
component in those cases, not the halves.

**How Figma actually behaves** — hard-won, all encoded as tests in
`design/test-figma-plugin.js`: a shared TEXT property forces one styling across every variant
bound to it; attaching one flattens per-character styling; paint-level opacity is ignored on a
variable-bound colour (tint the layer instead); an instance is named after the component set,
not the variant; a page must be loaded before its children can be read; and text layers carry
the line's leading, so a hugging layer sits high in a bar.

---

## Still open

**No destructive color token.** The "Delete Timer" button uses SwiftUI's system red at 80%
opacity. Sous has no red in its palette, and inventing one is a design decision rather than a
reconciliation, so it was left alone. The check script only catches hand-built hex values, so
it does not flag this. Worth deciding on a `status.destructive` token when billing or account
deletion needs a second one.

---

## What is enforced now

`python3 design/check-tokens.py` fails if any of these regress:

1. A color in `SousTheme.swift` no longer matches `tokens.json`.
2. A view builds a color by hand instead of using a token.
3. A view writes `.system(size:)` instead of using a type or icon token.
4. The `SousIconSize` scale no longer matches `tokens.json`.
5. A type role in `tokens.json` has no matching token in the theme.

Spacing is **not** in that list, by the decision above.

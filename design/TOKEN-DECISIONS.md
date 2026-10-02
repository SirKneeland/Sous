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

### 16. Swipe actions are documented, not drawn (2026-09-26)

Swiping a list row reveals an action, and iOS draws it: the rounded capsule, its size, its
reveal and the full-swipe threshold are all Apple's. Sous chooses three things — the tint,
the SF Symbol and the label.

So the **List Row** component records them rather than reproducing them: a note saying which
edge does what, and two colour chips for the tints. Drawing the capsules would freeze an
appearance Apple can change between releases, and they are round where everything Sous draws
is square — the same reasoning that keeps the wheel picker, the toggle and Apple's sign-in
button as they are.

| Where | Gesture | Action | Tint |
|---|---|---|---|
| Canvas rows | swipe right | Done, `checkmark` | `status/added` |
| Canvas rows | swipe left | Ask Sous, `bubble.left` | `accent/primary` |
| Memories | swipe left | Delete | the system's own red |

**This gives `status/added` a third job** — patch-diff additions, the ACCEPT button, and now
swipe-to-Done. Arguably one idea (*this is the affirmative action*) wearing three hats, but
worth watching: a colour with three meanings is on its way to having none. Not split here.

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
**the three wheel sheets** (one **Picker Sheet** component), **memories** (full and empty),
**timer banners** (one **Timer Banner** component, running and done), **import's paste,
loading and error modes** (plus a shared **Import Sheet Header** and a **Progress Bar**),
**photo acquisition** (the **Camera Overlay Button** and the failure sheet),
**the mise en place modal** (and the **Split Action Bar** it shares with the wheel sheets),
**the chat sheet's furniture in full** (**Attachment Strip** and **Quoted Context Chip**).

*Not yet in the library — worth a pass, roughly in order of how often a user meets them.*
**As of 2026-09-27 this table is empty of live work:** every row is either built or, in the
last case, deleted from the app.

| Screen / surface | Source | Why it matters |
|---|---|---|
| ~~**Timer banners**~~ | `TimerBannerStack`, `TimerDoneBanner` | **Built 2026-09-27** — see decision 17 |
| ~~**Import: the other modes**~~ | `Import/RecipeImportSheet.swift` | **Built 2026-09-27** — see decision 18 |
| ~~**Photo acquisition**~~ | `Acquisition/PhotoAcquisitionSheet.swift` | **Built 2026-09-27** — see decision 19 |
| ~~**Mise en place confirmation**~~ | `RecipeCanvasView` (modal) | **Built 2026-09-27** — see decision 20 |
| ~~**In-chat furniture**~~ | `ChatSheetView` | **Finished 2026-09-27.** The memory toast, the Chat Bubble variants and the generate pill landed earlier; the attachment strip and quoted-context chip complete it — see decision 21. |
| ~~**API key callout**~~ | *deleted* | **Dropped 2026-09-27** — the screen had not rendered since the nav-bar overhaul; orphaned code removed rather than drawn. See decision 22 |

*Deliberately out of scope:* everything under `Debug/` and `RowLayoutDebugPreview` — developer
tools, not product surfaces.

### 15. List Row generalises off the canvas — and found a gutter split (2026-09-25)

Memories was built to test whether **List Row** works away from the recipe canvas. It does:
with its Checkbox switch off, the row is a line of body text with a separator under it, which
is exactly what a memory is. No new component, no new variant.

**What it did not carry over is density.** The canvas draws its own rows and keeps them
compact — 10pt above and below the text, about 39pt a row. `MemoriesView` hands layout to
iOS, which gives a row more air: measured at **53.3pt pitch on device**. List Row now has a
**Roomy** switch that adds ~7pt either side, off by default because the canvas is where the
row mostly lives. Structure is shared; density is not, and the component says so.

**It also surfaced two list gutters.** The canvas sets its own 20pt
(`listRowInsets(EdgeInsets())` plus 20pt padding); `MemoriesView` uses a plain `List`, so it
inherits iOS's default 16pt. Measured on device: memory text and separators both start at
16pt against the canvas's 20pt.

**Settled 2026-09-26: the app moved to 20pt.** `MemoriesView` now sets
`listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))`, so its text and
separators line up with every other list. Verified on device: both now start at 20.0pt.

Both values are on the spacing scale, per decision 13's rule that spacing you touch snaps to
the nearest step. Worth knowing for anyone tuning this later: **15pt and 16pt vertical insets
both measured a 52.0pt row**, so iOS is rounding or clamping somewhere and the inset is not
the binding constraint. 16 was chosen because it is a scale step, not because it measured
differently.

The row is now 52.0pt against the 53.3 iOS had been giving it — 1.3pt tighter, and
imperceptible.

---

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
  14 call sites.
- **`SousBottomBar`** — the TALK TO SOUS / mic row, matching the **Bottom Bar** component's
  Voice Yes / Voice No variants. Pixel-identical in both states.

Both are deliberately narrower than "one view for everything". The rows share how they *look*
and differ in how they *behave* (swipe actions, list insets, the timer highlight), so only the
appearance was centralised. Paired rows inside a shared bordered container — the picker sheets,
the mise en place modal — and the split **Bottom Bar** stayed out, because the container is the
component in those cases, not the halves.

**How Figma actually behaves** — hard-won, all encoded as tests in
`design/test-figma-plugin.js`: a shared TEXT property forces one styling across every variant
bound to it; attaching one flattens per-character styling; paint-level opacity is ignored on a
variable-bound colour (tint the layer instead); an instance is named after the component set,
not the variant; a page must be loaded before its children can be read; text layers carry
the line's leading, so a hugging layer sits high in a bar; and **a component that anything
instances cannot be rebuilt, so a component built *from* another must tolerate a variant
that does not exist yet rather than throwing** — the first run of Timer Banner took the
whole import down for exactly this reason (2026-09-27), losing every component after it.

**Floats are 32-bit, so never compare them with `===` (2026-09-27).** Figma stores
opacity as a 32-bit float: write `0.2` and it reads back `0.20000000298023224`. Exact
equality only ever holds for values that happen to be exact in float32 — `0.5`, `0.25`,
`0.75` — which is why every earlier opacity check passed and the first `0.2` failed.
Checks now compare through `approx()`, and the stub rounds opacity through `Math.fround`
so the harness catches an `===` before the operator does. This was the *third* stub
fidelity gap found in one day; the pattern is that the stub was written to make the
plugin's intent pass, not to imitate Figma's constraints, and each gap surfaces as a
green suite followed by a red report.

**And a second thing the stub had wrong (2026-09-27).** A paint's own `opacity` is
ignored once its colour is bound to a variable — it reads back as 1, and the layer has to
be tinted instead. This file already said so, and the Progress Bar's track was written the
wrong way anyway; the stub carried the opacity through, so every test passed and the real
file reported `Progress Bar track is muted at 20% — 1`. The stub now drops it the way
Figma does, and re-running the old code against it reproduces that exact failure.

**And the one the stub had wrong (2026-09-27).** Removing a node in Figma marks only that
node: instances *inside* it keep `removed = false` and stay in `getInstancesAsync()`,
orphaned. Since the plugin clears the generated screens at the start of every run, the
Buttons, Icon Buttons and Badges inside them looked like live users and blocked their own
components from rebuilding — the giveaway being a report that could only name them
"unknown page". Liveness is now a walk up the parent chain to a real page, not the
`removed` flag. The test stub had been marking descendants too, which was kinder than
Figma and hid this for as long as the library was only tested against the stub.

### 17. Timer banners are one component, and their text properties are not shared (2026-09-27)

The running bar and the done panel look like two screens and are one idea: full-bleed
burgundy carrying a monospace readout. They became one **Timer Banner** component with a
Running / Done variant.

Measured on device before drawing anything, in both modes:

| | Light | Dark |
|---|---|---|
| Fill | `#8B2E3F` | `#C45068` |
| Running bar | 52.00pt tall, 20pt side gutters | same |
| Pencil | 32pt square, border `#C5969F` (white at 50%) | same geometry |
| Done panel | 300.00pt tall, content centred, 16pt between lines | same |

**Three things this settled.**

**The pencil is Icon Button, not a new component.** It is Bordered's exact geometry — a 32pt
square — on burgundy instead of cream. Icon Button gained an **On Accent** scheme rather
than the library gaining a fourth near-identical square. That scheme's border is white at
50%, deliberately left as a literal: Sous has no white-on-accent chrome token, the voice bar
has the same gap, and inventing one in Figma that the app does not have would be a lie in the
mirror. Logged in `KnownIssues.md` as one gap with three sites.

**The two variants cannot share text properties.** Running's label is `Sous/Button`; Done's
heading is `Sous/Title`. A shared TEXT property forces one styling across every variant bound
to it — already a hard-won note in this file — so the component carries **four** properties,
each bound to exactly one node, rather than two shared ones that would silently flatten the
type. The harness asserts all four, so a future tidy-up that collapses them fails.

**The stack is layout, not a component.** Up to three banners stack, newest first. That lives
on the screen, and the component's notes say so.

**On contrast.** The Done panel sets 28pt and 32pt, both comfortably large text, so the
dark-mode burgundy is fine there. The Running bar's 14pt label is the marginal 4.47:1 case —
a **second visible instance** of the open question below, not a new one. Built to the shipped
colour, and noted on the component.

### 18. Import's other modes: three screens, two components, two pickers left alone (2026-09-27)

The chooser was already built. Behind it sit five modes, and they are not five pieces of
work:

| Mode | Outcome |
|---|---|
| Paste | screen |
| Loading | screen |
| Error | screen |
| Camera | Apple's picker — documented, not drawn |
| Photo library | Apple's picker — documented, not drawn |

Camera and library are `UIImagePickerController` and `PHPicker`. Redrawing them would
freeze an appearance Apple owns, which is the same reasoning that leaves the wheel picker,
the toggle, the swipe actions and Apple's sign-in button alone. The one control Sous *does*
draw inside the viewfinder — the button that switches to the library — is its own component,
built with the photo acquisition sheet.

**Two components came out of it.**

**Import Sheet Header** is the row every mode shares: a 32pt square on the left, the title,
CANCEL in burgundy. Its back button is **Icon Button's Bordered scheme with the glyph
overridden to a chevron** — the same square the chat header uses for its gear, not a second
component. Where there is no back button, an empty 32pt square holds its place, because the
title is centred against it and would otherwise drift left.

Building it paid immediately: the already-built chooser screen had been drawing this row
inline, and now instances the component. The harness asserts it, so a future screen that
hand-rolls a header fails.

**Progress Bar** is the 2pt line on the loading screen. Measured at exactly 2.00pt, fill
`#1A1A1A` light and `#F2EFE9` dark — it is `text/primary`, so it inverts. It is
indeterminate: the fill follows a timed sequence of milestones and deliberately stops short
of full until the work finishes, so the component draws it at roughly 40% and says that is a
shape, not a value.

**The loading screen needed a debug fixture.** Reaching it for real means catching the gap
between sending a recipe and the model answering, which on a fast failure is under a second
— too short to look at, let alone check in two appearances. `-sous-fixture importLoading`
opens the sheet straight onto the crawl, using the conversion stage, which is the one path
the sheet is already designed to open into.

**Sheet geometry is measured, not guessed.** The large detent's top edge sits at **62pt**
— just below the 59pt safe area, not level with it — and the grabber is **36 x 5pt, 5pt**
below that edge, horizontally centred. Drawn at 52pt the card sat level with the status bar
and the grabber rode up into it. All four numbers are asserted on every import screen.

**The error screen confirmed its own redesign.** Seen on device, the stacked TRY AGAIN over
a bare burgundy CANCEL reads exactly as intended — the recovery path first, the way out
beneath it, and no grey-on-grey that would make a live control wear the disabled costume.

### 19. The camera overlay button is round on purpose — and always-dark surfaces need their own rules (2026-09-27)

Inside Apple's camera viewfinder, Sous draws exactly one control: the button at the bottom
left that switches to the photo library. Everything else there is Apple's, and stays a note.

**It is round, and that is the one deliberate exception to the square rule.** A square
burgundy block sitting between Apple's shutter and flip controls would read as a rendering
fault, not as Sous. This is the same instinct that keeps the wheel picker, the toggle, the
swipe capsules and Apple's sign-in button as they are — *iOS chrome stays iOS-shaped* — with
one difference: here the chrome is ours, drawn to sit convincingly among Apple's.

**Measured against Apple's own controls**, from a device photo of the real viewfinder:

| | Across | Fill |
|---|---|---|
| Ours | **50.2pt** | `#585858` |
| Apple's close button | **46.7pt** | `#1E1E1E` |

So it is **3.5pt larger than Apple's, not smaller** — the opposite of how it reads. What
makes it look different is the *fill*: ours is translucent and much lighter. If it should
sit more quietly, the lever is the opacity, not the diameter.

Figma cannot reproduce `.ultraThinMaterial`, so the component draws white at 18% — measured,
and labelled as a stand-in, the same way the paper texture and the blur-and-fade strip are
left out rather than faked.

---

**The failure sheet found a real defect, and then a second one.**

`PhotoAcquisitionSheet`'s "Could not attach image" state used no Sous type, colour or button
at all — raw system styling. `check-tokens.py` misses it because it only rejects hand-built
hex, not system defaults. Bringing it onto the tokens was the point of this surface.

Then the tokenised version was **worse than what it replaced**. Putting the Text button style
on it gave a burgundy DISMISS on a pure black sheet: **2.56:1**, well under AA. The old
`.buttonStyle(.bordered)` had been legible because iOS tints it for the surface it is on.

The cause is structural: **this sheet is always black** — it sits on Apple's camera chrome
and does not follow the app's light/dark setting — so a mode-aware token resolves to its
*light-mode* value, which is designed for cream. DISMISS is now white (21:1), matching the
voice bar, the only other always-dark surface, which has always used white labels and never
the accent.

**This is the third surface to need it**, and none of them can reach for a token:

| Surface | What it invents |
|---|---|
| Voice bar | `Color.white.opacity(0.08 / 0.15 / 0.2)` for fills, borders and waveform |
| Timer banner pencil | `Color.white.opacity(0.5)` for its border |
| Photo failure sheet | white, and white at 70%, for its labels |

Sous has no **on-dark-chrome** family, and no button style for one. Each surface picks its own
numbers. That is now a named gap rather than three separate oddities — logged in
`KnownIssues.md`, and worth settling the next time any of the three is opened up.

### 20. Split Action Bar exists, the modal uses it, and the wheel sheets cannot (2026-09-27)

Two actions in one ink-bordered box, split by a hairline — a quiet left, a committing right.
The shape appears in the three wheel sheets and in the mise en place modal, and it is the
reason both skipped the shared **Button**: the box is the component, not the halves.

**Extracting it found a defect in the modal.** Its CANCEL carried a full border *inside* the
outer border. Invisible, since both are ink — but SwiftUI centres a stroke on its path, so the
left half rendered fractionally wider than the right. The wheel sheets had always used a
proper `separator` hairline. The modal now does too.

**And a padding mismatch.** The modal was at 14pt vertical padding against the wheel sheets'
16, so the same control measured **44.33pt** in one place and **50.67pt** in another. 14 is not
on the spacing scale; 16 is. Per decision 13 — spacing you touch snaps to the nearest step —
the modal moved to 16. **Both now measure 50.67pt on device.**

**Two tones, and they are not interchangeable.** Burgundy is for an action that changes a
timer or a serving count; ink is for one that restructures the recipe. A burgundy OK on this
modal would promise something smaller than it does.

---

**The retro-fit was attempted and reverted, and the reason is a real Figma limit.**

The plan was for **Picker Sheet** to instance the new component. It cannot. Picker Sheet
exposes **Left** and **Right** as its own text properties, which is exactly what lets one
component serve all three wheel sheets (CANCEL/SET, CANCEL/START, PAUSE/START). A component
property can only be bound to a layer **inside that component**, never forwarded into a nested
instance, and the plugin API has no way to expose a nested instance's own properties. Instancing
the bar would have traded three sheets for one.

So the wheel sheets keep drawing the bar inline, the modal uses the component, and the shape is
described once. The harness asserts Picker Sheet still has Left and Right, so a future attempt
at this fails loudly rather than quietly costing the collapse.

**This is worth knowing beyond this component:** any shared sub-part that a parent needs to
re-label cannot be a nested instance in this library. It is the same wall the shared TEXT
property hit from the other side.

### 21. The chat furniture did not collapse, and that is the answer (2026-09-27)

The coverage audit called the in-chat furniture "the remaining cluster most likely to collapse
the same way" the timer sheets did. It didn't, and the reason is worth keeping.

**Attachment Strip** is three variants — Previewing, Preparing, Failed. There is a fourth
state, idle, which draws nothing, so it is not a variant; the harness asserts it never becomes
one. **Quoted Context Chip** is a single component with two text properties.

They look like they belong together — both are one-line strips above the composer — but they
answer different questions. One is about a file you attached; the other is about a row you
tapped. They share no geometry: the strip spans the full width at a 16pt gutter with a
hairline under it, the chip sits *inside* the text field with a stripe down its edge. Merging
them would have produced one component with a switch and nothing shared underneath.

**Two details worth recording:**

The chip's burgundy stripe is an **absolute overlay**, not a child of the row. As a child it
stretches the layout — which is why the Swift uses `.overlay(alignment: .leading)` rather than
an `HStack`. The component does the same and says so.

The strip's **failed state is the only place in Sous where burgundy means "error"**, and its
way out — DISMISS — is muted grey. That is the same shape as the import error screen's old
CANCEL, which was moved off grey-on-grey in September precisely because it made a live escape
wear the disabled costume. It is recorded here rather than changed, because both halves of it
belong to the open destructive-colour question below: what red means in Sous, and what an
error message should be coloured when there is no red.

---

### 22. The API key callout is deleted, not drawn (2026-09-27)

The last uncovered surface in the audit turned out not to be a surface. `APIKeyCallout` — the
arrow and burgundy tooltip pointing at the settings gear — was still in the codebase and still
compiled, but nothing constructed it. Its call site went away with the nav bar in
`6445196 BIG UI OVERHAUL`, when the gear moved into the chat sheet header, and nothing replaced
it. Also orphaned with it: a `GearButtonFrameKey` preference published from `ChatSheetView` and
read by nobody, and a `contentRoot` coordinate space that existed only to feed that preference.

Two ways to finish the library from there, and only one of them honest. Drawing the component
from the surviving code would have closed the audit with a screen no user can reach — and the
whole point of assembling screens from components is that it *tests* the components against
what ships. A component validated against dead code tests nothing.

So the code was deleted and the surface closed as not-applicable. The library now covers every
product surface that exists, which is a stronger claim than covering every surface that was
once written.

**What this consciously leaves broken:** a bring-your-own-key user gets no prompt to add their
key. That is a product gap, not a design-system gap, and it is logged in `docs/KnownIssues.md`
rather than papered over with a Figma component. If the nudge comes back it gets built fresh
against the gear's current position, and it earns a component then.

**The general rule this establishes:** when a surface in the audit cannot be reached in the
running app, the audit is out of date, not the app. Check whether the screen still ships before
drawing it — and prefer deleting dead code to enshrining it.

---

### 23. Screens sits directly under Cover (2026-09-29)

Pages landed in whatever order their builders happened to run, which left **Screens** buried
under twenty-odd component pages. That is backwards: Screens is what the library is *for* — the
assembled output — and the component pages are its parts. Anyone opening the file wants the
screens first, and had to scroll past every button variant to reach them.

The plugin now pins two positions on every run, Cover first and Screens second, and pins nothing
else. The component pages keep their existing relative order.

**Pinning only two positions is the point.** A full ordered list would have to be edited every
time a page is added, and would silently undo any page the operator dragged somewhere on purpose.
Two assertions fix the thing that was actually wrong and leave the rest alone.

Covered by two assertions in `design/test-figma-plugin.js`, inside the run-twice section — so the
reordering is proven idempotent, not just correct once. Re-ordering moves the existing page; it
never creates a second one.

**Confirmed in the real file on 2026-09-29**: the operator ran the plugin and Screens landed
directly under Cover. This mattered because the test harness runs against a stub, and page
insertion had to be added to that stub to test this at all — so the stub proved the plugin's
logic but could not prove Figma's `insertChild` behaves as documented. It does. Report: 785
checks, digest `ac5575bff515da96`, unchanged from the run before the reorder — the page-order
assertions live in the node harness, not in the plugin's own self-check, so the in-Figma report
does not mention page order at all. Worth moving into `verifyComponents()` if the order ever
regresses.

---

### 24. Sous's design system is not synced to Claude Design (2026-09-29)

Evaluated `/design-sync`, the Claude Code skill that uploads a design system to a Claude Design
project so the design agent builds with your real components. Stopped before running it. Recorded
here so nobody spends a day rediscovering why.

**The blocker is structural, not a setting.** The skill compiles an existing JavaScript component
library into a bundle and ships that — its stated core principle is *"ship what the customer
already built — the bundle is their compiled `dist/`, never a reimplementation."* It emits
`_ds_bundle.js`, per-component `.d.ts` prop contracts and `.jsx` previews.

Sous has none of the inputs: zero `.tsx`/`.jsx` files, no Storybook, no `dist/`, and no component
package — the only two `package.json` files are the eval suite and the backend API. The 164 source
files are Swift, and the component library proper lives in `design/figma-components.js`, which is
Figma's node API rather than anything bundlable.

**The escape hatch was considered and rejected.** The skill allows hand-authoring its output
layout for repos outside the converter's envelope. For Sous that means writing HTML or React
renditions of 32 components — a reimplementation, which is the thing the skill's own principle
warns against, and a third representation of the design system with nothing enforcing it. The
whole point of `check-tokens.py` is that `tokens.json` and `SousTheme.swift` cannot drift. A
hand-built third copy would have no such guard.

**What was nearly done instead, and why it is parked rather than dismissed.** The cheap half is
real: `tokens.json` is already a W3C-style token file, so exporting it as CSS custom properties is
mechanical, and it is the part that would make every Claude Design output on-brand. It is parked
only because without a component library the rest of the sync has nothing to carry, and a
tokens-only sync may not satisfy the skill's gates. If Sous ever grows a web surface — a marketing
site, a recipe share page — this is worth revisiting, and that exporter is the first step.

**`/design` itself needs none of this.** It works today without a synced system; it simply will
not know Sous's palette and type, so its output needs correcting by hand each time.

---

### 25. Every button has a pressed state, and a contrast floor decides it (2026-10-02)

Sous had no press feedback anywhere. All 63 button call sites route through
`.buttonStyle(.plain)` — the style that opts out of the system's own treatment — and nothing in
the code read `configuration.isPressed`. The one exception was `HapticOnPressStyle` on the
bottom bar: a haptic, no visual, scoped on purpose to "the one place a press is worth feeling."
Interaction state had simply never been decided.

**The rule: unfilled styles invert, filled styles shift one step.**

| Style | Resting | Pressed |
|---|---|---|
| Primary | burgundy fill, white label | fill deepens to `state/pressedAccent` |
| Inverse | ink fill (cream in dark) | fill moves toward mid-gray, `state/pressedInverse` |
| Secondary | 1pt ink border | ink fills it; label flips to the surface |
| Secondary Accent | 1pt burgundy border | burgundy fills it; label flips to white |
| Text | burgundy label only | burgundy fills it; label flips to white |

Borders do not change. A press alters a button's weight, never its shape.

**Two clauses rather than one, because an outline and a fill cannot press the same way.** An
unfilled button has somewhere obvious to go — it already names its own ink in its border or its
label, so pressing fills with it. A filled button is already inverted and has nowhere further to
go, so it steps along its own ramp instead.

**What this got wrong first, and what caught it.** The initial version was prettier and nearly
invisible. `Text` took the pale burgundy wash (`burgundy.50`) on the theory that a label-only
button wants the lightest possible treatment; `Inverse` stepped from `ink.900` to the adjacent
`ink.800`. Both read perfectly well as token names. Measured against what they replace:

- `Text` wash on the cream canvas — **1.02:1**
- `Inverse` light — **1.09:1**

Not weak affordances. No affordance. Neither would have survived a screenshot, except that a
press cannot be screenshotted: `touch_path` holds are not delivered to SwiftUI as presses, so
there was no picture to look at. The numbers found what the eye could not be shown.

So the floor is now a test. `SousButtonPressStateTests` asserts every pressed state clears
**1.25:1** against what it replaces — the resting fill for a filled style, the canvas for an
unfilled one — and that every pressed label still clears **4:1** on the fill arriving under it,
in both appearances. 1.25:1 is not an accessibility threshold; it is the point below which a
press is not visible at all. The test was confirmed to fail on the original wash before the
fix was kept.

**Costs accepted.** `Text` is used for Cancel and Reject, so those now flash burgundy while
held. A momentary fill on a destructive-adjacent control is a fair price for the alternative
being nothing at all; revisit if a `status.destructive` token ever lands (see Still open).
`Primary` clears the floor at 1.32:1 in light and 1.83:1 in dark — the narrowest of the five,
but it is a 353×52 fill rather than a label, and a CTA that flashes hard would read as a bug.

**One new primitive, two new semantic tokens.** `burgundy.800` (#6C2431) exists only as
Primary's pressed fill. `state/pressedAccent` and `state/pressedInverse` are scoped to
`FRAME_FILL`/`SHAPE_FILL` in Figma — a pressed fill never lands on type or a stroke. Everything
else reuses tokens already in the system, which is why inverting cost nothing new.

**Deliberately unanimated.** Sous has no motion tokens until Milestone 32, and inventing a
duration here would pre-empt that decision. The state snaps on and off. Revisit when motion
lands — this is one of the first things that should get a token.

**The rule was already there, hand-rolled.** RESET RECIPE on the canvas carried the comment
*"Pressed, it fills burgundy with a white label — which is Primary"* and swapped its own style
on press. That is exactly what Secondary Accent pressed now resolves to, arrived at
independently by whoever built that button. It is the only call site left un-migrated, because
its flag latches while the confirmation dialog is open rather than tracking the finger — a
different behaviour that a true press state would quietly break.

**Implementation note.** `SousButton` cannot read `configuration.isPressed` the obvious way: a
`ButtonStyle` wraps only the label, and Sous deliberately keeps fill and border *outside* the
Button so `.disabled()` dims the words instead of washing out the fill. `PressReportingStyle`
therefore renders the label untouched and mirrors the press flag into a binding the surrounding
chrome reads, writing it in `onChange` rather than during `makeBody`.

`SousButtonLabel` — the label-only half, for call sites that supply their own control — gained
an `isPressed` parameter so those can opt in, and all eight were migrated: TALK TO SOUS, TALK TO
A RECIPE, MAKE THIS RECIPE, NEW RECIPE, RESTORE ORIGINAL RECIPE, IMPORT RECIPE, SHARE SOUS WITH
A FRIEND, and the bottom bar's mic. `HapticOnPressStyle` now reports the press as well as firing
the impact, so TALK TO SOUS is felt *and* seen; the haptic itself is still the bottom bar's
alone.


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

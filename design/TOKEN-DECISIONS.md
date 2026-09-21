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

## Part 3 — Queued for step 2 (not decisions, just visibility)

Reconciliation doesn't fix scale sprawl. Two numbers to be aware of:

- **Type:** 6 named font tokens, but **15 distinct font sizes** in use — 10, 11, 12, 13, 14,
  15, 16, 17, 18, 20, 22, 24, 28, 32, 34. Most inline sizes were picked one screen at a time.
- **Spacing:** **20 distinct padding values**. The dominant one (20pt) is used 52 times and
  matches the spec's margin rule, so the underlying rhythm is real — it's the odd values
  (2, 6, 10, 13, 14, 18) that are freelancing.

`tokens.json` marks the proposed 8-step spacing scale as `proposed`, not `shipped`, so nothing
claims to be enforced that isn't.

---

## What happens once you sign off

1. Conflicts above get resolved into `tokens.json` (mostly already reflected — only items 6, 7
   and 8 are genuinely open).
2. `docs/DesignSpec.md` gets corrected so it describes the real app.
3. The five files in Part 2 get their hardcoded colors swapped for tokens.
4. A test asserts `SousTheme.swift` matches `tokens.json`, so they can never drift again.
5. Only then does Figma work start — against a source of truth that's actually true.

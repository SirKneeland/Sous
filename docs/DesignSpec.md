# Sous — Design Spec

> This document is the authoritative reference for visual design decisions in Sous.
> Claude Code must apply this system consistently across all screens.
> Do not deviate toward default SwiftUI aesthetics — this design is intentional and opinionated.
>
> **Last updated:** September 2026 — reconciled against the shipped build. Every hex
> value and type role below now matches what the app actually renders.
>
> **Source of truth:** `design/tokens.json` holds the canonical palette; this document
> explains how to apply it. `SousTheme.swift` is the Swift expression of the same values,
> and `design/check-tokens.py` fails if the two ever drift. Never hardcode a color in a
> view — add a token first. Decision history lives in `design/TOKEN-DECISIONS.md`.

---

## Aesthetic Direction

**Chef's notebook meets precision tool.** Warm, readable, and utilitarian. It should feel like something a serious home cook would trust and return to — not a consumer app trying to look friendly, and not a tech product cosplaying as a cookbook.

The palette and type system must feel considered, not defaults. The design is high-contrast and structured. It earns warmth through color and texture, not through rounded corners or pastel surfaces.

---

## Typography

### Typefaces

Two fonts carry the design. A third — monospace — is permitted in exactly two roles, defined below.

- **New York** (serif) — `Font.system(size: X, design: .serif)`
  Used for recipe titles, section header display names, option card dish names, and the "Sous" wordmark on the blank state. This is the identity font — the one thing that makes the app feel handcrafted rather than system-default.

- **SF Pro** (sans, default system) — `Font.system(size: X)` or semantic sizes
  Used for everything else: body text, labels, buttons, chat bubbles, captions, input fields. Standard `Font.system(...)` without any `design:` modifier.

- **SF Mono** — `design: .monospaced`
  Permitted in **exactly two roles** and nowhere else:
  1. **Numeric readouts** — running timers, the timer-done banner, and the duration and
     servings pickers. In a monospaced face every digit is the same width, so a countdown
     ticking from 9:59 to 10:00 doesn't make the surrounding text jump.
  2. **Voice bar state labels** — "ready", "listening", "speaking", "thinking".

Never use `Font.custom(...)`, and never use monospace outside those two roles — not in body
text, ingredient rows, step text, chat messages, buttons, or captions.

### Type Scale

| Role | Font | Size | Weight | Case | Notes |
|---|---|---|---|---|---|
| Recipe title | New York | 28pt | Bold | Title case | Primary canvas heading |
| Section header label | SF Pro | 11pt | Semibold | ALL CAPS | Letter-spaced 1.2, burgundy |
| Body / ingredient row | SF Pro | ~16pt | Regular | Sentence case | Line height ~1.6 |
| Step body text | SF Pro | ~17pt | Regular | Sentence case | Line height ~1.55 |
| Chat bubble text | SF Pro | ~15–16pt | Regular | Sentence case | |
| Caption / timestamp | SF Pro | 11pt | Regular | Sentence case | Muted color |
| Button label | SF Pro | ~14pt | Medium | ALL CAPS | Letter-spaced |
| Option card dish name | New York | ~17pt | Semibold | Title case | |
| Voice bar state label | SF Pro | ~13pt | Medium | lowercase | Specific to voice mode bar |

Section labels (INGREDIENTS, STEPS, MISE EN PLACE, etc.) should remain visually distinct via ALL CAPS and letter-spacing even though they're now SF Pro.

---

## Color Palette

### Light Mode

| Name | Hex | Usage |
|---|---|---|
| Cream (background) | `#F2EFE9` | Primary background on all screens |
| Ink (text) | `#1A1A1A` | All primary text, borders |
| Muted | `#9A9590` | Captions, timestamps, done-step text, placeholders |
| Surface | `#FFFFFF` | Sheet surfaces (chat, history drawer), input fields |
| Separator | `#D0CBC3` | Thin divider lines between sections and rows |
| **Burgundy primary** | `#8B2E3F` | CTA buttons, active states, accent color |
| Burgundy secondary bg | `#F7EAEC` | Highlighted rows, user chat bubble background, tag backgrounds |
| Success / add | `#2D6A4F` | Added items in patch diff only |
| Surface inverse | `#1A1A1A` | Ink fills that stay dark in both modes — history settings button, ACCEPT CHANGES |
| Scrim | `#757471` | Backdrop behind the photo acquisition sheet |

### Dark Mode

| Name | Hex | Usage |
|---|---|---|
| Background | `#1A1A1A` | Primary background |
| Text | `#F2EFE9` | Primary text (cream) |
| **Burgundy primary** | `#C45068` | CTA buttons (lighter for legibility on dark) |
| Burgundy secondary bg | `#2C1018` | Highlighted rows (near-black with burgundy tint) |

Cream, ink, and neutral values invert in dark mode as above. The key principle: primary burgundy gets *lighter* in dark mode (not darker) so it reads as a button on a dark surface; secondary backgrounds go very dark with a burgundy tint rather than the light wash used in light mode.

### Voice Mode Bar Colors (separate from main palette)

| Name | Hex | Usage |
|---|---|---|
| Bar background | burgundy primary | Voice mode bar background — the same burgundy as the nav bar, and it follows light/dark mode |
| Listening bar color | `#FAECE7` | Reactive waveform bars in Listening state (cream) |
| Speaking bar color | `#F5C4B3` | Reactive waveform bars in Speaking state (salmon) |
| State label warm | `#F0997B` | "○ ready", "○ thinking", secondary text (warm salmon) |
| State label bright | `#FAECE7` | "● listening" label (cream) |
| State label speaking | `#F5C4B3` | "● speaking" label, patch pending text, exit button icon |
| Exit button border | `rgba(255,255,255,0.2)` | Exit button border in voice bar |

---

## Shape & Border Language

- **Corners:** Square or very slightly rounded. `cornerRadius` 2–4pt maximum. No bubbly iOS defaults. Square feels intentional for this design; round feels default.
- **Borders:** 1pt solid. Color is `#1A1A1A` (ink, for strong borders) or `#D0CBC3` (separator, for light dividers between rows and sections). Use borders actively — they define structure rather than shadows.
- **Cards / grouped content:** Bordered rectangles. Not shadowed floating cards.
- **Buttons:** Bordered rectangles as the default. The primary "Talk to Sous" / CTA button is the exception — filled burgundy rectangle, full-width, no border.
- **Checkboxes:** Square, bordered, not circular.
- **No drop shadows** on any UI element.

---

## Spacing & Layout

- Left/right content margins: **20pt minimum**
- Section headers sit close to their content with a clear gap above (12–16pt above, 4–8pt below)
- Dividers between sections: 1pt line, `#D0CBC3`
- List items: row separation via 1pt dividers, not cards
- Vertical rhythm is consistent — do not mix tight and loose spacing arbitrarily
- Safe area insets must be respected; content does not bleed under the nav bar or tab bar

---

## Navigation Bar

The burgundy nav bar spans the top of the screen, extending through the status bar area.

- **Background:** Burgundy primary (`#8B2E3F`)
- **Status bar style:** Light content (white/cream icons and time)
- **Icons:** `+` (new recipe), `books.vertical.fill` (history), `gear` (settings) — evenly distributed across the bar width, icon color cream (`#F2EFE9`)
- **Icon border:** None. Icons are bare SF Symbols in cream.

### Collapse Behavior (Recipe Canvas only)

- Collapsed state: burgundy background on status bar area only, nav icons hidden
- Revealed state: full bar with nav icons visible below status bar
- Collapse trigger: scroll down past ~60pt from content top
- Reveal triggers: scroll up any amount (with `distanceFromBottom > 40` guard to prevent rubber-band false positives); scroll position returns to top
- Animation: `.animation(.easeInOut(duration: 0.2), value: navBarVisible)` attached directly to the bar view — not `withAnimation` inside the scroll callback

### Always-Visible (Zero State, Exploration State)

No collapse/reveal logic. Bar is always visible on screens with no scrollable content.

---

## Screen-by-Screen Spec

### Recipe Canvas (Cook Mode)

- Background: cream (`#F2EFE9`)
- Nav bar: burgundy, scroll-reveal
- Recipe title: New York, ~28pt, semibold, title case, ink color
- Thin horizontal divider below title block
- Section headers (INGREDIENTS, PROCEDURE, MISE EN PLACE): SF Pro, 11pt, ALL CAPS, burgundy primary, letter-spaced 1.2
- Ingredient rows: square bordered checkbox + SF Pro body text, ~16pt
  - Checked ingredients: checkbox filled burgundy, text **without** strikethrough (legibility preserved for reference use)
- Step rows: numbered, SF Pro ~17pt body text
  - Done steps: text struck through in muted color (`#9A9590`), checkbox or indicator filled burgundy
  - Steps with timers: same SF Pro font as all other steps — do not deviate based on timer presence
- Sub-steps: indented below parent step, independently checkable, same font at slightly smaller size
- "Talk to Sous" button: pinned to bottom, full-width, filled burgundy (`#8B2E3F`), cream ALL CAPS SF Pro label
- Voice mode mic button: near "Talk to Sous" button, Cook Mode only

### Chat Sheet

- Background: white (`#FFFFFF`) for the sheet surface, cream scrim on recipe behind
- User messages: burgundy secondary bg (`#F7EAEC`) bubble, ink text, SF Pro
- Assistant messages: white/surface background, bordered rectangle (not bubble), ink text, SF Pro — renders Markdown (bold, italic, bullet lists, numbered lists, headers)
- Memory toast: appears at top of chat sheet; shows proposed memory text + Save / Edit / Skip buttons inline
- Input bar: square-bordered text field, camera icon left, send icon right
- Exploration phase option cards: bordered card, dish name in New York, body in SF Pro, left border accent line in burgundy

### Patch Review Mode

- Background: cream
- Recipe canvas visible and primary; chat sheet collapsed; scrim removed
- Proposed diff rendered in-place:
  - Added items: muted green (`#2D6A4F`) highlight, left border accent
  - Modified items: rendered in final proposed state with "Edited" indicator
  - Removed items: struck through, ghost rendering in original position
- Bottom action bar: pinned, two equal columns
  - Left: REJECT — burgundy text on cream background
  - Right: ACCEPT CHANGES — cream text on ink (`#1A1A1A`) fill
  - Both ALL CAPS SF Pro, square corners, no border-radius

### Voice Mode Bar

Overlays the bottom of the screen. Does not replace or push the recipe canvas.

- Background: burgundy primary (`#8B2E3F` light / `#C45068` dark) — same token as the nav bar
- Height: sufficient to accommodate state label above + 28pt animation canvas below
- Top section: centered state label (SF Pro ~13pt, lowercase) + X exit button pinned top-right (28×28pt, `rgba(255,255,255,0.2)` border, `#F5C4B3` icon, SF Symbol "xmark")
- Bottom edge: full-width animation strip (28pt tall, flush to bar bottom)

**Animation strip spec:**
- Pixel pitch: 3pt unit, 2pt gap, 5pt step (bars and dots share the same pitch)
- Dot size: 3×3pt
- Two-row dot layout: row vertical gap = 2pt (same as horizontal gap)

| State | Label | Label color | Animation |
|---|---|---|---|
| Ready | `○ ready` | `#F0997B` | Two rows pulsing square dots, moderate intensity |
| Listening | `● listening` | `#FAECE7` | Full-width reactive bars in `#FAECE7` |
| Thinking | `○ thinking` | `#F0997B` | Two rows pulsing square dots, high intensity |
| Speaking | `● speaking` | `#F5C4B3` | Full-width reactive bars in `#F5C4B3`; secondary line "say 'stop' to interrupt" in `#F0997B` |
| Patch Pending | "say 'accept' or 'reject'" in `#F5C4B3` | — | Two rows slow-pulsing dots + Reject / Accept buttons above |

In Patch Pending state: full Patch Review Mode diff renders on the recipe canvas identically to text-mode patch review. Voice bar shows button pair (Reject left, Accept right) in addition to the dot indicator.

### Zero / Blank State

- Background: cream
- Burgundy nav bar always visible (no collapse logic)
- "Sous" wordmark: New York, large
- "Talk to a recipe" primary CTA: filled burgundy button
- "OR CREATE ONE" secondary text button: SF Pro, ink or muted

### History / Recent Recipes Drawer

- Background: cream
- Header: "HISTORY" SF Pro ALL CAPS centered
- List: bordered cards or thin-divider rows
- Each entry: recipe title (New York) left, timestamp (SF Pro caption, muted) right
- Swipe-left to delete

### Settings

- Background: cream
- Standard grouped list layout but with cream background (not system gray grouped)
- Section headers: SF Pro ALL CAPS, muted color
- Preference fields: square-bordered inputs / text areas
- Memories list: tap to edit, swipe-left to delete

---

## Iconography

- SF Symbols throughout
- No custom icon assets unless unavoidable
- Icon color: inherits from context (cream on burgundy surfaces, ink on cream surfaces, muted for secondary/inactive states)
- Icon weight: match surrounding text weight where possible

---

## Ingredient Checkbox Behavior

Ingredient checkboxes tick **without** applying strikethrough — legibility is preserved for shopping and reference use while cooking. This is intentional and must not be "fixed."

Step and Mise en Place checkboxes apply strikethrough on check.

All checkbox types remain at full opacity regardless of checked state — do not fade checked rows.

---

## What Not To Do

- Do not use monospace outside numeric readouts and voice bar state labels (see Typography)
- Do not use rounded buttons (capsule shape)
- Do not use SwiftUI default grouped list background (system gray)
- Do not use shadows or elevation
- Do not use filled secondary buttons — bordered rectangles only (except the primary CTA)
- Do not allow terracotta/orange anywhere — that palette was fully replaced by burgundy
- Do not use separate typefaces beyond New York and SF Pro

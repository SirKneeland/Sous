# Sous — Design Spec (M17)

## Overview

This document defines the visual language for Sous. Claude Code must apply this system consistently across all screens. Do not deviate toward default SwiftUI aesthetics — this design is intentional and opinionated.

The aesthetic direction is: **chef's notebook meets technical manual**. Warm, precise, and utilitarian. It should feel like a tool a serious home cook would trust, not a consumer app trying to look friendly.

---

## Typography

Use the closest available iOS system monospace font. In order of preference:
1. `SF Mono` (available as a system font on iOS)
2. `Courier New`
3. `.AppleSystemUIFontMonospaced`

Apply monospace consistently across ALL text in the app — titles, body, labels, buttons, inputs. There is no secondary font. The monospace is the identity.

**Type scale:**
- `title` — large, bold, ALL CAPS
- `sectionHeader` — small, ALL CAPS, terracotta color, letter-spaced
- `body` — regular weight, sentence case
- `caption` — small, muted color, ALL CAPS for labels (e.g. REV. 3, 3 MIN AGO)
- `button` — ALL CAPS, bold or medium weight

---

## Color Palette

```
Background:     #F2EFE9   (warm cream, not white)
Text:           #1A1A1A   (near-black charcoal)
Accent:         #C1440E   (terracotta — used for section headers, active states, highlights, reject actions)
Muted:          #9A9590   (warm gray — used for captions, timestamps, placeholders, done-step text)
Surface:        #FFFFFF   (white — used for bordered cards and input fields only)
Success/Add:    #2D6A4F   (muted green — used for added items in patch diff only)
Danger/Remove:  #C1440E   (terracotta — used for removed items in patch diff, also serves as accent)
Done overlay:   semi-transparent terracotta fill on checkboxes
```

Dark mode: invert background to #1A1A1A, text to #F2EFE9, keep accent and muted colors.

---

## Shape & Border Language

- **Corners:** square or very slightly rounded (cornerRadius 2–4pt max). No bubbly iOS defaults.
- **Borders:** 1pt solid, color #1A1A1A (dark) or #D0CBC3 (light separator). Use borders actively — they define structure.
- **Cards / grouped content:** bordered rectangles, not shadowed floating cards.
- **Buttons:** bordered rectangles, not filled capsules. Exception: the primary "Open Chat" CTA which uses a filled terracotta rectangle.
- **Checkboxes:** square, bordered, not circular.

---

## Spacing & Layout

- Generous left/right margins (20pt minimum).
- Section headers sit close to their content with a clear gap above.
- Dividers between sections: 1pt line, muted color.
- List items: clear row separation via thin dividers, not cards.
- Vertical rhythm is consistent — don't mix tight and loose spacing arbitrarily.

---

## Screen-by-Screen Spec

### Recipe Canvas (Cook Mode)

- Background: cream (#F2EFE9)
- Title: large, bold, ALL CAPS monospace, near-black
- Below title: `REV. N` in small ALL CAPS muted caption
- Thin horizontal divider below title block
- Section headers (INGREDIENTS, PROCEDURE): small ALL CAPS terracotta, letter-spaced, no bold
- Ingredient rows: square bordered checkbox + monospace body text
- Checked ingredients: checkbox filled terracotta, text struck through in muted color
- Step rows: numbered, monospace body text
- Done steps: text struck through in muted color, checkbox filled terracotta
- Top-right header buttons: gear icon, clock icon, plus icon — square bordered, small
- "Open Chat" button: pinned to bottom of screen, full-width, filled terracotta rectangle, ALL CAPS white monospace label

### Chat Sheet

- Background: white (#FFFFFF) for the sheet surface
- Header row: "ASSISTANT" in ALL CAPS monospace left, "CLOSE" in ALL CAPS terracotta right
- Thin top border on sheet
- User messages: dark filled bubble (near-black background, cream text), monospace
- Assistant messages: bordered rectangle (cream background, dark text), monospace — NOT a bubble, a box
- Options list (exploration phase): bordered card, numbered in terracotta (01. 02. 03.), body text in dark monospace, left border accent line in terracotta
- Input area: square bordered text field, camera icon left, send icon right (square bordered button)
- Chat loads scrolled to most recent message

### Patch Review

- Background: cream
- Title: ALL CAPS, bold, large
- Below title: `REV. N → N+1` in muted caption
- Thin divider
- "CHANGES" section header: terracotta ALL CAPS
- Removed items: struck through in terracotta, left border accent line
- Added items: muted green (#2D6A4F), left border accent line
- "STEP STATUS" section header: terracotta ALL CAPS
- DONE badge: square bordered, filled dark, white ALL CAPS text
- TODO badge: square bordered, terracotta border, terracotta ALL CAPS text
- Bottom action bar: pinned, two equal columns separated by a border
  - Left: REJECT — terracotta text on cream
  - Right: ACCEPT — white text on near-black fill
  - Both ALL CAPS monospace, no rounded corners

### Recent Recipes (History)

- Background: cream
- Header: "HISTORY" centered ALL CAPS, "DONE" button top-left as square bordered button
- Recipe list: bordered card containing rows separated by thin dividers
- Each row: recipe title (monospace body) left, timestamp (muted caption, e.g. "3 MIN", "1 DAY") right, chevron far right
- Timestamps in ALL CAPS muted

### Blank / Zero State

- Background: cream
- "SOUS" logotype centered, large, bold ALL CAPS monospace
- Tagline or prompt below in smaller muted monospace
- Single CTA: bordered rectangle button, "START COOKING" or similar, ALL CAPS

### Settings

- Background: cream
- Standard iOS Form structure but reskinned: section headers in terracotta ALL CAPS small, rows with monospace text, square toggle/input styles where possible
- Memories section: list rows with monospace text, swipe-left to delete, tap to edit per standard UX
- No floating cards — use dividers and section headers for structure

---

## Component Patterns

### Badges
- DONE: filled dark rectangle, white ALL CAPS monospace text
- TODO: bordered terracotta rectangle, terracotta ALL CAPS monospace text

### Toast (Memory Proposal)
- Appears at top of chat sheet
- Bordered rectangle, cream background
- Memory text in monospace body
- Three inline buttons: SAVE | EDIT | SKIP — ALL CAPS, terracotta
- Progress bar along bottom indicating 10-second timeout

### Patch Diff Lines
- Left border accent line (2pt) in terracotta for removed, green for added
- Removed: terracotta struck-through text
- Added: green text, no strikethrough

---

## What to Avoid

- Rounded corners beyond 4pt
- Filled capsule buttons (except Open Chat CTA)
- Shadow-based elevation
- Any non-monospace font
- Blue as an accent color
- Default iOS list styling (grouped inset rounded)
- Purple, gradient, or glassmorphism of any kind
- SF Symbols that look too playful — prefer simple geometric icons or text labels

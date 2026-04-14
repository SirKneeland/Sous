# ThumbDrop

ThumbDrop is a downward swipe gesture that moves the user between the recipe canvas and the chat sheet. It works in both directions and uses the same zone size, thresholds, and haptic sequence in both directions — it is a unified gesture system, not two separate ones.

---

## Directions

| Direction | Entry point | Result |
|---|---|---|
| Recipe canvas → Chat | Swipe down anywhere in the bottom 30% of the screen while the recipe canvas is active | Opens the chat sheet |
| Chat → Recipe canvas | Swipe down anywhere in the bottom 30% of the screen while the chat sheet is presented in non-fullscreen (sheet) mode | Dismisses the chat sheet |

---

## Implementation

Both directions use `ThumbDropOverlay` (`Views/ThumbDropOverlay.swift`), a `UIViewRepresentable` that installs a `UIPanGestureRecognizer` on the window.

- **Recipe canvas → Chat**: `ThumbDropOverlay` is placed as a `.background` on `BottomZoneView` (`WindowButtonHost.swift`). It is present in the hierarchy only when the recipe canvas is active; SwiftUI's view lifecycle removes the recognizer automatically when the bottom zone is hidden.
- **Chat → Recipe canvas**: `ThumbDropOverlay` is placed as a `.background` on the root of `ChatSheetView`, with `isActive: !isFullscreen`.

`shouldRecognizeSimultaneouslyWith` returns `true` for all other recognizers — ThumbDrop never blocks taps, scroll views, or row swipe actions.

---

## Trigger zone

Touches that do not start in the **bottom 30% of the screen** (`touchInWindow.y >= screenHeight * 0.7`) are rejected in `gestureRecognizerShouldBegin` before the gesture begins. This applies in both directions.

---

## Commit logic

A gesture commits (opens or closes the chat sheet) when **either** condition is met at `.ended`:

- Downward translation ≥ **50pt**, OR
- Peak downward velocity ≥ **400pt/s**

Peak velocity is tracked across all `.changed` events (not read at `.ended`, which is unreliable on fast flicks). It resets to zero on each new gesture.

---

## Angle gate

Once the total movement exceeds 12pt, the gesture fails if horizontal displacement exceeds vertical displacement (`dx > abs(dy)`). This lets diagonal swipes, scroll gestures, and row swipe actions fall through cleanly without competition.

---

## Haptic sequence

Fired during a downward ThumbDrop. Each band fires **at most once per gesture** — reverse travel does not re-trigger a band that already fired.

| Event | Style |
|---|---|
| Gesture confirmed as downward (first `.changed` with `dy > 0`) | `.light` |
| 30pt of downward travel | `.light` |
| 60pt of downward travel | `.medium` |
| 90pt of downward travel | `.rigid` |
| Commit | `.medium` |

All bands reset at the start of each new gesture.

---

## Visual feedback

The "Talk to Sous" button (recipe→chat direction) and the chat input bar (chat→recipe direction) both translate downward during the drag as visual feedback. The offset is computed as `min(dy * 0.65, 60)` — dampened to 65% of raw translation, capped at 60pt. On cancel, the element springs back with `response: 0.3, dampingFraction: 0.7`.

---

## What ThumbDrop does not affect

- Taps on any element in the bottom zone
- Vertical scrolling of the recipe canvas (`List`)
- Row swipe actions (mark done, Ask Sous)
- Timer banner taps
- Fullscreen chat (ThumbDrop is inactive when `isFullscreen` is true)

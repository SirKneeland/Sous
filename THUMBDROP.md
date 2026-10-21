# ThumbDrop

ThumbDrop is a downward swipe gesture that moves the user between the recipe canvas and the chat sheet. It works in both directions and uses the same zone size, thresholds, and haptic sequence in both directions — it is a unified gesture system, not two separate ones.

---

## Directions

| Direction | Entry point | Result |
|---|---|---|
| Recipe canvas → Chat | Swipe **up** anywhere in the bottom 15% of the screen while the recipe canvas is active | Opens the chat sheet |
| Chat → Recipe canvas | Swipe down anywhere in the bottom 15% of the screen while the chat sheet is presented in non-fullscreen (sheet) mode | Dismisses the chat sheet |

---

## Implementation

Both directions use `ThumbDropOverlay` (`Views/ThumbDropOverlay.swift`), a `UIViewRepresentable` that installs a `UIPanGestureRecognizer` on the window.

- **Recipe canvas → Chat**: `ThumbDropOverlay` is placed as a `.background` on `BottomZoneView` (`WindowButtonHost.swift`), with `tracksDownward: false`. It is present in the hierarchy only when the recipe canvas is active; SwiftUI's view lifecycle removes the recognizer automatically when the bottom zone is hidden.

  **The bar is a two-way handle and ThumbDrop only owns one way.** Up opens chat, which slides up from the bottom. Down belongs to the window shade — a `ShadePullInstaller` mounted beside the bar brings the shade down over the canvas, with the burgundy RECIPES hem appearing at the top as the affordance and the bar following the thumb. That is why `tracksDownward` exists: two escalating haptic ramps on one drag is one too many, and downward commits here would open chat behind the shade.
- **Chat → Recipe canvas**: `ThumbDropOverlay` is placed as a `.background` on the root of `ChatSheetView`, with `isActive: !isFullscreen`.

`shouldRecognizeSimultaneouslyWith` returns `true` for all other recognizers — ThumbDrop never blocks taps, scroll views, or row swipe actions.

---

## Trigger zone

Touches that do not start in the **bottom 15% of the screen** (`touchInWindow.y >= screenHeight * 0.85`) are rejected in `gestureRecognizerShouldBegin` before the gesture begins. This applies in both directions.

The zone is a parameter — `TriggerZone` — not a constant:

| Case | Meaning |
|---|---|
| `.bottomScreenFraction(0.15)` | The bottom 15% of the screen. **The default**, and what every call site uses today. |
| `.viewEdge(.top, height:)` / `.viewEdge(.bottom, height:)` | A band that many points tall, pinned to an edge of the view the overlay is a `.background` of — for a grab bar or a dismiss zone inside a panel. |

The zone gates only where the gesture *starts*. Both commit directions work from any zone position, including one pinned to the top of the screen.

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

The ladder lives in `SousHapticRamp` (`Haptics/SousHaptics.swift`) and is shared with the chat input bar's own `DragGesture`, which uses the same 30 / 60 / 90 pt bands with no entry tick and a single gate set keyed on absolute travel. Every haptic in ThumbDrop goes through `SousHaptics`, which caches and pre-warms the generators so the entry tick lands without Taptic Engine spin-up latency.

---

## Visual feedback

The "Talk to Sous" button (recipe→chat direction) and the chat input bar (chat→recipe direction) both translate downward during the drag as visual feedback. The offset is computed as `min(dy * 0.65, 60)` — dampened to 65% of raw translation, capped at 60pt. On cancel, the element springs back with `response: 0.3, dampingFraction: 0.7`.

---

## Parameters

Every geometric and threshold value is an argument on `ThumbDropOverlay`. The defaults are exactly the canvas↔chat values described above, so a call site that passes none behaves as it always has.

| Parameter | Default | What it does |
|---|---|---|
| `triggerZone` | `.bottomScreenFraction(0.15)` | Where the touch must start (see Trigger zone). |
| `offsetClamp` | `60` | Magnitude cap, in points, on the offset reported to `onOffsetChanged`. Pass `ThumbDropOverlay.unlimitedOffset` to track a panel across the whole screen. |
| `damping` | `0.65` | Fraction of raw translation reported as offset. |
| `commitDistance` | `50` | Translation in points that commits. |
| `commitVelocity` | `400` | Peak velocity in pt/s that commits. |

Upward tracking — offset, haptics, and commit — is enabled by passing an `onUpwardCommit` handler. With no handler, upward drag parks the element at rest and fires nothing.

The window shade's grab bar is the first call site to pass any of these: `.viewEdge(.bottom, height:)` for a zone inside the shade rather than a fraction of the screen, `unlimitedOffset` and `damping: 1` so the shade tracks the finger one-to-one across the whole display, and its own commit distance and velocity from the debug tunables. The shade's own pull-down is a separate recognizer (`ShadePullInstaller`) built on the same observe-without-consuming contract.

**The two cannot share a touch, and the zone is how they are kept apart.** `ThumbDropOverlay.defaultZoneTopY` publishes where the bottom zone's strip begins, and the shade's pull refuses to start below it. Without that the shade would start on a downward swipe over the Talk to Sous bar whenever the canvas was scrolled to the top — and a shade that has started hides the bottom zone, which removes this recognizer from the window mid-swipe. The swipe then does nothing at all. The bottom bar also now stays mounted for the whole of an opening pull, and only goes away once the shade is genuinely over it.

---

## What ThumbDrop does not affect

- Taps on any element in the bottom zone
- Vertical scrolling of the recipe canvas (`List`)
- Row swipe actions (mark done, Ask Sous)
- Timer banner taps
- Fullscreen chat (ThumbDrop is inactive when `isFullscreen` is true)

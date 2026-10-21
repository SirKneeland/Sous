import Observation
import SwiftUI

// MARK: - ShadePhase

/// Where the window shade is, and whether a finger is currently driving it.
///
/// `progress` is 0 when the shade is fully retracted above the screen and 1 when
/// it covers the screen. The two interactive cases carry it so that a gesture can
/// move the shade without the shade having to know which gesture it was.
enum ShadePhase: Equatable {
    case closed
    case opening(progress: CGFloat)
    case open
    case closing(progress: CGFloat)

    var progress: CGFloat {
        switch self {
        case .closed: return 0
        case .open: return 1
        case .opening(let p), .closing(let p): return p
        }
    }

    /// True while a finger is driving the shade, so the view can skip any
    /// implicit animation and track the touch exactly.
    var isInteractive: Bool {
        switch self {
        case .opening, .closing: return true
        case .closed, .open: return false
        }
    }

}

// MARK: - ShadePresentation

/// The window shade's presentation state, independent of what opens it.
///
/// The shade has one entry point today — pulling down on the recipe canvas once
/// it is scrolled to the top — and a second is coming: a grab bar at the top of
/// the explore screen. Neither belongs in here. A gesture's whole contract with
/// the shade is four calls: `beginOpening()`, `driveOpening(progress:)` on every
/// change, and `finishOpening(commit:)` on release — or the `close` mirror of
/// those. Adding the second entry point is therefore wiring, not surgery.
///
/// Haptics that belong to the *presentation* live here, so every entry point gets
/// them for free: a medium impact when a pull commits, a light one when the shade
/// lands, and a medium one when a dismissal commits. Haptics that belong to a
/// *gesture* — the peek tick, the commit detent, the ThumbDrop ramp — stay with
/// that gesture, because only it knows how far a finger has travelled.
/// `@Observable` rather than `ObservableObject` on purpose: `progress` changes on
/// every frame of a drag, and an `ObservableObject` would invalidate every view
/// holding it — `ContentView` included, with the whole recipe canvas inside it.
/// Observation invalidates only the views that actually read the value that moved.
@Observable
final class ShadePresentation {
    private(set) var phase: ShadePhase = .closed

    /// Whether the panel is showing its own contents, or is still the blank
    /// burgundy sheet it is while being pulled.
    ///
    /// Not derivable from `phase`: `.closed` has to mean "sheet" when a pull was
    /// cancelled, so the shade stays blank on the way back up, and "panel" after a
    /// dismissal, so it keeps its contents as it leaves. Written inside the same
    /// `withAnimation` as the commit, so the crossfade rides the open spring
    /// instead of snapping the moment a finger lifts.
    private(set) var showsContent: Bool = true

    /// Spring used when the shade travels down. Driven by the debug tunables.
    var openAnimation: Animation = .spring(response: 0.42, dampingFraction: 0.86)
    /// Spring used when the shade travels back up.
    var closeAnimation: Animation = .spring(response: 0.34, dampingFraction: 0.90)
    /// When the system's Reduce Motion setting is on, both springs are replaced by
    /// a quick fade — the view stops translating the panel and crossfades it instead.
    var reduceMotion: Bool = false

    // MARK: Derived state

    var progress: CGFloat { phase.progress }
    var isClosed: Bool { phase == .closed }
    var isOpen: Bool { phase == .open }
    /// True from the first pixel of a pull until the shade is fully retracted again.
    var isVisible: Bool { phase != .closed }
    var isInteractive: Bool { phase.isInteractive }

    var isOpening: Bool { if case .opening = phase { return true }; return false }
    var isClosing: Bool { if case .closing = phase { return true }; return false }

    /// True once the shade is actually over the bottom of the screen — open, or on
    /// its way back up. **Not** true during an opening pull: the shade is only at
    /// the top then, the bottom bar is still in plain sight, and taking it away
    /// would also take away its ThumbDrop recognizer.
    var coversBottomZone: Bool { isOpen || isClosing }

    // MARK: Interactive open

    func beginOpening() {
        guard isClosed else { return }
        // Blank the panel before a single pixel of it is on screen. A pull should
        // reveal one burgundy sheet, not a glimpse of the panel's own footer.
        showsContent = false
        phase = .opening(progress: 0)
    }

    /// Moves the shade. `progress` is clamped to 0...1; the caller converts
    /// whatever its gesture measures — points of pull, with whatever resistance
    /// curve it likes — into that range.
    func driveOpening(progress: CGFloat) {
        guard case .opening = phase else { return }
        phase = .opening(progress: clamped(progress))
    }

    /// Ends a pull: springs the shade the rest of the way down, or back up.
    func finishOpening(commit: Bool) {
        guard case .opening = phase else { return }
        if commit { commitOpen() } else { springClosed() }
    }

    // MARK: Interactive close

    func beginClosing() {
        guard isOpen else { return }
        phase = .closing(progress: 1)
    }

    func driveClosing(progress: CGFloat) {
        guard case .closing = phase else { return }
        phase = .closing(progress: clamped(progress))
    }

    /// Ends a dismissal: sends the shade the rest of the way up, or back down.
    func finishClosing(commit: Bool) {
        guard case .closing = phase else { return }
        if commit { commitClose() } else { springOpen(haptics: false) }
    }

    // MARK: Programmatic

    /// Opens the shade with no gesture behind it — the accessibility action, or a
    /// tap on a grab bar.
    func open() {
        guard !isOpen else { return }
        if isClosed { phase = .opening(progress: 0) }
        commitOpen()
    }

    /// Closes the shade. `completion` runs once it has fully retracted, which is
    /// how choosing a recipe or NEW RECIPE waits for the shade to get out of the
    /// way before acting — the same order the history drawer uses.
    func close(completion: (() -> Void)? = nil) {
        guard !isClosed else { completion?(); return }
        if isOpen { phase = .closing(progress: 1) }
        commitClose(completion: completion)
    }

    // MARK: Transitions

    private func commitOpen() {
        SousHaptics.impact(.medium)
        withAnimation(effective(openAnimation), completionCriteria: .logicallyComplete) {
            phase = .open
            showsContent = true
        } completion: {
            // The shade touching the bottom of the screen.
            SousHaptics.impact(.light)
        }
    }

    private func commitClose(completion: (() -> Void)? = nil) {
        SousHaptics.impact(.medium)
        withAnimation(effective(closeAnimation), completionCriteria: .logicallyComplete) {
            phase = .closed
        } completion: {
            completion?()
        }
    }

    /// Cancels a pull — no haptic, because nothing happened.
    private func springClosed() {
        withAnimation(effective(closeAnimation)) { phase = .closed }
    }

    private func springOpen(haptics: Bool) {
        if haptics { SousHaptics.impact(.light) }
        withAnimation(effective(openAnimation)) { phase = .open }
    }

    private func effective(_ animation: Animation) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : animation
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }
}

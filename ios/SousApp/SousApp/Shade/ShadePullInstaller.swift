import SwiftUI
import UIKit

// MARK: - ShadePullInstaller

/// The recipe canvas's entry point to the window shade: keep pulling down once the
/// list is already at the top, and the shade comes down with you.
///
/// Installs a `UIPanGestureRecognizer` on the window and *observes* without
/// consuming — `cancelsTouchesInView = false`, `delaysTouchesBegan = false`, and
/// `shouldRecognizeSimultaneouslyWith` always true — exactly as `ThumbDropOverlay`
/// and `DrawerDismissInstaller` do. Scrolling, swipe actions, collapsible section
/// headers, long-presses and timer rows therefore behave as if this did not exist;
/// the canvas still rubberbands under the descending shade.
///
/// Add as a `.background` on the recipe canvas so the recognizer is removed with it.
///
/// Two gates keep it out of the way: `isAtTop`, so the gesture can only start where
/// the list already rubberbands, and `isActive`, which the caller turns off in chat,
/// voice mode, title editing, patch review, and whenever the left-edge drawer or the
/// shade itself is already showing.
struct ShadePullInstaller: UIViewRepresentable {
    var isActive: Bool
    /// Whether the gesture may only start where the canvas already rubberbands.
    /// True for the canvas pull. False for the bottom bar, which is a handle you
    /// grab rather than an overscroll you continue.
    var requiresCanvasAtTop: Bool = true
    /// True when the canvas is scrolled to its top. Read at the instant the pan is
    /// recognised; a rubberband past the top still counts as the top.
    var isAtTop: Bool
    /// Window-space band the touch must start in. The canvas owns everything above
    /// the bottom bar's strip; the bar owns the strip itself. Disjoint on purpose —
    /// one touch must never be claimed by both.
    var startYRange: Range<CGFloat>
    var tuning: ShadeGesture
    /// Full travel of the shade — the screen height. Converts points into progress.
    var shadeHeight: CGFloat
    var onBegin: () -> Void
    /// Called on every change with the shade's progress (0...1) and the raw
    /// downward pull in points, so a caller can move something under the finger.
    var onProgress: (_ progress: CGFloat, _ pull: CGFloat) -> Void
    /// Called once on release with whether the pull committed.
    var onEnd: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }

    func makeUIView(context: Context) -> ShadePullHostView {
        let host = ShadePullHostView()
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        host.pan = pan
        return host
    }

    func updateUIView(_ uiView: ShadePullHostView, context: Context) {
        context.coordinator.owner = self
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var owner: ShadePullInstaller

        /// True once this gesture has been accepted as a shade pull and the
        /// presentation has been told to start opening.
        private var pulling = false
        /// True once the angle gate has rejected the gesture; it cannot recover.
        private var failed = false
        /// Fires once, when the peek is fully out.
        private var peekFired = false
        /// Whether the pull is currently past the commit distance. Each crossing in
        /// either direction fires its own tick.
        private var pastDetent = false
        /// Peak downward velocity. End-state velocity is unreliable on fast flicks,
        /// so ThumbDrop tracks the peak and so does this.
        private var peakVelocity: CGFloat = 0

        init(owner: ShadePullInstaller) {
            self.owner = owner
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                pulling = false
                failed = false
                peekFired = false
                pastDetent = false
                peakVelocity = 0

            case .changed:
                guard !failed else { return }
                let translation = gesture.translation(in: gesture.view)
                let dx = abs(translation.x)
                let dy = translation.y

                // Angle gate, as ThumbDrop's: once there is enough movement to tell
                // the direction, a mostly-horizontal gesture is not a shade pull.
                if dx + abs(dy) > 12 && dx > abs(dy) {
                    fail()
                    return
                }
                guard dy > 0 else {
                    // Scrolled back up past where the pull started. Keep the shade
                    // tracking at zero rather than cancelling: the finger is still down.
                    if pulling { owner.onProgress(0, 0) }
                    return
                }
                if !pulling {
                    guard owner.isActive else { return }
                    pulling = true
                    SousHaptics.prepare(.reveal, .detentEngage, .detentRelease, .commit)
                    owner.onBegin()
                }

                let vy = gesture.velocity(in: gesture.view).y
                if vy > peakVelocity { peakVelocity = vy }

                // The peek is fully out: the one haptic an ordinary top bounce
                // never reaches, because an ordinary bounce stops short of here.
                if !peekFired && dy >= owner.tuning.peekAppearDistance {
                    peekFired = true
                    SousHaptics.play(.reveal)
                }

                // Detent at the commit distance — crisp going past it, lighter
                // coming back, once per crossing.
                let past = dy >= owner.tuning.pullCommitDistance
                if past != pastDetent {
                    pastDetent = past
                    SousHaptics.play(past ? .detentEngage : .detentRelease)
                }

                owner.onProgress(progress(forPull: dy), dy)

            case .ended:
                guard pulling, !failed else { return }
                pulling = false
                let dy = gesture.translation(in: gesture.view).y
                let commits = dy >= owner.tuning.pullCommitDistance
                    || peakVelocity >= owner.tuning.pullCommitVelocity
                owner.onEnd(commits)

            case .cancelled, .failed:
                guard pulling else { return }
                pulling = false
                owner.onEnd(false)

            default:
                break
            }
        }

        private func fail() {
            failed = true
            guard pulling else { return }
            pulling = false
            owner.onEnd(false)
        }

        private func progress(forPull pull: CGFloat) -> CGFloat {
            let height = max(1, owner.shadeHeight)
            return min(1, owner.tuning.travel(forPull: pull) / height)
        }

        // MARK: - UIGestureRecognizerDelegate

        /// Only start where the canvas already rubberbands: at the top, moving down,
        /// and clear of the strip the bottom bar's own ThumbDrop owns.
        ///
        /// That last clause is not a nicety. The two gestures cannot share a touch:
        /// the shade starting hides the bottom zone, and hiding the bottom zone
        /// removes ThumbDrop's recognizer from the window — so a swipe down on the
        /// Talk to Sous bar, with the canvas at the top, used to do nothing at all.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            guard owner.isActive else { return false }
            if owner.requiresCanvasAtTop && !owner.isAtTop { return false }
            guard owner.startYRange.contains(pan.location(in: nil).y) else { return false }
            let velocity = pan.velocity(in: pan.view)
            return velocity.y > 0 && velocity.y > abs(velocity.x)
        }

        /// Never steal a tap, a scroll, a swipe action or a long press.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

// MARK: - ShadePullHostView

/// Installs the recognizer on the window when it enters the hierarchy and removes
/// it when it leaves, so the gesture lives exactly as long as the canvas does.
/// Never hit-tests, so it cannot block anything underneath.
final class ShadePullHostView: UIView {
    var pan: UIPanGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let pan else { return }
        pan.view?.removeGestureRecognizer(pan)
        window?.addGestureRecognizer(pan)
    }
}

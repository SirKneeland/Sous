import SwiftUI
import UIKit

// MARK: - ThumbDropOverlay

/// Installs a `UIPanGestureRecognizer` at the window level so that ThumbDrop
/// can be triggered from anywhere in the bottom fifth of the screen, not just
/// from the input bar row.
///
/// The UIView itself is zero-height and non-interactive; gesture recognition
/// happens at the enclosing window, which is above all sibling views in the
/// responder chain. This means taps, scrolls, and long-presses in the chat
/// transcript are never blocked — `shouldRecognizeSimultaneouslyWith` returns
/// `true` for every other recognizer.
///
/// Usage: add as a `.background` on the root of `ChatSheetView`. It installs
/// itself on `didMoveToWindow` and cleans up when the sheet dismisses.
struct ThumbDropOverlay: UIViewRepresentable {
    /// True when the chat sheet is presented in non-fullscreen (sheet) mode.
    var isActive: Bool
    /// Called with the current drag offset (-60–60 pt) as the gesture progresses.
    /// Negative values mean the element is being dragged upward.
    var onOffsetChanged: (CGFloat) -> Void
    /// Called when the gesture commits downward: ≥50 pt down or ≥400 pt/s peak velocity.
    var onCommit: () -> Void
    /// Called when the gesture cancels or fails — consumer should spring the element back.
    var onCancel: () -> Void
    /// Called when the gesture commits upward: ≥50 pt up or ≥400 pt/s peak upward velocity.
    /// Pass nil to disable upward commit detection (default).
    var onUpwardCommit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(isActive: isActive,
                    onOffsetChanged: onOffsetChanged,
                    onCommit: onCommit,
                    onCancel: onCancel,
                    onUpwardCommit: onUpwardCommit)
    }

    func makeUIView(context: Context) -> ThumbDropHostView {
        let hostView = ThumbDropHostView()
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        // Do not cancel or delay touches — we're observing, not consuming.
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        hostView.pan = pan
        return hostView
    }

    func updateUIView(_ uiView: ThumbDropHostView, context: Context) {
        context.coordinator.isActive = isActive
        context.coordinator.onOffsetChanged = onOffsetChanged
        context.coordinator.onCommit = onCommit
        context.coordinator.onCancel = onCancel
        context.coordinator.onUpwardCommit = onUpwardCommit
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isActive: Bool
        var onOffsetChanged: (CGFloat) -> Void
        var onCommit: () -> Void
        var onCancel: () -> Void
        var onUpwardCommit: (() -> Void)?

        /// Set to true when the angle gate fires mid-gesture so we ignore
        /// subsequent `.changed` events and don't call `onCommit` at `.ended`.
        private var hasFailed = false
        /// Guards against calling `onCancel` more than once per gesture.
        private var cancelFired = false
        /// Guards against firing the entry haptic more than once per gesture.
        private var entryHapticFired = false
        /// Downward slingshot thresholds. Each fires at most once per gesture.
        private var sling1Fired = false  // 30pt → .light
        private var sling2Fired = false  // 60pt → .medium
        private var sling3Fired = false  // 90pt → .rigid
        /// Upward slingshot thresholds (mirrored). Each fires at most once per gesture.
        private var slingUp1Fired = false  // -30pt → .light
        private var slingUp2Fired = false  // -60pt → .medium
        private var slingUp3Fired = false  // -90pt → .rigid
        /// Peak downward velocity (pt/s) seen during .changed. End-state velocity
        /// is unreliable on fast flicks (reads negative at lift-off); peak is stable.
        private var peakVelocity: CGFloat = 0
        /// Peak upward velocity magnitude (pt/s). Stored as positive for easy comparison.
        private var peakUpwardVelocity: CGFloat = 0

        init(isActive: Bool,
             onOffsetChanged: @escaping (CGFloat) -> Void,
             onCommit: @escaping () -> Void,
             onCancel: @escaping () -> Void,
             onUpwardCommit: (() -> Void)? = nil) {
            self.isActive = isActive
            self.onOffsetChanged = onOffsetChanged
            self.onCommit = onCommit
            self.onCancel = onCancel
            self.onUpwardCommit = onUpwardCommit
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                hasFailed = false
                cancelFired = false
                entryHapticFired = false
                sling1Fired = false
                sling2Fired = false
                sling3Fired = false
                slingUp1Fired = false
                slingUp2Fired = false
                slingUp3Fired = false
                peakVelocity = 0
                peakUpwardVelocity = 0

            case .changed:
                guard !hasFailed else { return }
                let translation = gesture.translation(in: gesture.view)
                let dx = abs(translation.x)
                let dy = translation.y

                // Angle gate: once there is enough movement to evaluate direction
                // (>12 pt total), fail if horizontal exceeds vertical displacement.
                // This lets scroll and diagonal gestures fall through cleanly.
                if dx + abs(dy) > 12 && dx > abs(dy) {
                    hasFailed = true
                    onOffsetChanged(0)
                    fireCancel()
                    return
                }

                if dy > 0 {
                    // Track peak downward velocity across the full gesture.
                    let vy = gesture.velocity(in: gesture.view).y
                    if vy > peakVelocity { peakVelocity = vy }
                    // Fire the entry haptic once when the gesture first passes the
                    // angle gate and is confirmed as a valid downward ThumbDrop.
                    if !entryHapticFired {
                        entryHapticFired = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    // Slingshot haptics: fire once as translation crosses each
                    // threshold. Back-and-forth movement does not re-trigger.
                    if dy >= 30 && !sling1Fired {
                        sling1Fired = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    if dy >= 60 && !sling2Fired {
                        sling2Fired = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    if dy >= 90 && !sling3Fired {
                        sling3Fired = true
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    }
                    // Dampen offset as the existing input bar gesture does.
                    onOffsetChanged(min(dy * 0.65, 60))
                } else if dy < 0, onUpwardCommit != nil {
                    // Moving upward — mirror of downward tracking, only when an
                    // upward commit handler is registered (e.g. cook mode bottom zone).
                    let vy = gesture.velocity(in: gesture.view).y
                    let vyUp = -vy  // positive magnitude of upward velocity
                    if vyUp > peakUpwardVelocity { peakUpwardVelocity = vyUp }
                    if !entryHapticFired {
                        entryHapticFired = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    if dy <= -30 && !slingUp1Fired {
                        slingUp1Fired = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    if dy <= -60 && !slingUp2Fired {
                        slingUp2Fired = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    if dy <= -90 && !slingUp3Fired {
                        slingUp3Fired = true
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    }
                    // Dampen upward offset symmetrically: negative value moves element up.
                    onOffsetChanged(max(dy * 0.65, -60))
                } else {
                    // Moving upward with no upward handler — keep element at rest.
                    onOffsetChanged(0)
                }

            case .ended:
                guard !hasFailed else { return }
                let translation = gesture.translation(in: gesture.view)
                let commitsDown = translation.y >= 50 || peakVelocity >= 400
                let commitsUp = translation.y <= -50 || peakUpwardVelocity >= 400
                if commitsDown {
                    onOffsetChanged(0)
                    onCommit()
                } else if commitsUp, let onUpwardCommit {
                    onOffsetChanged(0)
                    onUpwardCommit()
                } else {
                    fireCancel()
                }

            case .cancelled, .failed:
                fireCancel()

            default:
                break
            }
        }

        private func fireCancel() {
            guard !cancelFired else { return }
            cancelFired = true
            onCancel()
        }

        // MARK: - UIGestureRecognizerDelegate

        /// Reject the gesture before it begins if the touch did not start in the
        /// bottom fifth of the screen, or if ThumbDrop is currently inactive.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isActive else { return false }
            // location(in: nil) returns coordinates in the window — equivalent to
            // screen space on non-zoomed displays.
            let touchInWindow = gestureRecognizer.location(in: nil)
            let screenHeight = UIScreen.main.bounds.height
            return touchInWindow.y >= screenHeight * 0.75
        }

        /// Always allow simultaneous recognition so this gesture never steals
        /// taps, scroll-view pans, or long-press recognizers.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

// MARK: - ThumbDropHostView

/// A zero-height, non-interactive UIView whose sole job is lifecycle management:
/// when it enters the window hierarchy it installs the pan recognizer on the
/// window; when it leaves, it removes it.
///
/// The view itself never participates in hit-testing (`isUserInteractionEnabled`
/// is false), so it cannot block taps or gestures in underlying content.
final class ThumbDropHostView: UIView {
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
        // Remove from whatever window (or nil) it was on before.
        pan.view?.removeGestureRecognizer(pan)
        // Install on the new window if one exists.
        window?.addGestureRecognizer(pan)
    }
}

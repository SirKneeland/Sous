import SwiftUI
import UIKit

// MARK: - ThumbDropOverlay

/// Installs a `UIPanGestureRecognizer` at the window level so that ThumbDrop
/// can be triggered from anywhere in its trigger zone — by default the bottom
/// 15% of the screen — not just from the input bar row.
///
/// The UIView itself is non-interactive; gesture recognition happens at the
/// enclosing window, which is above all sibling views in the responder chain.
/// This means taps, scrolls, and long-presses in the chat transcript are never
/// blocked — `shouldRecognizeSimultaneouslyWith` returns `true` for every other
/// recognizer.
///
/// Usage: add as a `.background` on the root of the view that owns the zone. It
/// installs itself on `didMoveToWindow` and cleans up when that view goes away.
///
/// Every geometric and threshold value is a parameter whose default matches the
/// canvas↔chat behavior, so a new surface (e.g. a full-screen shade tracked
/// across the whole display) can reuse the same gesture engine and haptics.
struct ThumbDropOverlay: UIViewRepresentable {

    // MARK: Trigger zone

    /// Where a touch must *start* for ThumbDrop to engage. The zone gates only
    /// the beginning of the gesture; both commit directions work from any zone,
    /// including one pinned to the top of the screen.
    enum TriggerZone: Equatable {
        /// The bottom `fraction` of the screen. `0.15` is the bottom 15%.
        case bottomScreenFraction(CGFloat)
        /// A band `height` points tall, pinned to the top or bottom edge of the
        /// view this overlay is a `.background` of — for a grab bar or a
        /// dismiss zone inside a panel.
        case viewEdge(VerticalEdge, height: CGFloat)
    }

    /// Pass as `offsetClamp` to leave the visual offset effectively unlimited,
    /// so a caller can track a panel across the whole screen.
    static let unlimitedOffset: CGFloat = .infinity

    /// The default trigger zone: the bottom 15% of the screen.
    static let defaultZone: TriggerZone = .bottomScreenFraction(0.15)

    // MARK: Inputs

    /// True when ThumbDrop should be listening (e.g. the chat sheet is
    /// presented in non-fullscreen mode).
    var isActive: Bool
    /// Where a touch must start. Defaults to the bottom 15% of the screen.
    var triggerZone: TriggerZone = ThumbDropOverlay.defaultZone
    /// Magnitude cap on the offset reported to `onOffsetChanged`, in points.
    /// Defaults to 60. Use `ThumbDropOverlay.unlimitedOffset` for no cap.
    var offsetClamp: CGFloat = 60
    /// Fraction of raw translation reported as offset. Defaults to 0.65.
    var damping: CGFloat = 0.65
    /// Translation in points that commits the gesture. Defaults to 50.
    var commitDistance: CGFloat = 50
    /// Peak velocity in pt/s that commits the gesture. Defaults to 400.
    var commitVelocity: CGFloat = 400
    /// Called with the current drag offset as the gesture progresses, damped and
    /// clamped. Negative values mean the element is being dragged upward.
    var onOffsetChanged: (CGFloat) -> Void
    /// Called when the gesture commits downward: `commitDistance` down or
    /// `commitVelocity` peak downward velocity.
    var onCommit: () -> Void
    /// Called when the gesture cancels or fails — consumer should spring the element back.
    var onCancel: () -> Void
    /// Called when the gesture commits upward. Pass nil to disable upward
    /// tracking entirely (default) — upward drag then parks the element at rest
    /// and fires no haptics.
    var onUpwardCommit: (() -> Void)? = nil
    /// Called instead of onCommit when voice mode is active. Pass nil to use onCommit always.
    var onVoiceModeExit: (() -> Void)? = nil

    /// The geometry and thresholds, bundled for the coordinator.
    struct Config {
        var triggerZone: TriggerZone
        var offsetClamp: CGFloat
        var damping: CGFloat
        var commitDistance: CGFloat
        var commitVelocity: CGFloat
    }

    private var config: Config {
        Config(triggerZone: triggerZone,
               offsetClamp: offsetClamp,
               damping: damping,
               commitDistance: commitDistance,
               commitVelocity: commitVelocity)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isActive: isActive,
                    config: config,
                    onOffsetChanged: onOffsetChanged,
                    onCommit: onCommit,
                    onCancel: onCancel,
                    onUpwardCommit: onUpwardCommit,
                    onVoiceModeExit: onVoiceModeExit)
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
        // The coordinator needs the host view's window frame to resolve a
        // `.viewEdge` zone.
        context.coordinator.hostView = hostView
        return hostView
    }

    func updateUIView(_ uiView: ThumbDropHostView, context: Context) {
        context.coordinator.isActive = isActive
        context.coordinator.config = config
        context.coordinator.hostView = uiView
        context.coordinator.onOffsetChanged = onOffsetChanged
        context.coordinator.onCommit = onCommit
        context.coordinator.onCancel = onCancel
        context.coordinator.onUpwardCommit = onUpwardCommit
        context.coordinator.onVoiceModeExit = onVoiceModeExit
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isActive: Bool
        var config: Config
        var onOffsetChanged: (CGFloat) -> Void
        var onCommit: () -> Void
        var onCancel: () -> Void
        var onUpwardCommit: (() -> Void)?
        var onVoiceModeExit: (() -> Void)?
        /// Needed to resolve a `.viewEdge` trigger zone into window coordinates.
        weak var hostView: ThumbDropHostView?

        /// Set to true when the angle gate fires mid-gesture so we ignore
        /// subsequent `.changed` events and don't call `onCommit` at `.ended`.
        private var hasFailed = false
        /// Guards against calling `onCancel` more than once per gesture.
        private var cancelFired = false
        /// Entry tick plus the 30 / 60 / 90 pt escalating ladder, with separate
        /// gates per direction. Shared with the chat input bar's own gesture.
        private var ramp = SousHapticRamp()
        /// Peak downward velocity (pt/s) seen during .changed. End-state velocity
        /// is unreliable on fast flicks (reads negative at lift-off); peak is stable.
        private var peakVelocity: CGFloat = 0
        /// Peak upward velocity magnitude (pt/s). Stored as positive for easy comparison.
        private var peakUpwardVelocity: CGFloat = 0

        init(isActive: Bool,
             config: Config,
             onOffsetChanged: @escaping (CGFloat) -> Void,
             onCommit: @escaping () -> Void,
             onCancel: @escaping () -> Void,
             onUpwardCommit: (() -> Void)? = nil,
             onVoiceModeExit: (() -> Void)? = nil) {
            self.isActive = isActive
            self.config = config
            self.onOffsetChanged = onOffsetChanged
            self.onCommit = onCommit
            self.onCancel = onCancel
            self.onUpwardCommit = onUpwardCommit
            self.onVoiceModeExit = onVoiceModeExit
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                hasFailed = false
                cancelFired = false
                ramp.reset()
                // Warm the Taptic Engine so the entry tick lands immediately.
                ramp.prepare()
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
                    // Entry tick, then the escalating ladder. Each fires at most
                    // once per gesture; back-and-forth does not re-trigger.
                    ramp.update(travel: dy)
                    // Dampen offset as the existing input bar gesture does.
                    onOffsetChanged(min(dy * config.damping, config.offsetClamp))
                } else if dy < 0, onUpwardCommit != nil {
                    // Moving upward — mirror of downward tracking, only when an
                    // upward commit handler is registered (e.g. cook mode bottom zone).
                    let vy = gesture.velocity(in: gesture.view).y
                    let vyUp = -vy  // positive magnitude of upward velocity
                    if vyUp > peakUpwardVelocity { peakUpwardVelocity = vyUp }
                    ramp.update(travel: dy)
                    // Dampen upward offset symmetrically: negative value moves element up.
                    onOffsetChanged(max(dy * config.damping, -config.offsetClamp))
                } else {
                    // Moving upward with no upward handler — keep element at rest.
                    onOffsetChanged(0)
                }

            case .ended:
                guard !hasFailed else { return }
                let translation = gesture.translation(in: gesture.view)
                let commitsDown = translation.y >= config.commitDistance
                    || peakVelocity >= config.commitVelocity
                let commitsUp = translation.y <= -config.commitDistance
                    || peakUpwardVelocity >= config.commitVelocity
                if commitsDown {
                    onOffsetChanged(0)
                    if let onVoiceModeExit {
                        onVoiceModeExit()
                    } else {
                        onCommit()
                    }
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

        /// Reject the gesture before it begins if the touch did not start inside
        /// the trigger zone, or if ThumbDrop is currently inactive.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isActive else { return false }
            // location(in: nil) returns coordinates in the window — equivalent to
            // screen space on non-zoomed displays.
            let touchInWindow = gestureRecognizer.location(in: nil)
            switch config.triggerZone {
            case .bottomScreenFraction(let fraction):
                let screenHeight = UIScreen.main.bounds.height
                return touchInWindow.y >= screenHeight * (1 - fraction)
            case .viewEdge(let edge, let height):
                guard let hostView, let window = hostView.window else { return false }
                let frame = hostView.convert(hostView.bounds, to: window)
                guard frame.height > 0 else { return false }
                switch edge {
                case .top:
                    return touchInWindow.y >= frame.minY
                        && touchInWindow.y <= min(frame.minY + height, frame.maxY)
                case .bottom:
                    return touchInWindow.y >= max(frame.maxY - height, frame.minY)
                        && touchInWindow.y <= frame.maxY
                @unknown default:
                    return false
                }
            }
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

/// A non-interactive UIView whose jobs are lifecycle management — when it enters
/// the window hierarchy it installs the pan recognizer on the window, and when it
/// leaves, it removes it — and supplying its own window frame for a `.viewEdge`
/// trigger zone.
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

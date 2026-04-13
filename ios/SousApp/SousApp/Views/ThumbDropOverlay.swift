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
    /// Called with the current drag offset (0–60 pt) as the gesture progresses.
    var onOffsetChanged: (CGFloat) -> Void
    /// Called when the gesture commits: ≥20 pt downward, predominantly vertical.
    var onCommit: () -> Void
    /// Called when the gesture cancels or fails — consumer should spring the input bar back.
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isActive: isActive,
                    onOffsetChanged: onOffsetChanged,
                    onCommit: onCommit,
                    onCancel: onCancel)
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
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isActive: Bool
        var onOffsetChanged: (CGFloat) -> Void
        var onCommit: () -> Void
        var onCancel: () -> Void

        /// Set to true when the angle gate fires mid-gesture so we ignore
        /// subsequent `.changed` events and don't call `onCommit` at `.ended`.
        private var hasFailed = false
        /// Guards against calling `onCancel` more than once per gesture.
        private var cancelFired = false
        /// Guards against firing the entry haptic more than once per gesture.
        private var entryHapticFired = false

        init(isActive: Bool,
             onOffsetChanged: @escaping (CGFloat) -> Void,
             onCommit: @escaping () -> Void,
             onCancel: @escaping () -> Void) {
            self.isActive = isActive
            self.onOffsetChanged = onOffsetChanged
            self.onCommit = onCommit
            self.onCancel = onCancel
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                hasFailed = false
                cancelFired = false
                entryHapticFired = false

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
                    // Fire the entry haptic once when the gesture first passes the
                    // angle gate and is confirmed as a valid downward ThumbDrop.
                    if !entryHapticFired {
                        entryHapticFired = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    // Dampen offset as the existing input bar gesture does.
                    onOffsetChanged(min(dy * 0.65, 60))
                } else {
                    // Moving upward — keep input bar at rest.
                    onOffsetChanged(0)
                }

            case .ended:
                guard !hasFailed else { return }
                let translation = gesture.translation(in: gesture.view)
                if translation.y >= 20 {
                    onOffsetChanged(0)
                    onCommit()
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
            return touchInWindow.y >= screenHeight * 0.7
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

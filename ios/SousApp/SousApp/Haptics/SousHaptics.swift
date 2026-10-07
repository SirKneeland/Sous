import UIKit

// MARK: - SousHaptics

/// The single entry point for every haptic in Sous.
///
/// Generators are cached per style rather than created per tap, so that
/// `prepare()` can warm the Taptic Engine before a latency-sensitive moment
/// (the first tick of a drag ramp, for instance) and keep it warm for the
/// duration of the gesture. Firing without a preceding `prepare()` behaves
/// exactly as a freshly constructed generator does.
///
/// All calls must happen on the main thread. Every current caller is either a
/// SwiftUI closure or a UIKit gesture callback, both of which already are —
/// hence the `nonisolated(unsafe)` storage rather than `@MainActor`, which
/// would be unreachable from `ThumbDropOverlay`'s `@objc` gesture handler.
enum SousHaptics {
    typealias ImpactStyle = UIImpactFeedbackGenerator.FeedbackStyle
    typealias NotificationType = UINotificationFeedbackGenerator.FeedbackType

    nonisolated(unsafe) private static var impactGenerators: [Int: UIImpactFeedbackGenerator] = [:]
    nonisolated(unsafe) private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Fires an impact tick.
    static func impact(_ style: ImpactStyle) {
        impactGenerator(for: style).impactOccurred()
    }

    /// Fires a notification haptic (success / warning / error).
    static func notify(_ type: NotificationType) {
        notificationGenerator.notificationOccurred(type)
    }

    /// Warms the Taptic Engine for the given impact styles. Call at the start of
    /// a gesture so the first tick lands without engine spin-up latency.
    static func prepare(_ styles: ImpactStyle...) {
        prepare(styles)
    }

    static func prepare(_ styles: [ImpactStyle]) {
        for style in styles { impactGenerator(for: style).prepare() }
    }

    /// Warms the Taptic Engine for notification haptics.
    static func prepareNotification() {
        notificationGenerator.prepare()
    }

    private static func impactGenerator(for style: ImpactStyle) -> UIImpactFeedbackGenerator {
        if let existing = impactGenerators[style.rawValue] { return existing }
        let generator = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style.rawValue] = generator
        return generator
    }
}

// MARK: - SousHapticRamp

/// An escalating, one-shot haptic ladder for drag gestures: an optional entry
/// tick when travel first begins, then one tick per distance threshold crossed.
///
/// Each step fires **at most once per gesture** — reverse travel does not
/// re-trigger a step that already fired. Call `reset()` at the start of every
/// new gesture and `update(travel:)` on every change, where `travel` is signed
/// (positive is downward).
///
/// Two shapes are in use today:
/// - `ThumbDropOverlay` uses the default: an entry tick, and separate gate sets
///   per direction, so a drag that reverses can climb the ladder the other way.
/// - The chat input bar's own `DragGesture` uses `entryStyle: nil,
///   directional: false`: no entry tick, and one gate set keyed on absolute
///   travel, so reversing direction does not re-fire anything.
struct SousHapticRamp {
    struct Step {
        let distance: CGFloat
        let style: SousHaptics.ImpactStyle

        init(_ distance: CGFloat, _ style: SousHaptics.ImpactStyle) {
            self.distance = distance
            self.style = style
        }
    }

    /// ThumbDrop's ladder: 30pt light, 60pt medium, 90pt rigid.
    static let thumbDropSteps: [Step] = [
        Step(30, .light),
        Step(60, .medium),
        Step(90, .rigid),
    ]

    private let steps: [Step]
    private let entryStyle: SousHaptics.ImpactStyle?
    private let directional: Bool

    private var entryFired = false
    private var downFired: [Bool]
    private var upFired: [Bool]

    init(steps: [Step] = SousHapticRamp.thumbDropSteps,
         entryStyle: SousHaptics.ImpactStyle? = .light,
         directional: Bool = true) {
        self.steps = steps
        self.entryStyle = entryStyle
        self.directional = directional
        self.downFired = Array(repeating: false, count: steps.count)
        self.upFired = Array(repeating: false, count: steps.count)
    }

    /// Clears every gate. Call once per new gesture.
    mutating func reset() {
        entryFired = false
        downFired = Array(repeating: false, count: steps.count)
        upFired = Array(repeating: false, count: steps.count)
    }

    /// Warms the Taptic Engine for every style this ramp can fire.
    func prepare() {
        var styles = steps.map(\.style)
        if let entryStyle { styles.append(entryStyle) }
        SousHaptics.prepare(styles)
    }

    /// Advances the ramp. `travel` is signed drag translation in points;
    /// positive is downward.
    mutating func update(travel: CGFloat) {
        guard travel != 0 else { return }

        if let entryStyle, !entryFired {
            entryFired = true
            SousHaptics.impact(entryStyle)
        }

        let distance = abs(travel)
        let upward = directional && travel < 0
        for index in steps.indices where distance >= steps[index].distance {
            if upward {
                guard !upFired[index] else { continue }
                upFired[index] = true
            } else {
                guard !downFired[index] else { continue }
                downFired[index] = true
            }
            SousHaptics.impact(steps[index].style)
        }
    }
}

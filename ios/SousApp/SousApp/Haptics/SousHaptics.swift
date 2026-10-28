import UIKit

// MARK: - SousHaptic

/// What a haptic *means*, rather than which generator it uses.
///
/// Sous chose its taps the way it once chose its colours: a style picked at each
/// call site, independently, by whoever wrote it. That produced one `.medium` for
/// a button press, a gesture committing, a long press firing and a toast arriving
/// — four unrelated events that happen to feel identical, and no record anywhere
/// of whether that was intended.
///
/// So the scale is named for the event. Several roles resolve to the same UIKit
/// style, exactly as several semantic colours resolve to the same primitive; what
/// matters is that two things which should feel alike are written as the same
/// role, and two things that merely happen to share a style are not.
///
/// Adding a role is a design decision — log it in `design/TOKEN-DECISIONS.md`.
/// See decision 27.
enum SousHaptic {
    /// A small choice registering: a duration tapped in a step, a secondary
    /// button, ACCEPT on the review bar.
    case selection
    /// A control firing — the bottom bar being pressed, a long press completing.
    case activation
    /// A gesture reaching its end and being honoured. ThumbDrop, the shade.
    case commit
    /// Something settling into place after it was let go. The shade landing.
    case land
    /// An affordance appearing under the finger mid-gesture. The shade's peek.
    case reveal
    /// Crossing a threshold that will change what happens on release.
    case detentEngage
    /// Falling back below that threshold again.
    case detentRelease
    /// Something arriving that the user did not ask for right then — the memory
    /// toast. Deliberately not `activation`: nothing was pressed.
    case notice
    /// Work finished successfully. A memory saved.
    case confirm
    /// The action was refused — a timer still running, three timers already going.
    case blocked
}

// MARK: - SousHaptics

/// The single entry point for every haptic in Sous.
///
/// Generators are cached per style rather than created per tap, so that
/// `prepare` can warm the Taptic Engine before a latency-sensitive moment (the
/// first tick of a drag ramp, for instance) and keep it warm for the duration of
/// the gesture. Firing without a preceding `prepare` behaves exactly as a freshly
/// constructed generator does.
///
/// The UIKit styles are `fileprivate` on purpose: the compiler, not a convention,
/// is what stops a view reaching past the scale and picking an intensity. The
/// check script backs that up by failing on a feedback generator built anywhere
/// but here.
///
/// All calls must happen on the main thread. Every current caller is either a
/// SwiftUI closure or a UIKit gesture callback, both of which already are — hence
/// the `nonisolated(unsafe)` storage rather than `@MainActor`, which would be
/// unreachable from `ThumbDropOverlay`'s `@objc` gesture handler.
enum SousHaptics {
    nonisolated(unsafe) private static var impactGenerators: [Int: UIImpactFeedbackGenerator] = [:]
    nonisolated(unsafe) private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Fires a haptic for what just happened.
    static func play(_ haptic: SousHaptic) {
        switch haptic.feedback {
        case .impact(let style): impactGenerator(for: style).impactOccurred()
        case .notification(let type): notificationGenerator.notificationOccurred(type)
        }
    }

    /// Warms the Taptic Engine for the given roles. Call at the start of a gesture
    /// so the first tick lands without engine spin-up latency.
    static func prepare(_ haptics: SousHaptic...) {
        prepare(haptics)
    }

    static func prepare(_ haptics: [SousHaptic]) {
        for haptic in haptics {
            switch haptic.feedback {
            case .impact(let style): impactGenerator(for: style).prepare()
            case .notification: notificationGenerator.prepare()
            }
        }
    }

    private static func impactGenerator(
        for style: UIImpactFeedbackGenerator.FeedbackStyle
    ) -> UIImpactFeedbackGenerator {
        if let existing = impactGenerators[style.rawValue] { return existing }
        let generator = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style.rawValue] = generator
        return generator
    }
}

// MARK: - The scale

fileprivate enum SousFeedback {
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(UINotificationFeedbackGenerator.FeedbackType)
}

fileprivate extension SousHaptic {
    /// The one place a role becomes an intensity. Every value here was the style
    /// already in use at the call sites that role replaced, so the app feels
    /// exactly as it did — the scale records the decisions rather than changing them.
    var feedback: SousFeedback {
        switch self {
        case .selection:      return .impact(.light)
        case .activation:     return .impact(.medium)
        case .commit:         return .impact(.medium)
        case .land:           return .impact(.light)
        case .reveal:         return .impact(.soft)
        case .detentEngage:   return .impact(.rigid)
        case .detentRelease:  return .impact(.light)
        case .notice:         return .impact(.medium)
        case .confirm:        return .notification(.success)
        case .blocked:        return .notification(.error)
        }
    }
}

// MARK: - SousHapticRamp

/// An escalating, one-shot haptic ladder for drag gestures: an optional entry
/// tick when travel begins, then one tick per distance threshold crossed.
///
/// The ladder is deliberately *not* expressed in roles. It is one event — "a drag
/// is building" — whose steps are an intensity curve, and naming each rung would
/// be inventing three roles that mean nothing on their own. Callers choose the
/// entry tick and the direction handling; the curve itself is fixed.
///
/// Each step fires **at most once per gesture** — reverse travel does not
/// re-trigger a step that already fired. Call `reset()` at the start of every new
/// gesture and `update(travel:)` on every change, where `travel` is signed
/// (positive is downward).
///
/// Two shapes are in use today:
/// - `ThumbDropOverlay` uses the default: an entry tick, and separate gate sets
///   per direction, so a drag that reverses can climb the ladder the other way.
/// - The chat input bar's own `DragGesture` uses `playsEntryTick: false,
///   directional: false`: no entry tick, and one gate set keyed on absolute
///   travel, so reversing direction does not re-fire anything.
struct SousHapticRamp {
    fileprivate struct Step {
        let distance: CGFloat
        let style: UIImpactFeedbackGenerator.FeedbackStyle
    }

    /// 30pt light, 60pt medium, 90pt rigid.
    fileprivate static let steps: [Step] = [
        Step(distance: 30, style: .light),
        Step(distance: 60, style: .medium),
        Step(distance: 90, style: .rigid),
    ]

    private let playsEntryTick: Bool
    private let directional: Bool

    private var entryFired = false
    private var downFired: [Bool]
    private var upFired: [Bool]

    init(playsEntryTick: Bool = true, directional: Bool = true) {
        self.playsEntryTick = playsEntryTick
        self.directional = directional
        self.downFired = Array(repeating: false, count: Self.steps.count)
        self.upFired = Array(repeating: false, count: Self.steps.count)
    }

    /// Clears every gate. Call once per new gesture.
    mutating func reset() {
        entryFired = false
        downFired = Array(repeating: false, count: Self.steps.count)
        upFired = Array(repeating: false, count: Self.steps.count)
    }

    /// Warms the Taptic Engine for every rung of the ladder.
    func prepare() {
        SousHaptics.prepareRamp()
    }

    /// Advances the ramp. `travel` is signed drag translation in points;
    /// positive is downward.
    mutating func update(travel: CGFloat) {
        guard travel != 0 else { return }

        if playsEntryTick, !entryFired {
            entryFired = true
            SousHaptics.fireRamp(.light)
        }

        let distance = abs(travel)
        let upward = directional && travel < 0
        for index in Self.steps.indices where distance >= Self.steps[index].distance {
            if upward {
                guard !upFired[index] else { continue }
                upFired[index] = true
            } else {
                guard !downFired[index] else { continue }
                downFired[index] = true
            }
            SousHaptics.fireRamp(Self.steps[index].style)
        }
    }
}

extension SousHaptics {
    /// The ramp's own door into the generators. Not part of the scale — see the
    /// note on `SousHapticRamp` for why the ladder is an intensity curve rather
    /// than a set of roles.
    fileprivate static func fireRamp(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        impactGenerator(for: style).impactOccurred()
    }

    fileprivate static func prepareRamp() {
        for step in SousHapticRamp.steps { impactGenerator(for: step.style).prepare() }
        impactGenerator(for: .light).prepare()
    }
}

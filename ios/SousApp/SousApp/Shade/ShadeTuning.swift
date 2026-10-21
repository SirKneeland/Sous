import SwiftUI
import UIKit

// MARK: - ShadeMetrics

/// Fixed geometry the shade depends on, as opposed to the tunable feel.
enum ShadeMetrics {
    /// The shade covers the whole screen, safe areas included, so neither it nor
    /// the gesture driving it can read the insets from a `GeometryReader` that
    /// respects them.
    static var windowInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets ?? .zero
    }

    /// How far the shade has to travel for its hem to be fully legible.
    ///
    /// Three parts, all of them necessary: the status bar the bar has to clear,
    /// the bar itself, and the burgundy strip below it that reaches the bottom of
    /// the screen when the shade is open. That strip is the panel's real bottom
    /// edge, so leaving it out puts RECIPES behind the clock.
    static var peekTravel: CGFloat {
        windowInsets.top + SousGrabBar.height + windowInsets.bottom
    }
}

// MARK: - ShadeTuningValues

/// Every number the window shade's feel depends on, in one struct.
///
/// These are **motion**, and Sous's design system has no motion tokens yet
/// (Milestone 32). They deliberately do not live in `design/tokens.json` and are
/// not a numbered decision: they are debug tunables until they have been felt on
/// a real device, at which point whichever survive become motion tokens.
struct ShadeTuningValues {
    // MARK: The pull that opens it

    /// Points of downward pull past which releasing commits.
    var pullCommitDistance: CGFloat = Defaults.pullCommitDistance
    /// Peak downward velocity (pt/s) that commits regardless of distance. Higher
    /// than ThumbDrop's 400 on purpose — a quick flick at the top of the list is
    /// how people bounce it, and that must not open the shade.
    var pullCommitVelocity: CGFloat = Defaults.pullCommitVelocity
    /// Fraction of further finger travel the shade follows once the peek is out.
    var pullResistance: CGFloat = Defaults.pullResistance
    /// Points of pull over which the peek eases fully into view. The soft tick
    /// fires here, and nothing is shown or felt before it.
    var peekAppearDistance: CGFloat = Defaults.peekAppearDistance

    // MARK: The pull that opens it from the bottom bar

    // The bar sits about 90pt from the bottom of the glass, so a thumb starting on
    // it simply cannot travel the canvas pull's distance — it runs out of screen.
    // Hence its own, shorter set. Resistance, springs and the peek curve are shared.
    //
    // The peek therefore comes out faster here than it does from the canvas: the
    // same ~145pt of shade travel, over 35pt of thumb instead of 90. It reads as the
    // hem snapping out rather than being drawn out, which is the right trade when
    // the whole gesture has to finish inside 60pt.

    var barPullCommitDistance: CGFloat = Defaults.barPullCommitDistance
    var barPullCommitVelocity: CGFloat = Defaults.barPullCommitVelocity
    var barPeekAppearDistance: CGFloat = Defaults.barPeekAppearDistance

    /// This same tuning with the bar's three distances swapped in, so the gesture
    /// itself needs no idea which entry point it is serving.
    var forBarPull: ShadeTuningValues {
        var copy = self
        copy.pullCommitDistance = barPullCommitDistance
        copy.pullCommitVelocity = barPullCommitVelocity
        copy.peekAppearDistance = barPeekAppearDistance
        return copy
    }

    // MARK: The springs

    var openResponse: Double = Defaults.openResponse
    var openDamping: Double = Defaults.openDamping
    var closeResponse: Double = Defaults.closeResponse
    var closeDamping: Double = Defaults.closeDamping

    // MARK: The swipe that dismisses it

    /// Height of the ThumbDrop zone at the bottom of the open shade.
    var dismissZoneHeight: CGFloat = Defaults.dismissZoneHeight
    var dismissCommitDistance: CGFloat = Defaults.dismissCommitDistance
    var dismissCommitVelocity: CGFloat = Defaults.dismissCommitVelocity

    var openAnimation: Animation {
        .spring(response: openResponse, dampingFraction: openDamping)
    }

    var closeAnimation: Animation {
        .spring(response: closeResponse, dampingFraction: closeDamping)
    }

    /// How far the shade has travelled for a given raw downward pull.
    ///
    /// Two segments. Up to `peekAppearDistance` the peek eases out with a
    /// smoothstep, so the grab bar is exactly fully visible — and legible — at the
    /// moment the soft tick fires, rather than half-clipped by the top of the
    /// screen. Past that, further pull is followed at `pullResistance`.
    func travel(forPull pull: CGFloat) -> CGFloat {
        travel(forPull: pull, peekTravel: ShadeMetrics.peekTravel)
    }

    /// Testable form. `peekTravel` depends on the device's safe area, so tests pass
    /// it explicitly rather than depending on whichever window the host has.
    func travel(forPull pull: CGFloat, peekTravel: CGFloat) -> CGFloat {
        let raw = max(0, pull)
        let t = min(1, raw / max(1, peekAppearDistance))
        let eased = t * t * (3 - 2 * t)
        return peekTravel * eased + max(0, raw - peekAppearDistance) * pullResistance
    }

    // MARK: Defaults

    enum Defaults {
        static let pullCommitDistance: CGFloat = 160
        static let pullCommitVelocity: CGFloat = 1000
        static let pullResistance: CGFloat = 0.55
        static let peekAppearDistance: CGFloat = 90
        // ThumbDrop's own numbers, which this gesture used to carry when it opened
        // chat from the same bar — the sensitivity was already right, only the
        // destination changed. The peek has to be fully out well before the commit,
        // so it lands at a little over half the distance.
        static let barPullCommitDistance: CGFloat = 60
        static let barPullCommitVelocity: CGFloat = 400
        static let barPeekAppearDistance: CGFloat = 35
        static let openResponse: Double = 0.42
        static let openDamping: Double = 0.86
        static let closeResponse: Double = 0.34
        static let closeDamping: Double = 0.90
        static let dismissZoneHeight: CGFloat = 96
        static let dismissCommitDistance: CGFloat = 60
        static let dismissCommitVelocity: CGFloat = 500
    }
}

// MARK: - ShadeTuning

/// The `@AppStorage` keys behind `ShadeTuningValues`, and the ranges the debug
/// sliders offer. TEMP — this whole type goes when motion tokens land.
enum ShadeTuning {
    /// The feature switch. Off restores the hamburger everywhere and removes the
    /// pull-down entirely.
    static let enabledKey = "debugShadeNavigation"

    static let pullCommitDistanceKey = "debugShadePullCommitDistance"
    static let pullCommitVelocityKey = "debugShadePullCommitVelocity"
    static let pullResistanceKey = "debugShadePullResistance"
    static let peekAppearDistanceKey = "debugShadePeekAppearDistance"
    static let barPullCommitDistanceKey = "debugShadeBarPullCommitDistance"
    static let barPullCommitVelocityKey = "debugShadeBarPullCommitVelocity"
    static let barPeekAppearDistanceKey = "debugShadeBarPeekAppearDistance"
    static let openResponseKey = "debugShadeOpenResponse"
    static let openDampingKey = "debugShadeOpenDamping"
    static let closeResponseKey = "debugShadeCloseResponse"
    static let closeDampingKey = "debugShadeCloseDamping"
    static let dismissZoneHeightKey = "debugShadeDismissZoneHeight"
    static let dismissCommitDistanceKey = "debugShadeDismissCommitDistance"
    static let dismissCommitVelocityKey = "debugShadeDismissCommitVelocity"

    /// Key, label, default, and slider range — the Settings section is generated
    /// from this so a new tunable is one line.
    struct Slider: Identifiable {
        let key: String
        let label: String
        let value: Double
        let range: ClosedRange<Double>
        let unit: String
        var id: String { key }
    }

    static let sliders: [Slider] = [
        .init(key: pullCommitDistanceKey, label: "Pull commit distance",
              value: Double(ShadeTuningValues.Defaults.pullCommitDistance), range: 60...360, unit: "pt"),
        .init(key: pullCommitVelocityKey, label: "Pull commit velocity",
              value: Double(ShadeTuningValues.Defaults.pullCommitVelocity), range: 200...2500, unit: "pt/s"),
        .init(key: pullResistanceKey, label: "Pull resistance",
              value: Double(ShadeTuningValues.Defaults.pullResistance), range: 0.15...1, unit: "×"),
        .init(key: peekAppearDistanceKey, label: "Peek label appear distance",
              value: Double(ShadeTuningValues.Defaults.peekAppearDistance), range: 16...200, unit: "pt"),
        .init(key: barPullCommitDistanceKey, label: "Bar pull commit distance",
              value: Double(ShadeTuningValues.Defaults.barPullCommitDistance), range: 25...160, unit: "pt"),
        .init(key: barPullCommitVelocityKey, label: "Bar pull commit velocity",
              value: Double(ShadeTuningValues.Defaults.barPullCommitVelocity), range: 150...1500, unit: "pt/s"),
        .init(key: barPeekAppearDistanceKey, label: "Bar peek appear distance",
              value: Double(ShadeTuningValues.Defaults.barPeekAppearDistance), range: 10...120, unit: "pt"),
        .init(key: openResponseKey, label: "Open spring response",
              value: ShadeTuningValues.Defaults.openResponse, range: 0.1...1, unit: "s"),
        .init(key: openDampingKey, label: "Open spring damping",
              value: ShadeTuningValues.Defaults.openDamping, range: 0.4...1, unit: ""),
        .init(key: closeResponseKey, label: "Close spring response",
              value: ShadeTuningValues.Defaults.closeResponse, range: 0.1...1, unit: "s"),
        .init(key: closeDampingKey, label: "Close spring damping",
              value: ShadeTuningValues.Defaults.closeDamping, range: 0.4...1, unit: ""),
        .init(key: dismissZoneHeightKey, label: "Dismiss zone height",
              value: Double(ShadeTuningValues.Defaults.dismissZoneHeight), range: 40...240, unit: "pt"),
        .init(key: dismissCommitDistanceKey, label: "Dismiss commit distance",
              value: Double(ShadeTuningValues.Defaults.dismissCommitDistance), range: 20...200, unit: "pt"),
        .init(key: dismissCommitVelocityKey, label: "Dismiss commit velocity",
              value: Double(ShadeTuningValues.Defaults.dismissCommitVelocity), range: 150...1500, unit: "pt/s"),
    ]

    /// Clears every stored tunable so `@AppStorage` falls back to its declared
    /// default. Does not touch the feature switch.
    static func resetToDefaults() {
        for slider in sliders {
            UserDefaults.standard.removeObject(forKey: slider.key)
        }
    }
}

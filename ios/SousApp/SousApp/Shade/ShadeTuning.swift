import SwiftUI
import UIKit

// MARK: - ShadeMetrics

/// Fixed geometry the shade depends on, as opposed to the feel of the gesture.
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

// MARK: - ShadeGesture

/// The distances and velocities that decide how the window shade responds to a
/// finger. **Gesture, not motion** — the springs live in `SousMotion`.
///
/// These were eleven live sliders in the Settings DEBUG section for three weeks,
/// which is how they were arrived at: tuned on a device, by thumb, rather than
/// guessed in a simulator. The sliders are gone and the values they settled on are
/// the defaults below. See decision 29.
///
/// They are deliberately *not* in `tokens.json`. A commit velocity in points per
/// second is not a design token in any sense Figma or another platform would
/// recognise; it is this gesture's calibration, and it belongs with the gesture.
struct ShadeGesture {
    // MARK: The pull that opens it, from the canvas

    /// Points of downward pull past which releasing commits.
    var pullCommitDistance: CGFloat = 160
    /// Peak downward velocity (pt/s) that commits regardless of distance. Higher
    /// than ThumbDrop's 400 on purpose — a quick flick at the top of the list is
    /// how people bounce it, and that must not open the shade.
    var pullCommitVelocity: CGFloat = 1000
    /// Fraction of further finger travel the shade follows once the peek is out.
    var pullResistance: CGFloat = 0.55
    /// Points of pull over which the peek eases fully into view. The soft tick
    /// fires here, and nothing is shown or felt before it.
    var peekAppearDistance: CGFloat = 90

    // MARK: The pull that opens it, from a grab bar

    // A thumb on the Talk to Sous bar has about 90pt of glass beneath it, so it
    // simply cannot travel the canvas pull's distance — it runs out of screen.
    // Hence its own, shorter set, shared with the explore screen's grab bar.
    // Resistance, the springs and the peek curve are shared.
    //
    // The peek therefore comes out faster here: the same ~145pt of shade travel
    // over 35pt of thumb instead of 90. It reads as the hem snapping out rather
    // than being drawn out, which is the right trade when the whole gesture has to
    // finish inside 60pt.

    var barPullCommitDistance: CGFloat = 60
    var barPullCommitVelocity: CGFloat = 400
    var barPeekAppearDistance: CGFloat = 35

    // MARK: The swipe that dismisses it

    /// Height of the ThumbDrop zone at the bottom of the open shade.
    var dismissZoneHeight: CGFloat = 96
    var dismissCommitDistance: CGFloat = 60
    var dismissCommitVelocity: CGFloat = 500

    /// This same calibration with the bar's three distances swapped in, so the
    /// gesture itself needs no idea which entry point it is serving.
    var forBarPull: ShadeGesture {
        var copy = self
        copy.pullCommitDistance = barPullCommitDistance
        copy.pullCommitVelocity = barPullCommitVelocity
        copy.peekAppearDistance = barPeekAppearDistance
        return copy
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
}

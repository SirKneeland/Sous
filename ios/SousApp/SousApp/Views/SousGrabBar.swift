import SwiftUI

// MARK: - SousGrabBar

/// A full-bleed burgundy bar carrying a chevron and an optional label: the handle
/// of a panel that slides in from an edge of the screen.
///
/// Two things make it its own component rather than a `SousButton` variant:
/// it is **full-bleed** — a hem on a sliding panel has no gutters, where every
/// Sous button sits inside the 20pt margin — and it is **directional**, because
/// the same bar has to say "pull me down" at the bottom of a peeking shade and
/// "push me back up" once that shade is open.
///
/// Used today at the bottom of the window shade, pointing down while the shade is
/// being pulled and up once it is open. The explore screen's grab bar (next build)
/// is the same component at the top of the screen, pointing down.
///
/// Matches the Figma **Grab Bar** component. See decision 26 in
/// `design/TOKEN-DECISIONS.md`.
struct SousGrabBar: View {
    /// Which way the chevron points — the direction the panel will travel.
    enum Direction {
        case up, down

        var symbol: String {
            switch self {
            case .up:   return "chevron.up"
            case .down: return "chevron.down"
            }
        }
    }

    /// Which edge of its container the bar is pinned to. Decides which side the
    /// hairline rule sits on: always the side facing the panel's content.
    enum Edge {
        case top, bottom
    }

    /// Shown beside the chevron, ALL CAPS. Omit for a bar that is pure affordance.
    var title: String? = nil
    var direction: Direction
    var edge: Edge = .bottom
    /// What VoiceOver reads. The visible label says what is behind the bar;
    /// this says what tapping it does.
    var accessibilityActionLabel: String
    let action: () -> Void

    /// Matches the Talk to Sous bar, so the two read as the same furniture.
    static let height: CGFloat = SousSize.control

    // MARK: - Lockup

    /// The chevron and label on their own, with no fill and no rule.
    ///
    /// Split out because the window shade draws exactly this while it is being
    /// pulled: the whole panel is one burgundy sheet then, so a bar drawn around
    /// the label would only add a seam. Sharing the lockup keeps the two from
    /// drifting — the label must not move by a pixel when the sheet becomes the
    /// real panel underneath it.
    struct Lockup: View {
        var title: String?
        var direction: Direction

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: direction.symbol)
                    .font(.sousIcon(.small, weight: .semibold))
                if let title {
                    Text(title.uppercased())
                        .font(.sousButton)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: SousGrabBar.height)
        }
    }

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            if edge == .bottom { SousRule() }

            Button(action: action) {
                Lockup(title: title, direction: direction)
            }
            .buttonStyle(PressReportingStyle(isPressed: $isPressed))
            .background(isPressed ? Color.sousPressedAccent : Color.sousTerracotta)

            if edge == .top { SousRule() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityActionLabel)
    }
}

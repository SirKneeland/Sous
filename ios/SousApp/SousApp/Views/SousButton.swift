import SwiftUI

// MARK: - SousButtonStyle

/// The five button styles Sous draws, matching the Figma **Button** component.
///
/// Sous had no shared button for a long time, so roughly forty call sites each
/// assembled their own fill, border and padding around `Font.sousButton`. That is
/// what produced five near-identical styles and three inconsistencies. These are
/// the styles that survived the audit — anything outside them is a design decision,
/// not a new case to add here.
enum SousButtonStyle {
    /// Burgundy fill, white label. The main action on a screen.
    case primary
    /// Ink fill that flips to cream in dark mode. Confirming.
    case inverse
    /// 1pt ink border, no fill.
    case secondary
    /// 1pt burgundy border, no fill.
    case secondaryAccent
    /// Burgundy label only. Cancel, Reject.
    case text

    fileprivate func fill(enabled: Bool) -> Color {
        switch self {
        case .primary:         return .sousTerracotta
        case .inverse:         return enabled ? .sousText : .sousMuted
        case .secondary,
             .secondaryAccent,
             .text:            return .clear
        }
    }

    fileprivate func border(enabled: Bool) -> Color? {
        switch self {
        case .primary, .inverse, .text: return nil
        case .secondary:                return .sousText
        case .secondaryAccent:          return .sousTerracotta
        }
    }

    fileprivate func label(enabled: Bool) -> Color {
        switch self {
        // Labels on burgundy are white in both modes (decided 2026-09-20): the
        // burgundy does not invert, so a label that did would go near-black in dark.
        case .primary:         return .white
        case .inverse:         return .sousBackground
        case .secondary:       return enabled ? .sousText : .sousMuted
        case .secondaryAccent,
             .text:            return .sousTerracotta
        }
    }
}

// MARK: - SousButtonLabel

/// The visual half of a Sous button, without the tap handling.
///
/// Separate from `SousButton` because some call sites supply their own control —
/// `ShareLink` on the cap-reached screen, for one — and still need to look like a
/// button. Labels are always ALL CAPS; the type token carries no letter-spacing.
/// Just the icon and words — no fill, no border, no sizing.
///
/// Split out from the chrome because SwiftUI's `.disabled()` dims a button's *label*.
/// Since the style already encodes the disabled look (a muted fill, a muted label), letting
/// the dimming land on the fill too washes it out — which is exactly what happened when the
/// fill briefly lived inside the label. Chrome therefore wraps the button; the label does not
/// carry it.
private struct SousButtonContent: View {
    let title: String
    let style: SousButtonStyle
    let isEnabled: Bool
    let icon: String?
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isBusy {
                ProgressView().tint(style.label(enabled: isEnabled))
            } else {
                if let icon {
                    Image(systemName: icon)
                        .font(.sousIcon(.medium, weight: .semibold))
                }
                Text(title)
                    .font(.sousButton)
            }
        }
        .foregroundStyle(style.label(enabled: isEnabled))
    }
}

/// Sizing, fill and border. Applied outside the button so `.disabled()` cannot dim it.
private struct SousButtonChrome: ViewModifier {
    let style: SousButtonStyle
    let isEnabled: Bool
    let height: CGFloat?
    let verticalPadding: CGFloat
    let fillsWidth: Bool
    let horizontalPadding: CGFloat

    func body(content: Content) -> some View {
        sized(width(content))
            .background(style.fill(enabled: isEnabled))
            .overlay {
                if let border = style.border(enabled: isEnabled) {
                    Rectangle().stroke(border, lineWidth: 1)
                }
            }
    }

    @ViewBuilder
    private func width<V: View>(_ content: V) -> some View {
        if fillsWidth {
            content.frame(maxWidth: .infinity)
        } else {
            content.padding(.horizontal, horizontalPadding)
        }
    }

    @ViewBuilder
    private func sized<V: View>(_ content: V) -> some View {
        if let height {
            content.frame(height: height)
        } else {
            content.padding(.vertical, verticalPadding)
        }
    }
}

struct SousButtonLabel: View {
    let title: String
    var style: SousButtonStyle = .primary
    var isEnabled: Bool = true
    /// Fixed height — 52pt for the full-width CTAs. Pass nil to hug the label with
    /// `verticalPadding` instead, which is how the import sheet sizes its buttons.
    var height: CGFloat? = 52
    /// Used only when `height` is nil.
    var verticalPadding: CGFloat = 14
    /// Full-width by default. Compact buttons — SAVE KEY, the import sheet's inline
    /// actions — hug their label with `horizontalPadding` on each side instead.
    var fillsWidth: Bool = true
    /// Used only when `fillsWidth` is false.
    var horizontalPadding: CGFloat = 16
    /// An optional leading SF Symbol, as TALK TO SOUS uses.
    var icon: String? = nil
    /// Swaps the label for a spinner while work is in flight — the paywall's
    /// purchase button. The Figma component has no Busy variant yet; it should.
    var isBusy: Bool = false

    var body: some View {
        SousButtonContent(title: title, style: style, isEnabled: isEnabled,
                          icon: icon, isBusy: isBusy)
            .modifier(chrome)
    }

    fileprivate var chrome: SousButtonChrome {
        SousButtonChrome(style: style, isEnabled: isEnabled, height: height,
                         verticalPadding: verticalPadding, fillsWidth: fillsWidth,
                         horizontalPadding: horizontalPadding)
    }
}

// MARK: - SousButton

/// A full-width Sous button. Square, bordered or filled, never rounded — the one
/// exception being genuine iOS chrome, which is not drawn with this.
struct SousButton: View {
    let title: String
    var style: SousButtonStyle = .primary
    var isEnabled: Bool = true
    var height: CGFloat? = 52
    var verticalPadding: CGFloat = 14
    var fillsWidth: Bool = true
    var horizontalPadding: CGFloat = 16
    var icon: String? = nil
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SousButtonContent(title: title, style: style, isEnabled: isEnabled,
                              icon: icon, isBusy: isBusy)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // Chrome outside the button, so `.disabled()` dims only the words.
        .modifier(SousButtonChrome(style: style, isEnabled: isEnabled, height: height,
                                   verticalPadding: verticalPadding, fillsWidth: fillsWidth,
                                   horizontalPadding: horizontalPadding))
    }
}

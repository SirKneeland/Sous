import SwiftUI
import UIKit

// MARK: - Palette

// The hex literals below are the single source of truth for Sous's palette in
// code. They are verified against `design/tokens.json` by `design/check-tokens.py`
// — if you change a value here, change it there too or the check fails.
//
// Never hardcode a color in a view. If a view needs a color that isn't here,
// add a token here first.

private extension UIColor {
    convenience init(sousHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Builds a color that resolves differently in light and dark mode.
/// Pass the same value twice for a token that does not invert.
private func sousDynamic(light: UInt32, dark: UInt32) -> UIColor {
    UIColor { t in
        UIColor(sousHex: t.userInterfaceStyle == .dark ? dark : light)
    }
}

/// UIKit-facing tokens. Needed where SwiftUI can't reach — `UINavigationBarAppearance`,
/// `NSAttributedString`. SwiftUI code should use the `Color` equivalents below.
extension UIColor {
    /// Warm cream (light) / charcoal (dark) — primary background
    static let sousBackgroundUI = sousDynamic(light: 0xF2EFE9, dark: 0x1A1A1A)

    /// Near-black (light) / cream (dark) — primary text and strong borders
    static let sousTextUI = sousDynamic(light: 0x1A1A1A, dark: 0xF2EFE9)

    /// Burgundy — accent, section headers, active states, nav bar, voice bar
    static let sousTerracottaUI = sousDynamic(light: 0x8B2E3F, dark: 0xC45068)

    /// Pale burgundy — timer-highlight rows, user chat bubbles
    static let sousHighlightBackgroundUI = sousDynamic(light: 0xF7EAEC, dark: 0x2C1018)

    /// Warm gray — captions, timestamps, done steps, placeholders
    static let sousMutedUI = sousDynamic(light: 0x9A9590, dark: 0x9A9590)

    /// White (light) / dark surface (dark) — chat sheet, input fields
    static let sousSurfaceUI = sousDynamic(light: 0xFFFFFF, dark: 0x222222)

    /// Ink fill that stays dark in both modes — history settings button
    static let sousSurfaceInverseUI = sousDynamic(light: 0x1A1A1A, dark: 0x1A1A1A)

    /// Backdrop behind the photo acquisition sheet
    static let sousScrimUI = sousDynamic(light: 0x757471, dark: 0x757471)

    /// Muted green — added items in patch diff, and the ACCEPT fill on the review bar
    static let sousGreenUI = sousDynamic(light: 0x2D6A4F, dark: 0x2D6A4F)

    /// Thin separator / divider line
    static let sousSeparatorUI = sousDynamic(light: 0xD0CBC3, dark: 0x3A3530)

    // Voice mode renders on a burgundy fill in both modes, so these do not invert.

    /// Voice: "listening" label and listening waveform
    static let sousVoiceBrightUI = sousDynamic(light: 0xFAECE7, dark: 0xFAECE7)

    /// Voice: "speaking" label, speaking waveform, exit icon, patch-pending text
    static let sousVoiceSpeakingUI = sousDynamic(light: 0xF5C4B3, dark: 0xF5C4B3)

    /// Voice: "ready" / "thinking" labels and secondary voice copy
    static let sousVoiceWarmUI = sousDynamic(light: 0xF0997B, dark: 0xF0997B)
}

extension Color {
    static let sousBackground = Color(UIColor.sousBackgroundUI)
    static let sousText = Color(UIColor.sousTextUI)
    static let sousTerracotta = Color(UIColor.sousTerracottaUI)
    static let sousHighlightBackground = Color(UIColor.sousHighlightBackgroundUI)
    static let sousMuted = Color(UIColor.sousMutedUI)
    static let sousSurface = Color(UIColor.sousSurfaceUI)
    static let sousSurfaceInverse = Color(UIColor.sousSurfaceInverseUI)
    static let sousScrim = Color(UIColor.sousScrimUI)
    static let sousGreen = Color(UIColor.sousGreenUI)
    static let sousSeparator = Color(UIColor.sousSeparatorUI)
    static let sousVoiceBright = Color(UIColor.sousVoiceBrightUI)
    static let sousVoiceSpeaking = Color(UIColor.sousVoiceSpeakingUI)
    static let sousVoiceWarm = Color(UIColor.sousVoiceWarmUI)
}

// MARK: - Typography

// Every text style in the app comes from a token below. Never write
// `.system(size:)` in a view — `design/check-tokens.py` fails the build if you do.
//
// Monospace is permitted in exactly two roles: numeric readouts and voice bar
// state labels. See docs/DesignSpec.md.

extension Font {

    // MARK: New York — identity

    /// Recipe titles.
    static let sousTitle: Font = .system(size: 28, weight: .bold, design: .serif)

    /// SOUS logotype in the blank state.
    static let sousLogotype: Font = .system(size: 34, weight: .bold, design: .serif)

    // MARK: SF Pro — structure and body

    /// Small ALL CAPS burgundy section headers (INGREDIENTS, PROCEDURE).
    static let sousSectionHeader: Font = .system(size: 11, weight: .semibold)

    /// Body text, ingredient names, step text, chat messages.
    static let sousBody: Font = .system(size: 16, weight: .regular)

    /// Captions, timestamps, revision numbers.
    static let sousCaption: Font = .system(size: 11, weight: .regular)

    /// Button labels (ALL CAPS).
    static let sousButton: Font = .system(size: 14, weight: .semibold)

    /// De-emphasised button labels — destructive or secondary actions.
    static let sousButtonQuiet: Font = .system(size: 13, weight: .regular)

    /// Markdown H1 in assistant chat messages.
    static let sousHeading1: Font = .system(size: 17, weight: .bold)

    /// Markdown H2 in assistant chat messages.
    static let sousHeading2: Font = .system(size: 15, weight: .bold)

    /// Markdown H3 and below in assistant chat messages.
    static let sousHeading3: Font = .system(size: 14, weight: .semibold)

    // MARK: SF Mono — numeric readouts and voice labels only

    /// Timer-done banner. The largest readout in the app.
    static let sousReadoutLarge: Font = .system(size: 32, weight: .bold, design: .monospaced)

    /// Active countdown in the adjust-timer sheet.
    static let sousReadout: Font = .system(size: 24, weight: .bold, design: .monospaced)

    /// Digits in the duration and servings wheels.
    static let sousPickerValue: Font = .system(size: 22, weight: .regular, design: .monospaced)

    /// Wheel labels — HOURS, MINUTES, PEOPLE.
    static let sousPickerLabel: Font = .system(size: 15, weight: .semibold, design: .monospaced)

    /// Countdown inside a running-timer banner.
    static let sousTimerBanner: Font = .system(size: 14, weight: .semibold, design: .monospaced)

    /// Voice bar state labels — ready, listening, speaking, thinking.
    static let sousVoiceLabel: Font = .system(size: 14, weight: .regular, design: .monospaced)

    /// Voice bar ACCEPT / REJECT button labels.
    static let sousVoiceButton: Font = .system(size: 13, weight: .semibold, design: .monospaced)
}

// MARK: - Icon Sizing

/// The five permitted SF Symbol sizes. Icons are sized from this scale, never
/// by eye — an icon that looks wrong at every step usually wants different padding.
enum SousIconSize: CGFloat {
    /// Chevrons, close buttons, inline row affordances.
    case small = 11
    /// Standard bar and control icons — send, scan, pencil.
    case medium = 14
    /// Prominent controls — drawer buttons, mic, camera.
    case large = 16
    /// Feature icons in sheets and pickers.
    case xLarge = 22
    /// Empty-state illustration icons.
    case huge = 32
}

extension Font {
    /// SF Symbol sizing. Weight defaults to regular; pass one to match surrounding text.
    static func sousIcon(_ size: SousIconSize, weight: Font.Weight = .regular) -> Font {
        .system(size: size.rawValue, weight: weight)
    }
}

// MARK: - Square Checkbox

/// Square bordered checkbox. Unchecked: 1pt border. Checked: burgundy fill + white checkmark.
struct SousCheckbox: View {
    let isChecked: Bool
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isChecked ? Color.sousTerracotta : Color.clear)
                .frame(width: size, height: size)
                .overlay(
                    Rectangle()
                        .stroke(isChecked ? Color.sousTerracotta : Color.sousText, lineWidth: 1)
                )
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Section Header

/// Burgundy ALL CAPS section header with letter spacing.
struct SousSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.sousSectionHeader)
            .foregroundStyle(Color.sousTerracotta)
            .kerning(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Divider

/// 1pt horizontal line in the separator color.
struct SousRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.sousSeparator)
            .frame(maxWidth: .infinity)
            .frame(height: 1)
    }
}

// MARK: - Square Icon Button

/// Small square bordered icon button for navigation bars.
struct SousIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.sousIcon(.medium))
                .foregroundStyle(Color.sousText)
                .frame(width: 32, height: 32)
                .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Typography constants

/// Values that are not fonts or colours but still belong to one decision.
enum SousType {
    /// Letter-spacing for the SOUS wordmark.
    ///
    /// One value, because the app drew its own name in five places at three different
    /// trackings — 0 in the drawer and chat blank state, 2 on sign in and the loading
    /// state, 3 on the paywall — until it was settled at 2 on 2026-09-25. Nobody had
    /// chosen that spread; each screen picked its own as it was written.
    static let wordmarkTracking: CGFloat = 2
}

import SwiftUI
import UIKit

// MARK: - Color Palette

extension Color {
    /// Warm cream (light) / Charcoal (dark) — primary background
    static let sousBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
            : UIColor(red: 242/255, green: 239/255, blue: 233/255, alpha: 1)
    })

    /// Near-black (light) / Cream (dark) — primary text and borders
    static let sousText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 242/255, green: 239/255, blue: 233/255, alpha: 1)
            : UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
    })

    /// Terracotta #C1440E — accent, section headers, active states
    static let sousTerracotta = Color(red: 193/255, green: 68/255, blue: 14/255)

    /// Pale terracotta #E8A882 — timer-highlight row background
    static let sousHighlightBackground = Color(red: 232/255, green: 168/255, blue: 130/255)

    /// Warm gray #9A9590 — captions, timestamps, placeholders
    static let sousMuted = Color(red: 154/255, green: 149/255, blue: 144/255)

    /// White (light) / Dark surface (dark) — chat sheet, input fields
    static let sousSurface = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1)
            : UIColor.white
    })

    /// Muted green #2D6A4F — added items in patch diff
    static let sousGreen = Color(red: 45/255, green: 106/255, blue: 79/255)

    /// Thin separator / divider line
    static let sousSeparator = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 58/255, green: 53/255, blue: 48/255, alpha: 1)
            : UIColor(red: 208/255, green: 203/255, blue: 195/255, alpha: 1)
    })
}

// MARK: - Typography

extension Font {
    /// Large, bold, ALL CAPS — recipe titles, screen titles
    static let sousTitle: Font = .system(size: 24, weight: .bold, design: .monospaced)

    /// Small ALL CAPS terracotta — section headers (INGREDIENTS, PROCEDURE)
    static let sousSectionHeader: Font = .system(size: 11, weight: .regular, design: .monospaced)

    /// Regular weight — body text, ingredient names, step text, chat messages
    static let sousBody: Font = .system(size: 15, weight: .regular, design: .monospaced)

    /// Small — captions, timestamps, revision numbers
    static let sousCaption: Font = .system(size: 11, weight: .regular, design: .monospaced)

    /// Medium weight — button labels (ALL CAPS)
    static let sousButton: Font = .system(size: 14, weight: .semibold, design: .monospaced)

    /// Large bold — SOUS logotype in blank state
    static let sousLogotype: Font = .system(size: 34, weight: .bold, design: .monospaced)
}

// MARK: - Square Checkbox

/// Square bordered checkbox. Unchecked: 1pt border. Checked: terracotta fill + white checkmark.
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

/// Terracotta ALL CAPS section header with letter spacing.
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
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.sousText)
                .frame(width: 32, height: 32)
                .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

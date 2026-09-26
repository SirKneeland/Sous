import SwiftUI
import UIKit

// MARK: - HapticOnPressStyle

/// A medium impact on press. Lives with the bottom bar because its two buttons are the
/// only things that use it — the bar is the app's main action, and it is the one place
/// a press is worth feeling.
struct HapticOnPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            }
    }
}

// MARK: - SousBottomBar

/// The bar at the bottom of the canvas: a rule, then TALK TO SOUS with the mic beside
/// it, sharing one burgundy fill split by a hairline.
///
/// One component rather than two buttons, because that is what it is. The divider
/// belongs to neither half — it only reads as a divider because both sides share a
/// fill — and when voice is unavailable the mic and the divider go together while the
/// CTA expands to full width. That is bar-level layout, not button state, which is why
/// the shared `SousButton` alone could never have owned this.
///
/// Matches the Figma **Bottom Bar** component (Voice Yes / Voice No).
struct SousBottomBar: View {
    /// Voice is hidden during the free trial and in soft wall — see `BillingGate`.
    var voiceEnabled: Bool = true
    let onTalk: () -> Void
    let onVoice: () -> Void

    /// The mic is 60 x 52: wider than tall, so it reads as the bar's other half rather
    /// than as a square button stuck on the end. Not an Icon Button — that component is
    /// 44pt or 32pt square, and neither is this.
    private static let micWidth: CGFloat = 60
    private static let height: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            SousRule()

            HStack(spacing: 0) {
                Button(action: onTalk) {
                    SousButtonLabel(title: "TALK TO SOUS", style: .primary,
                                    height: Self.height, icon: "message")
                }
                .buttonStyle(HapticOnPressStyle())

                if voiceEnabled {
                    // White at 25% on the shared burgundy. Not a token: it is one of the
                    // raw white-opacity values recorded in docs/KnownIssues.md, and it
                    // belongs to this seam rather than to either side.
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 1, height: Self.height)

                    Button(action: onVoice) {
                        Image(systemName: "mic.fill")
                            .font(.sousIcon(.large, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: Self.micWidth, height: Self.height)
                            .background(Color.sousTerracotta)
                    }
                    .buttonStyle(HapticOnPressStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.sousBackground)
        }
    }
}

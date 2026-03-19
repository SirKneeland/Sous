import SwiftUI

// MARK: - Preference Key

/// Captures the gear button's frame in the "contentRoot" named coordinate space
/// so the callout arrow can be positioned over it at runtime without hardcoded offsets.
struct GearButtonFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - Callout View

/// First-launch callout that points directly at the gear icon.
/// Rendered as a full-screen overlay so it can position itself using
/// the gear button's runtime frame. Never dismissible by tap.
struct APIKeyCallout: View {
    /// Frame of the gear button in the "contentRoot" coordinate space.
    let gearFrame: CGRect

    var body: some View {
        GeometryReader { geo in
            let arrowHalfWidth: CGFloat = 9
            // Trailing padding that places the arrow's center directly over the gear's midX.
            let arrowTrailingPad = max(0, geo.size.width - gearFrame.midX - arrowHalfWidth)
            let topPad = gearFrame.maxY + 2

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.sousText)
                    .frame(width: 18, height: 18)
                    .padding(.trailing, arrowTrailingPad)

                Text("Start here — add your\nAPI key in Settings.")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.sousTerracotta)
                    .padding(.trailing, 8)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, topPad)
        }
    }
}

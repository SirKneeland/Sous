import SwiftUI

// MARK: - TimerDoneBanner

/// Large (~300pt) burgundy panel shown when a timer expires.
/// Tapping dismisses it and scrolls to the step.
struct TimerDoneBanner: View {
    let session: TimerSession
    let onDismiss: (UUID) -> Void   // stepId → scroll + highlight after dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Button {
                onDismiss(session.stepId)
            } label: {
                VStack(spacing: 16) {
                    Text(session.shortSummary.uppercased())
                        .font(.sousTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("TIMER DONE [\(formatDuration(session.totalDuration))]")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(Color.sousTerracotta)
            }
            .buttonStyle(.plain)
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

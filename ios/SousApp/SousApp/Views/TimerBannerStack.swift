import SwiftUI

// MARK: - TimerBannerStack

/// Renders up to 3 stacked timer banners (newest first) above the Talk to Sous button.
/// Tapping a banner scrolls to and highlights the relevant step (via callback).
struct TimerBannerStack: View {
    var timerManager: StepTimerManager
    let onTapBanner: (UUID) -> Void   // stepId → scroll + highlight

    var body: some View {
        VStack(spacing: 0) {
            ForEach(timerManager.activeSessions) { session in
                TimerBannerRow(
                    session: session,
                    timerManager: timerManager,
                    onTap: { onTapBanner(session.stepId) }
                )
            }
        }
    }
}

// MARK: - TimerBannerRow

private struct TimerBannerRow: View {
    let session: TimerSession
    var timerManager: StepTimerManager
    let onTap: () -> Void

    @State private var showingAdjust = false

    private var remaining: TimeInterval { timerManager.remainingTime(for: session) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(session.shortSummary)
                    .font(.sousButton)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text(formatTime(remaining))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                // Pencil: adjust remaining time
                Button {
                    showingAdjust = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.sousTerracotta)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingAdjust) {
            DurationPickerSheet(
                title: "ADJUST TIMER",
                initialDuration: remaining,
                onConfirm: { newDuration in
                    showingAdjust = false
                    timerManager.adjustTimer(session, newRemaining: newDuration)
                },
                onCancel: { showingAdjust = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

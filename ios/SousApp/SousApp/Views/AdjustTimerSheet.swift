import SwiftUI

// MARK: - AdjustTimerSheet

/// Sheet for adjusting a currently active (or paused) timer.
/// Shown when the user taps the pencil icon on a timer banner.
struct AdjustTimerSheet: View {
    /// Stable identity for looking up the live session from timerManager.
    let sessionId: UUID
    var timerManager: StepTimerManager
    let onDismiss: () -> Void

    @State private var hours: Int
    @State private var minutes: Int

    init(session: TimerSession, timerManager: StepTimerManager, onDismiss: @escaping () -> Void) {
        self.sessionId = session.id
        self.timerManager = timerManager
        self.onDismiss = onDismiss
        // Seed pickers from the remaining time at the moment the sheet is presented.
        let totalMinutes = max(1, Int(session.remainingTime() / 60))
        _hours = State(initialValue: totalMinutes / 60)
        _minutes = State(initialValue: totalMinutes % 60)
    }

    // MARK: Live session

    private var liveSession: TimerSession? {
        timerManager.activeSessions.first { $0.id == sessionId }
    }

    private var remaining: TimeInterval {
        guard let s = liveSession else { return 0 }
        return timerManager.remainingTime(for: s)
    }

    private var isPaused: Bool { liveSession?.isPaused ?? false }

    private var selectedDuration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60)
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row: title left, live countdown right
            HStack {
                Text("ADJUST TIMER")
                    .font(.sousTitle)
                    .foregroundStyle(Color.sousText)
                Spacer()
                Text(formatTime(remaining))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.sousTerracotta)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            SousRule()

            // Hours / Minutes wheel pickers
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("HOURS")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.sousMuted)
                        .kerning(1.0)
                    Picker("Hours", selection: $hours) {
                        ForEach(0..<24, id: \.self) { h in
                            Text("\(h)").tag(h)
                                .font(.system(size: 22, weight: .regular, design: .monospaced))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }

                Rectangle()
                    .fill(Color.sousSeparator)
                    .frame(width: 1)
                    .padding(.vertical, 8)

                VStack(spacing: 4) {
                    Text("MINUTES")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.sousMuted)
                        .kerning(1.0)
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { m in
                            Text("\(m)").tag(m)
                                .font(.system(size: 22, weight: .regular, design: .monospaced))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)

            SousRule()

            // Action buttons: Pause/Resume | Start
            HStack(spacing: 0) {
                Button {
                    guard let live = liveSession else { return }
                    if isPaused {
                        timerManager.resumeTimer(live)
                    } else {
                        timerManager.pauseTimer(live)
                    }
                } label: {
                    Text(isPaused ? "RESUME" : "PAUSE")
                        .font(.sousButton)
                        .foregroundStyle(Color.sousTerracotta)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.sousSeparator)
                    .frame(width: 1)
                    .frame(height: 52)

                Button {
                    let duration = selectedDuration
                    guard duration > 0, let live = liveSession else { return }
                    timerManager.adjustTimer(live, newRemaining: duration)
                    onDismiss()
                } label: {
                    Text("START")
                        .font(.sousButton)
                        .foregroundStyle(Color.sousBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.sousTerracotta)
                }
                .buttonStyle(.plain)
            }
            .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Delete Timer — less prominent, destructive
            Spacer().frame(height: 24)
            Button {
                if let live = liveSession {
                    timerManager.deleteTimer(live)
                }
                onDismiss()
            } label: {
                Text("Delete Timer")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.sousBackground)
    }

    // MARK: Helpers

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

import SwiftUI
import SousCore

// MARK: - TimerAffordanceText

/// Renders step text with a highlighted time span (terracotta) and a trailing tappable timer icon.
/// The timer icon is the sole tap target for the timer flow — the text itself is not tappable.
/// Steps with no detected time reference render as plain text with no affordance.
struct TimerAffordanceText: View {
    let step: Step
    let stepIndex: Int
    let isHighlighted: Bool
    var timerManager: StepTimerManager
    var onClearHighlight: (() -> Void)? = nil

    @State private var showingRangePicker = false
    @State private var pendingParsed: ParsedTime? = nil
    @State private var isStarting: Bool = false

    private var parsed: ParsedTime? { StepTimeParser.parse(step.text) }
    private var hasActiveTimer: Bool { timerManager.isTimerActive(for: step.id) }
    private var isDone: Bool { step.status == .done }

    var body: some View {
        stepTextView
            .sheet(item: $pendingParsed) { p in
                DurationPickerSheet(
                    initialDuration: p.lowerBound,
                    onConfirm: { duration in
                        pendingParsed = nil
                        startTimer(duration: duration)
                    },
                    onCancel: {
                        pendingParsed = nil
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
            }
    }

    // MARK: - Step text

    /// Renders the step text with the timer affordance scoped to a trailing icon button only.
    /// The highlighted time span is coloured but not itself tappable — only the icon triggers
    /// the timer flow. Steps with no detected time reference render as plain text.
    @ViewBuilder
    private var stepTextView: some View {
        if let p = parsed, !isDone {
            HStack(alignment: .top, spacing: 8) {
                buildHighlightedText(step.text, highlightRange: p.range)

                let iconName = (hasActiveTimer || isStarting) ? "timer.circle.fill" : "timer"
                Button {
                    guard !hasActiveTimer else { return }
                    handleTimerTap()
                } label: {
                    Image(systemName: iconName)
                        .font(.sousBody)
                        .foregroundStyle(Color.sousTerracotta.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else {
            Text(step.text)
                .font(.sousBody)
                .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
                .strikethrough(isDone, color: Color.sousMuted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Builds a `Text` with the time span highlighted in terracotta. No icon is inlined —
    /// the icon lives as a separate tappable button so the tap target is correctly scoped.
    private func buildHighlightedText(_ text: String, highlightRange: Range<String.Index>) -> some View {
        let before = String(text[text.startIndex..<highlightRange.lowerBound])
        let middle = String(text[highlightRange])
        let after  = String(text[highlightRange.upperBound..<text.endIndex])

        return (
            Text(before).foregroundStyle(Color.sousText)
            + Text(middle).foregroundStyle(Color.sousTerracotta)
            + Text(after).foregroundStyle(Color.sousText)
        )
        .font(.sousBody)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Timer start logic

    private func handleTimerTap() {
        guard let p = parsed else { return }
        onClearHighlight?()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch p.duration {
        case .exact(let seconds):
            startTimer(duration: seconds)
        case .range:
            pendingParsed = p
            showingRangePicker = true
        }
    }

    private func startTimer(duration: TimeInterval) {
        isStarting = true
        Task {
            await timerManager.startTimer(
                stepId: step.id,
                stepIndex: stepIndex,
                stepText: step.text,
                duration: duration
            )
            isStarting = false
        }
    }
}

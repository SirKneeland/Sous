import SwiftUI
import SousCore

// MARK: - TimerAffordanceText

/// Renders step text with a highlighted time span (burgundy) and a tappable timer icon.
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

    /// Returns the Text-concatenated step view with the timer icon inlined before the
    /// highlighted time span. When there is an active timer or no time reference, renders
    /// plain text. The whole view is wrapped in a Button when there is a time reference so
    /// tapping anywhere on the text triggers the timer flow.
    @ViewBuilder
    private var stepTextView: some View {
        if let p = parsed, !isDone {
            Button {
                guard !hasActiveTimer else { return }
                handleTimerTap()
            } label: {
                buildInlineText(step.text, highlightRange: p.range)
            }
            .buttonStyle(.plain)
        } else {
            Text(step.text)
                .font(.sousBody)
                .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
                .strikethrough(isDone, color: Color.sousMuted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Builds a `Text` with the timer SF Symbol inlined immediately before the highlighted
    /// time span, so the icon and time text flow together within the paragraph.
    private func buildInlineText(_ text: String, highlightRange: Range<String.Index>) -> some View {
        let before = String(text[text.startIndex..<highlightRange.lowerBound])
        let middle = String(text[highlightRange])
        let after  = String(text[highlightRange.upperBound..<text.endIndex])
        let baseColor: Color = Color.sousText
        let accentColor: Color = Color.sousTerracotta
        let iconName = (hasActiveTimer || isStarting) ? "timer.circle.fill" : "timer"

        let composed =
            Text(before).font(.sousBody).foregroundStyle(baseColor)
            + Text(Image(systemName: iconName)).font(.sousBody).foregroundStyle(accentColor.opacity(0.85))
            + Text(" " + middle).font(.sousBody).foregroundStyle(accentColor)
            + Text(after).font(.sousBody).foregroundStyle(baseColor)

        return composed
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Timer start logic

    private func handleTimerTap() {
        guard let p = parsed else { return }
        onClearHighlight?()
        // Phase 1: immediate feedback before any async work
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

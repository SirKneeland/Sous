import SwiftUI
import UIKit
import SousCore

// MARK: - TimerAffordanceText

/// Renders a step row's text. If the step contains a time reference and is not done, delegates
/// to `TimerStepTextView` (UIViewRepresentable) which produces a single flowing paragraph with
/// the timer affordance (icon + time span) as the sole tap target. Steps without a time reference,
/// or done steps, render as a plain SwiftUI `Text`.
struct TimerAffordanceText: View {
    let step: Step
    let stepIndex: Int
    let isHighlighted: Bool
    var isCurrent: Bool = false
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

    @ViewBuilder
    private var stepTextView: some View {
        if let p = parsed, !isDone {
            TimerStepTextView(
                stepText: step.text,
                timerRange: p.range,
                isTimerActive: hasActiveTimer,
                isStarting: isStarting,
                isCurrent: isCurrent,
                onTimerTap: {
                    guard !hasActiveTimer else { return }
                    handleTimerTap()
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(step.text)
                .font(.sousBody)
                .fontWeight(isCurrent ? .bold : nil)
                .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
                .strikethrough(isDone, color: Color.sousMuted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

// MARK: - TimerStepTextView

/// A non-scrolling UITextView wrapped as a SwiftUI view. Renders the step text as a single
/// flowing NSAttributedString paragraph with an inline SF Symbol for the timer affordance.
/// A UITapGestureRecognizer uses NSLayoutManager character-index hit testing to restrict
/// the interactive region to the timer span (icon + time text) only.
private struct TimerStepTextView: UIViewRepresentable {

    let stepText: String
    let timerRange: Range<String.Index>
    let isTimerActive: Bool
    let isStarting: Bool
    var isCurrent: Bool = false
    let onTimerTap: () -> Void

    // MARK: Shared style constants

    private var bodyFont: UIFont {
        UIFont.monospacedSystemFont(ofSize: 15, weight: isCurrent ? .bold : .regular)
    }

    private static var textUIColor: UIColor {
        UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 242/255, green: 239/255, blue: 233/255, alpha: 1)
                : UIColor(red:  26/255, green:  26/255, blue:  26/255, alpha: 1)
        }
    }

    private static var accentUIColor: UIColor {
        UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 196/255, green: 80/255, blue: 104/255, alpha: 1)
                : UIColor(red: 139/255, green: 46/255, blue:  63/255, alpha: 1)
        }
    }

    // MARK: UIViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        // Force TextKit 1 so NSLayoutManager character-index hit testing is available.
        let tv = UITextView(usingTextLayoutManager: false)
        tv.isScrollEnabled = false
        tv.isEditable = false
        tv.isSelectable = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tv.addGestureRecognizer(tap)
        context.coordinator.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let (attrStr, timerRange) = buildAttributedString()
        if tv.attributedText != attrStr {
            tv.attributedText = attrStr
        }
        context.coordinator.timerNSRange = timerRange
        context.coordinator.onTimerTap = onTimerTap
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let natural = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(natural.height))
    }

    // MARK: NSAttributedString construction

    /// Builds the attributed string and returns the NSRange of the timer span
    /// (icon attachment character + space + time text) within the full string.
    private func buildAttributedString() -> (NSAttributedString, NSRange) {
        let text = stepText
        let before = String(text[text.startIndex..<timerRange.lowerBound])
        let middle = String(text[timerRange])
        let after  = String(text[timerRange.upperBound..<text.endIndex])

        let font = bodyFont
        let baseAttrs:   [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Self.textUIColor]
        let accentAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Self.accentUIColor]

        let result = NSMutableAttributedString()

        // Text before the timer reference
        if !before.isEmpty {
            result.append(NSAttributedString(string: before, attributes: baseAttrs))
        }

        // --- Timer span start ---
        let timerStart = result.length

        // Inline SF Symbol icon
        let iconName = (isTimerActive || isStarting) ? "timer.circle.fill" : "timer"
        let symCfg = UIImage.SymbolConfiguration(font: font)
        if let img = UIImage(systemName: iconName, withConfiguration: symCfg)?
                        .withTintColor(Self.accentUIColor, renderingMode: .alwaysOriginal) {
            let attachment = NSTextAttachment()
            attachment.image = img
            // Vertically centre the icon on the cap-height line.
            let sz = img.size
            attachment.bounds = CGRect(
                x: 0,
                y: (font.capHeight - sz.height) / 2,
                width: sz.width,
                height: sz.height
            )
            result.append(NSAttributedString(attachment: attachment))
        }

        // Space + highlighted time text
        result.append(NSAttributedString(string: " " + middle, attributes: accentAttrs))

        // --- Timer span end ---
        let timerEnd = result.length

        // Text after the timer reference
        if !after.isEmpty {
            result.append(NSAttributedString(string: after, attributes: baseAttrs))
        }

        let timerNSRange = NSRange(location: timerStart, length: timerEnd - timerStart)
        return (result, timerNSRange)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject {
        weak var textView: UITextView?
        var timerNSRange: NSRange = NSRange(location: NSNotFound, length: 0)
        var onTimerTap: (() -> Void)?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let tv = textView,
                  timerNSRange.location != NSNotFound else { return }
            let lm = tv.layoutManager

            // Convert touch to text-container coordinates.
            let pt = gesture.location(in: tv)
            let adjusted = CGPoint(x: pt.x - tv.textContainerInset.left,
                                   y: pt.y - tv.textContainerInset.top)

            // Find the nearest glyph and its corresponding character index.
            let glyphIdx = lm.glyphIndex(for: adjusted,
                                          in: tv.textContainer,
                                          fractionOfDistanceThroughGlyph: nil)
            let charIdx = lm.characterIndexForGlyph(at: glyphIdx)

            // Fire only when the tap lands inside the timer span.
            if charIdx >= timerNSRange.location,
               charIdx < timerNSRange.location + timerNSRange.length {
                onTimerTap?()
            }
        }
    }
}

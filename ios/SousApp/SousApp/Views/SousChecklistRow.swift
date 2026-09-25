import SwiftUI

// MARK: - SousChecklistText

/// The text inside a checklist row: body type, muted and struck through once done,
/// bold while it is the current step.
///
/// `strikesWhenDone` is false for ingredients on purpose — ticking one off means
/// "I have this", not "this no longer applies", so it stays legible.
struct SousChecklistText: View {
    let text: String
    var isDone: Bool = false
    var isCurrent: Bool = false
    var strikesWhenDone: Bool = true

    var body: some View {
        Text(text)
            .font(.sousBody)
            .fontWeight(isCurrent ? .bold : nil)
            .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
            .strikethrough(strikesWhenDone && isDone, color: Color.sousMuted)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - SousChecklistRow

/// Checkbox and content, the way every checklist row on the recipe canvas pairs
/// them: top-aligned, 12pt apart, with the checkbox nudged 2pt down so it sits on
/// the first line of text instead of above it.
///
/// This owns the pairing and nothing else. Swipe actions, list-row insets, the
/// timer-highlight fill, the drain-and-collapse animation and the tap targets all
/// differ per section and stay at the call site — ingredients, steps and mise en
/// place agree on how a row *looks* and disagree on how it *behaves*. Folding the
/// behaviour in would mean a view with a dozen flags, which is harder to read than
/// the three callers it replaced.
struct SousChecklistRow<Content: View>: View {
    let isChecked: Bool
    /// Leading inset for a nested row, applied as padding so it does not inherit the
    /// stack's item spacing. Use `SousChecklistRow.nestedIndent` per level.
    var indent: CGFloat = 0
    /// When set, the checkbox is its own tap target. When nil, the whole row is,
    /// and the caller handles the gesture.
    var onToggleCheckbox: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    /// One level of nesting. Sub-steps and mise en place components share it, so a
    /// nested prep task and a sub-step line up instead of sitting 12pt apart.
    static var nestedIndent: CGFloat { 20 }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            checkbox
            content()
            // minLength 0 so a caller whose content already fills the width
            // (the step row) is unaffected, while callers that don't (ingredients,
            // mise en place) still get pushed left.
            Spacer(minLength: 0)
        }
        // Leading padding, not a spacer inside the stack. A spacer would also pick
        // up the 12pt item spacing, which is exactly why nested prep tasks used to
        // sit 12pt further right than sub-steps despite both declaring 20.
        .padding(.leading, indent)
    }

    @ViewBuilder
    private var checkbox: some View {
        if let onToggleCheckbox {
            Button(action: onToggleCheckbox) {
                SousCheckbox(isChecked: isChecked)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
        } else {
            SousCheckbox(isChecked: isChecked)
                .padding(.top, 2)
        }
    }
}

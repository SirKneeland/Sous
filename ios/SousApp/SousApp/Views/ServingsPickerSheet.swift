import SwiftUI

// MARK: - ServingsPickerSheet

/// Sheet for choosing a new serving size. Modeled on `AdjustTimerSheet`.
/// Shown when the user taps the "SERVES N" indicator in the recipe header.
/// "SET" hands the chosen value back via `onSet`, which triggers an LLM rescale
/// request that flows through normal patch review.
struct ServingsPickerSheet: View {
    /// The recipe's current serving size, used to seed the picker (4 when unknown).
    let currentServings: Int
    let onCancel: () -> Void
    let onSet: (Int) -> Void

    /// Selectable serving sizes shown in the wheel.
    static let range = 1...12

    @State var selection: Int

    init(currentServings: Int, onCancel: @escaping () -> Void, onSet: @escaping (Int) -> Void) {
        self.currentServings = currentServings
        self.onCancel = onCancel
        self.onSet = onSet
        // Clamp the seed into the selectable range so the wheel always has a valid tag.
        _selection = State(initialValue: min(max(currentServings, ServingsPickerSheet.range.lowerBound),
                                             ServingsPickerSheet.range.upperBound))
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row
            HStack {
                Text("SERVES")
                    .font(.sousTitle)
                    .foregroundStyle(Color.sousText)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            SousRule()

            // People wheel picker
            VStack(spacing: 4) {
                Text("PEOPLE")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.sousMuted)
                    .kerning(1.0)
                Picker("People", selection: $selection) {
                    ForEach(ServingsPickerSheet.range, id: \.self) { n in
                        Text("\(n)").tag(n)
                            .font(.system(size: 22, weight: .regular, design: .monospaced))
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)

            SousRule()

            // Action buttons: Cancel | Set
            HStack(spacing: 0) {
                Button {
                    onCancel()
                } label: {
                    Text("CANCEL")
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
                    onSet(selection)
                } label: {
                    Text("SET")
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
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.sousBackground)
    }
}

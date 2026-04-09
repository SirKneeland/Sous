import SwiftUI
import SousCore

// MARK: - Standalone debug preview — NOT connected to any production view
// Delete this file when done investigating row layout.

private struct RowLayoutDebugPreview: View {
    var body: some View {
        List {
            // Solo row 1
            HStack(alignment: .top, spacing: 12) {
                SousCheckbox(isChecked: false)
                    .padding(.top, 2)
                Text("solo row text")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.visible, edges: .bottom)
            .listRowSeparatorTint(Color.sousSeparator)

            // Child row — built exactly as NestedStepGroupView builds them
            Button { } label: {
                HStack(alignment: .top, spacing: 12) {
                    SousCheckbox(isChecked: false)
                        .padding(.top, 2)
                    Text("child row text")
                        .font(.sousBody)
                        .foregroundStyle(Color.sousText)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -20)
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 20))
            .listRowBackground(Color.yellow.opacity(0.15)) // tint to spot the row bounds
            .listRowSeparator(.visible, edges: .bottom)
            .listRowSeparatorTint(Color.sousSeparator)

            // Solo row 2
            HStack(alignment: .top, spacing: 12) {
                SousCheckbox(isChecked: false)
                    .padding(.top, 2)
                Text("solo row text")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.visible, edges: .bottom)
            .listRowSeparatorTint(Color.sousSeparator)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.sousBackground)
    }
}

#Preview("Row Layout Debug") {
    RowLayoutDebugPreview()
}

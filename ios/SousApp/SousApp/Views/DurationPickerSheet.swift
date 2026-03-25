import SwiftUI

// MARK: - DurationPickerSheet

/// A sheet containing hours + minutes wheel pickers.
/// Used when starting a range timer or editing remaining time.
struct DurationPickerSheet: View {
    let title: String
    let initialDuration: TimeInterval
    let onConfirm: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var hours: Int
    @State private var minutes: Int

    init(
        title: String = "SET TIMER",
        initialDuration: TimeInterval,
        onConfirm: @escaping (TimeInterval) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.initialDuration = initialDuration
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let totalMinutes = max(1, Int(initialDuration / 60))
        _hours = State(initialValue: totalMinutes / 60)
        _minutes = State(initialValue: totalMinutes % 60)
    }

    private var selectedDuration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.sousTitle)
                    .foregroundStyle(Color.sousText)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            SousRule()

            // Pickers
            HStack(spacing: 0) {
                // Hours
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

                // Divider
                Rectangle()
                    .fill(Color.sousSeparator)
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Minutes
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

            // Action buttons
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
                    let duration = selectedDuration
                    guard duration > 0 else { return }
                    onConfirm(duration)
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
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.sousBackground)
    }
}

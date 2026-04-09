import SwiftUI

struct TexturePreviewView: View {
    @AppStorage("debugTextureIntensity") private var intensity: Double = 0.6
    @AppStorage("debugTextureApproach") private var approachRaw: String = "dots"
    // Grain color stored as separate components — SwiftUI Color isn't @AppStorage-compatible.
    // Default: warm brown RGB(101, 67, 33)
    @AppStorage("debugGrainColorR") private var grainR: Double = 101.0 / 255
    @AppStorage("debugGrainColorG") private var grainG: Double = 67.0 / 255
    @AppStorage("debugGrainColorB") private var grainB: Double = 33.0 / 255

    @Environment(\.dismiss) private var dismiss

    private enum GrainApproach: String {
        case dots, fibers, twoLayer
        var label: String {
            switch self {
            case .dots:     return "Dots"
            case .fibers:   return "Fibers"
            case .twoLayer: return "Two-Layer"
            }
        }
    }

    private var approach: GrainApproach {
        GrainApproach(rawValue: approachRaw) ?? .dots
    }

    private var grainColor: Color {
        Color(red: grainR, green: grainG, blue: grainB)
    }

    private var grainColorBinding: Binding<Color> {
        Binding(
            get: { grainColor },
            set: { newColor in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(newColor).getRed(&r, green: &g, blue: &b, alpha: &a)
                grainR = Double(r)
                grainG = Double(g)
                grainB = Double(b)
            }
        )
    }

    var body: some View {
        texturedBackground
            .ignoresSafeArea()
            .overlay(alignment: .bottom) { controlPanel }
            .overlay(alignment: .topLeading) { backButton }
    }

    // MARK: - Textured background

    @ViewBuilder
    private var texturedBackground: some View {
        switch approach {
        case .dots:
            Color.sousBackground
                .modifier(DotsTextureModifier(intensity: intensity, color: grainColor))
        case .fibers:
            Color.sousBackground
                .modifier(FibersTextureModifier(intensity: intensity, color: grainColor))
        case .twoLayer:
            Color.sousBackground
                .modifier(TwoLayerTextureModifier(intensity: intensity, color: grainColor))
        }
    }

    // MARK: - Control panel

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Approach switcher
            HStack(spacing: 0) {
                approachButton(.dots)
                approachButton(.fibers)
                approachButton(.twoLayer)
            }
            .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))

            // Intensity slider
            VStack(alignment: .leading, spacing: 6) {
                Text("Intensity: \(String(format: "%.2f", intensity))")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
                Slider(value: $intensity, in: 0...1)
                    .tint(Color.sousTerracotta)
            }

            // Grain color picker
            HStack {
                Text("Grain color")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                Spacer()
                ColorPicker("", selection: grainColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }
        }
        .padding(24)
        .background(Color.sousBackground.opacity(0.92))
    }

    @ViewBuilder
    private func approachButton(_ a: GrainApproach, disabled: Bool = false) -> some View {
        let isSelected = approach == a
        Button {
            if !disabled { approachRaw = a.rawValue }
        } label: {
            Text(a.label)
                .font(.sousCaption)
                .foregroundStyle(
                    disabled   ? Color.sousMuted :
                    isSelected ? Color.sousBackground :
                                 Color.sousText
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected && !disabled ? Color.sousText : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Back button

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Text("BACK")
                .font(.sousButton)
                .foregroundStyle(Color.sousText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 60)
        .padding(.leading, 20)
    }
}

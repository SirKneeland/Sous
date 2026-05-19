import Combine
import SwiftUI

// MARK: - Private colors

private extension Color {
    static let vbSalmon   = Color(red: 0xF0 / 255.0, green: 0x99 / 255.0, blue: 0x7B / 255.0)
    static let vbCream    = Color(red: 0xFA / 255.0, green: 0xEC / 255.0, blue: 0xE7 / 255.0)
    static let vbPeach    = Color(red: 0xF5 / 255.0, green: 0xC4 / 255.0, blue: 0xB3 / 255.0)
}

// MARK: - VoiceBarView

struct VoiceBarView: View {
    @ObservedObject var coordinator: VoiceModeCoordinator
    var onExit: () -> Void
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            labelSection
            if coordinator.state == .patchPending {
                patchButtons
            }
            VoiceCanvasStrip(state: coordinator.state)
                .frame(height: 28)
        }
        .background(Color.sousTerracotta.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Label section

    @ViewBuilder
    private var labelSection: some View {
        ZStack(alignment: .topTrailing) {
            stateContent
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 52)
                .padding(.vertical, 20)

            exitButton
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        if coordinator.connectionFailed {
            Text("Voice mode unavailable")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.vbSalmon)
        } else if coordinator.state == .patchPending {
            Text("say 'accept' or 'reject'")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.vbPeach)
        } else {
            VStack(spacing: 6) {
                Text(stateText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(stateTextColor)
            }
        }
    }

    private var exitButton: some View {
        Button(action: onExit) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.vbPeach)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
        .padding(.trailing, 16)
    }

    // MARK: - Patch buttons

    private var patchButtons: some View {
        HStack(spacing: 0) {
            Button(action: onReject) {
                Text("REJECT")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.vbSalmon)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
            }
            .buttonStyle(.plain)

            Color.white.opacity(0.15)
                .frame(width: 1)

            Button(action: onAccept) {
                Text("ACCEPT CHANGES")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.vbPeach)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - State display helpers

    private var stateText: String {
        switch coordinator.state {
        case .ready:        "○ ready"
        case .listening:    "● listening"
        case .thinking:     "○ thinking"
        case .speaking:     "● speaking"
        case .patchPending: ""
        }
    }

    private var stateTextColor: Color {
        switch coordinator.state {
        case .ready:        .vbSalmon
        case .listening:    .vbCream
        case .thinking:     .vbSalmon
        case .speaking:     .vbPeach
        case .patchPending: .vbPeach
        }
    }
}

// MARK: - VoiceCanvasStrip

private struct VoiceCanvasStrip: View {
    let state: VoiceModeState
    @StateObject private var animator = VoiceAnimator()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            canvasContent(size: size)
                .onAppear {
                    animator.configure(for: state, width: size.width, height: size.height)
                }
                .onChange(of: state) { _, newState in
                    animator.configure(for: newState, width: size.width, height: size.height)
                }
        }
    }

    @ViewBuilder
    private func canvasContent(size: CGSize) -> some View {
        switch state {
        case .ready, .thinking, .patchPending:
            Canvas { ctx, s in
                drawDots(ctx: &ctx, size: s)
            }

        case .listening, .speaking:
            let barColor: Color = state == .listening ? .vbCream : .vbPeach
            TimelineView(.animation) { _ in
                Canvas { ctx, s in
                    drawBars(ctx: &ctx, size: s, color: barColor)
                }
            }
        }
    }

    private func drawDots(ctx: inout GraphicsContext, size: CGSize) {
        guard !animator.row1Opacities.isEmpty else { return }
        let step: CGFloat = 5
        let dotSize: CGFloat = 3
        let row2Y: CGFloat = size.height - dotSize
        let row1Y: CGFloat = row2Y - dotSize - 2
        let count = min(animator.row1Opacities.count, Int(size.width / step))
        for i in 0..<count {
            let x = CGFloat(i) * step
            guard x + dotSize <= size.width else { break }
            ctx.fill(
                Path(CGRect(x: x, y: row1Y, width: dotSize, height: dotSize)),
                with: .color(Color.white.opacity(animator.row1Opacities[i]))
            )
            if i < animator.row2Opacities.count {
                ctx.fill(
                    Path(CGRect(x: x, y: row2Y, width: dotSize, height: dotSize)),
                    with: .color(Color.white.opacity(animator.row2Opacities[i]))
                )
            }
        }
    }

    private func drawBars(ctx: inout GraphicsContext, size: CGSize, color: Color) {
        guard !animator.barHeights.isEmpty else { return }
        let step: CGFloat = 5
        let barW: CGFloat = 3
        let count = min(animator.barHeights.count, Int(size.width / step))
        for i in 0..<count {
            let x = CGFloat(i) * step
            guard x + barW <= size.width else { break }
            let h = animator.barHeights[i]
            ctx.fill(
                Path(CGRect(x: x, y: size.height - h, width: barW, height: h)),
                with: .color(color)
            )
        }
    }
}

// MARK: - VoiceAnimator

@MainActor
private final class VoiceAnimator: ObservableObject {
    @Published var row1Opacities: [Double] = []
    @Published var row2Opacities: [Double] = []
    @Published var barHeights: [CGFloat] = []

    private var row1Targets: [Double] = []
    private var row2Targets: [Double] = []
    private var timer: AnyCancellable?

    func configure(for state: VoiceModeState, width: CGFloat, height: CGFloat) {
        timer?.cancel()
        timer = nil

        let count = max(0, Int(width / 5))

        switch state {
        case .ready, .patchPending:
            initDots(count: count, range: 0.10...1.0)
            startDotTimer(lerpFactor: 0.09, interval: 0.05, range: 0.10...1.0)
        case .thinking:
            initDots(count: count, range: 0.15...1.0)
            startDotTimer(lerpFactor: 0.18, interval: 0.035, range: 0.15...1.0)
        case .listening, .speaking:
            initBars(count: count, maxH: height)
            startBarTimer(interval: 0.11, count: count, maxH: height)
        }
    }

    // MARK: - Dots

    private func initDots(count: Int, range: ClosedRange<Double>) {
        guard row1Opacities.count != count else { return }
        row1Opacities = (0..<count).map { _ in Double.random(in: range) }
        row1Targets   = (0..<count).map { _ in Double.random(in: range) }
        row2Opacities = (0..<count).map { _ in Double.random(in: range) }
        row2Targets   = (0..<count).map { _ in Double.random(in: range) }
    }

    private func startDotTimer(lerpFactor: Double, interval: TimeInterval, range: ClosedRange<Double>) {
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let count = self.row1Opacities.count
                guard count > 0, count == self.row2Opacities.count else { return }
                var r1 = self.row1Opacities
                var r2 = self.row2Opacities
                for i in 0..<count {
                    r1[i] += (self.row1Targets[i] - r1[i]) * lerpFactor
                    if abs(r1[i] - self.row1Targets[i]) < 0.02 {
                        self.row1Targets[i] = Double.random(in: range)
                    }
                    r2[i] += (self.row2Targets[i] - r2[i]) * lerpFactor
                    if abs(r2[i] - self.row2Targets[i]) < 0.02 {
                        self.row2Targets[i] = Double.random(in: range)
                    }
                }
                self.row1Opacities = r1
                self.row2Opacities = r2
            }
    }

    // MARK: - Bars

    private func initBars(count: Int, maxH: CGFloat) {
        guard barHeights.count != count else { return }
        barHeights = (0..<count).map { _ in CGFloat.random(in: 2...maxH) }
    }

    private func startBarTimer(interval: TimeInterval, count: Int, maxH: CGFloat) {
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                var raw = (0..<count).map { _ in CGFloat.random(in: 2...maxH) }
                for i in 0..<count {
                    let prev = i > 0 ? raw[i - 1] : raw[i]
                    let next = i < count - 1 ? raw[i + 1] : raw[i]
                    raw[i] = (prev + raw[i] + next) / 3
                }
                self.barHeights = raw
            }
    }
}

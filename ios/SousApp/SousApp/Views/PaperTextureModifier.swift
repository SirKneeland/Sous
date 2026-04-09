import SwiftUI

// MARK: - Seeded RNG

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64 = 42) {
        state = seed
    }

    mutating func nextDouble() -> Double {
        // Xorshift64 — fast, deterministic, no global state
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state) / Double(UInt64.max)
    }
}

// MARK: - PaperTextureModifier

/// Overlays a static procedural grain on any view.
/// The grain pattern is seeded so it is identical on every render.
struct PaperTextureModifier: ViewModifier {
    /// 0.0 = invisible, 1.0 = full intensity. Each dot is drawn at (intensity × 0.04) opacity.
    let intensity: Double

    // Positions are pre-computed once at load time using a fixed seed.
    private static let grainCount = 6_000
    private static let grainPositions: [(CGFloat, CGFloat)] = {
        var rng = SeededRNG(seed: 42)
        return (0..<grainCount).map { _ in
            (CGFloat(rng.nextDouble()), CGFloat(rng.nextDouble()))
        }
    }()

    func body(content: Content) -> some View {
        content.overlay(
            Canvas { context, size in
                let opacity = intensity * 0.25
                guard opacity > 0 else { return }
                for (fx, fy) in Self.grainPositions {
                    let x = fx * size.width
                    let y = fy * size.height
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.black.opacity(opacity))
                    )
                }
            }
            .allowsHitTesting(false)
        )
    }
}

// MARK: - PaperTextureReadingModifier

/// Reads intensity from UserDefaults so the canvas updates in real time
/// when the debug slider in Settings is adjusted.
private struct PaperTextureReadingModifier: ViewModifier {
    @AppStorage("debugTextureIntensity") private var intensity: Double = 0.6

    func body(content: Content) -> some View {
        content.modifier(PaperTextureModifier(intensity: intensity))
    }
}

// MARK: - View Extension

extension View {
    /// Applies the paper grain texture. Intensity is read from UserDefaults
    /// (key "debugTextureIntensity"), falling back to 0.6.
    func paperTexture() -> some View {
        modifier(PaperTextureReadingModifier())
    }
}

// MARK: - DotsTextureModifier (color-parameterized, for debug preview)

struct DotsTextureModifier: ViewModifier {
    let intensity: Double
    let color: Color

    private static let grainCount = 6_000
    private static let grainPositions: [(CGFloat, CGFloat)] = {
        var rng = SeededRNG(seed: 42)
        return (0..<grainCount).map { _ in
            (CGFloat(rng.nextDouble()), CGFloat(rng.nextDouble()))
        }
    }()

    func body(content: Content) -> some View {
        content.overlay(
            Canvas { context, size in
                let opacity = intensity * 0.25
                guard opacity > 0 else { return }
                for (fx, fy) in Self.grainPositions {
                    let x = fx * size.width
                    let y = fy * size.height
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
                }
            }
            .allowsHitTesting(false)
        )
    }
}

// MARK: - TwoLayerTextureModifier (debug preview)

struct TwoLayerTextureModifier: ViewModifier {
    let intensity: Double
    let color: Color

    // Coarse layer: sparse, longer fiber strokes — seed 200
    private static let coarseFibers: [FiberSample] = {
        var rng = SeededRNG(seed: 200)
        return (0..<1_500).map { _ in
            FiberSample(
                fx:          CGFloat(rng.nextDouble()),
                fy:          CGFloat(rng.nextDouble()),
                length:      CGFloat(rng.nextDouble() * 3.0 + 2.0),   // 2–5pt
                angle:       CGFloat(rng.nextDouble() * .pi * 2),
                strokeWidth: CGFloat(rng.nextDouble() * 0.7 + 0.8),   // 0.8–1.5pt
                opacityMult: rng.nextDouble() * 0.4 + 0.6             // 0.6–1.0
            )
        }
    }()

    // Fine layer: dense tiny dots — seed 201. Tuple: (x, y, size) all as fractions/pt.
    private static let fineDots: [(CGFloat, CGFloat, CGFloat)] = {
        var rng = SeededRNG(seed: 201)
        return (0..<8_000).map { _ in
            (
                CGFloat(rng.nextDouble()),
                CGFloat(rng.nextDouble()),
                CGFloat(rng.nextDouble() * 0.5 + 0.5)   // 0.5–1.0pt
            )
        }
    }()

    func body(content: Content) -> some View {
        content.overlay(
            Canvas { context, size in
                guard intensity > 0 else { return }

                // Coarse fiber layer — 60% of intensity-scaled opacity
                for fiber in Self.coarseFibers {
                    let x = fiber.fx * size.width
                    let y = fiber.fy * size.height
                    let halfLen = fiber.length / 2
                    let dx = cos(fiber.angle) * halfLen
                    let dy = sin(fiber.angle) * halfLen
                    var path = Path()
                    path.move(to: CGPoint(x: x - dx, y: y - dy))
                    path.addLine(to: CGPoint(x: x + dx, y: y + dy))
                    let opacity = intensity * 0.25 * 0.60 * fiber.opacityMult
                    context.stroke(
                        path,
                        with: .color(color.opacity(opacity)),
                        lineWidth: fiber.strokeWidth
                    )
                }

                // Fine dot layer — 40% of intensity-scaled opacity
                let fineOpacity = intensity * 0.25 * 0.40
                for (fx, fy, dotSize) in Self.fineDots {
                    let x = fx * size.width
                    let y = fy * size.height
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(fineOpacity)))
                }
            }
            .allowsHitTesting(false)
        )
    }
}

// MARK: - FibersTextureModifier (debug preview)

private struct FiberSample {
    let fx: CGFloat        // x position as fraction [0,1]
    let fy: CGFloat        // y position as fraction [0,1]
    let length: CGFloat    // 1–4pt
    let angle: CGFloat     // radians, 0–2π
    let strokeWidth: CGFloat // 0.5–1.5pt
    let opacityMult: Double  // 0.5–1.0, per-fiber opacity variation
}

struct FibersTextureModifier: ViewModifier {
    let intensity: Double
    let color: Color

    private static let fiberSamples: [FiberSample] = {
        var rng = SeededRNG(seed: 99)
        return (0..<4_000).map { _ in
            FiberSample(
                fx:          CGFloat(rng.nextDouble()),
                fy:          CGFloat(rng.nextDouble()),
                length:      CGFloat(rng.nextDouble() * 3.0 + 1.0),
                angle:       CGFloat(rng.nextDouble() * .pi * 2),
                strokeWidth: CGFloat(rng.nextDouble() + 0.5),
                opacityMult: rng.nextDouble() * 0.5 + 0.5
            )
        }
    }()

    func body(content: Content) -> some View {
        content.overlay(
            Canvas { context, size in
                guard intensity > 0 else { return }
                for fiber in Self.fiberSamples {
                    let x = fiber.fx * size.width
                    let y = fiber.fy * size.height
                    let halfLen = fiber.length / 2
                    let dx = cos(fiber.angle) * halfLen
                    let dy = sin(fiber.angle) * halfLen
                    var path = Path()
                    path.move(to: CGPoint(x: x - dx, y: y - dy))
                    path.addLine(to: CGPoint(x: x + dx, y: y + dy))
                    let opacity = intensity * 0.25 * fiber.opacityMult
                    context.stroke(
                        path,
                        with: .color(color.opacity(opacity)),
                        lineWidth: fiber.strokeWidth
                    )
                }
            }
            .allowsHitTesting(false)
        )
    }
}

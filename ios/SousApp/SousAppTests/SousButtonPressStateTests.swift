import XCTest
import SwiftUI
@testable import SousApp

// MARK: - SousButtonPressStateTests

/// Decision 25: every button has a pressed state, and what "pressed" means depends
/// on whether the button is an outline, a wash or a fill.
///
/// These assert resolved hex values rather than token identity, in both appearances,
/// because the whole risk of this change is a colour that looks right in light mode
/// and vanishes in dark — Sous has tokens that deliberately do not invert.
@MainActor
final class SousButtonPressStateTests: XCTestCase {

    private func hex(_ color: Color, _ style: UIUserInterfaceStyle) -> String {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        guard a > 0 else { return "clear" }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func fill(_ s: SousButtonStyle, pressed: Bool, _ m: UIUserInterfaceStyle) -> String {
        hex(s.fill(enabled: true, pressed: pressed), m)
    }

    private func label(_ s: SousButtonStyle, pressed: Bool, _ m: UIUserInterfaceStyle) -> String {
        hex(s.label(enabled: true, pressed: pressed), m)
    }

    // MARK: Filled styles deepen by one step

    func test_primary_pressedFillDeepensInBothModes() {
        XCTAssertEqual(fill(.primary, pressed: false, .light), "#8B2E3F")
        XCTAssertEqual(fill(.primary, pressed: true, .light), "#6C2431", "burgundy.800")
        // Dark mode rests on the lifted burgundy, so "deeper" is the brand 700.
        XCTAssertEqual(fill(.primary, pressed: false, .dark), "#C45068")
        XCTAssertEqual(fill(.primary, pressed: true, .dark), "#8B2E3F", "burgundy.700")
        // The label stays white on burgundy in both modes (decision 2026-09-20).
        for mode in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertEqual(label(.primary, pressed: true, mode), "#FFFFFF")
        }
    }

    func test_inverse_pressedFillMovesTowardMidGrayFromEitherEnd() {
        // Light: near-black resting → lifts to warmGray.600.
        XCTAssertEqual(fill(.inverse, pressed: false, .light), "#1A1A1A")
        XCTAssertEqual(fill(.inverse, pressed: true, .light), "#757471")
        // Dark: cream resting → darkens to warmGray.500.
        XCTAssertEqual(fill(.inverse, pressed: false, .dark), "#F2EFE9")
        XCTAssertEqual(fill(.inverse, pressed: true, .dark), "#9A9590")
    }

    // MARK: Outline styles invert

    func test_secondary_invertsFillAndLabel() {
        for mode in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertEqual(fill(.secondary, pressed: false, mode), "clear")
            // The border colour becomes the fill…
            XCTAssertEqual(fill(.secondary, pressed: true, mode),
                           hex(.sousText, mode), "pressed fill must equal the resting border")
            // …and the label flips to the surface so it stays legible on it.
            XCTAssertEqual(label(.secondary, pressed: true, mode), hex(.sousBackground, mode))
            XCTAssertNotEqual(label(.secondary, pressed: true, mode),
                              fill(.secondary, pressed: true, mode),
                              "an inverted label must not match its own fill")
        }
    }

    func test_secondaryAccent_invertsToBurgundyWithWhiteLabel() {
        for mode in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertEqual(fill(.secondaryAccent, pressed: true, mode), hex(.sousTerracotta, mode))
            XCTAssertEqual(label(.secondaryAccent, pressed: true, mode), "#FFFFFF")
        }
    }

    // MARK: The text style inverts too

    func test_text_invertsRatherThanWashing() {
        // A pale wash was tried here first and measured 1.02:1 against the cream
        // canvas — see the contrast floor below, which is what caught it.
        for mode in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertEqual(fill(.text, pressed: false, mode), "clear")
            XCTAssertEqual(fill(.text, pressed: true, mode), hex(.sousTerracotta, mode))
            XCTAssertEqual(label(.text, pressed: true, mode), "#FFFFFF")
        }
    }

    // MARK: Invariants across every style

    func test_everyStyleChangesVisiblyWhenPressed() {
        let styles: [SousButtonStyle] = [.primary, .inverse, .secondary, .secondaryAccent, .text]
        for style in styles {
            for mode in [UIUserInterfaceStyle.light, .dark] {
                let resting = fill(style, pressed: false, mode) + label(style, pressed: false, mode)
                let pressed = fill(style, pressed: true, mode) + label(style, pressed: true, mode)
                XCTAssertNotEqual(resting, pressed,
                                  "\(style) shows no press feedback in \(mode == .dark ? "dark" : "light")")
            }
        }
    }

    func test_pressDoesNotDisturbTheDisabledLook() {
        // Disabled styling wins over pressed: a disabled button cannot be pressed,
        // and its muted treatment must not be overwritten by the pressed branch.
        XCTAssertEqual(hex(SousButtonStyle.inverse.fill(enabled: false, pressed: true), .light),
                       hex(.sousMuted, .light))
        XCTAssertEqual(hex(SousButtonStyle.secondary.label(enabled: false, pressed: true), .light),
                       hex(.sousMuted, .light))
    }

    // MARK: Borders are unchanged by a press

    func test_bordersSurviveThePress() {
        // The outline styles keep their border under the new fill — the shape of the
        // button must not change on press, only its weight.
        XCTAssertNotNil(SousButtonStyle.secondary.border(enabled: true, pressed: true))
        XCTAssertNotNil(SousButtonStyle.secondaryAccent.border(enabled: true, pressed: true))
        XCTAssertNil(SousButtonStyle.text.border(enabled: true, pressed: true))
    }

    // MARK: Contrast floor — the state has to be visible, not merely different

    /// WCAG relative luminance.
    private func luminance(_ hex: String) -> Double {
        let h = hex.dropFirst()
        let parts = stride(from: 0, to: 6, by: 2).map { i -> Double in
            let start = h.index(h.startIndex, offsetBy: i)
            let end = h.index(start, offsetBy: 2)
            return Double(UInt8(h[start..<end], radix: 16) ?? 0) / 255
        }
        let f = { (c: Double) in c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(parts[0]) + 0.7152 * f(parts[1]) + 0.0722 * f(parts[2])
    }

    private func contrast(_ a: String, _ b: String) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Every pressed state must differ from what it replaces by a visible margin.
    ///
    /// 1.25:1 is not an accessibility threshold — it is a floor below which a press
    /// simply cannot be seen. Both of the states this caught (a pale wash at 1.02:1,
    /// an adjacent ink shade at 1.09:1) looked perfectly reasonable as token names.
    func test_everyPressedStateClearsTheVisibilityFloor() {
        let floor = 1.25
        let canvas: (UIUserInterfaceStyle) -> String = { self.hex(.sousBackground, $0) }

        for mode in [UIUserInterfaceStyle.light, .dark] {
            let modeName = mode == .dark ? "dark" : "light"

            // Filled styles: the pressed fill against the resting fill.
            for style in [SousButtonStyle.primary, .inverse] {
                let ratio = contrast(fill(style, pressed: true, mode), fill(style, pressed: false, mode))
                XCTAssertGreaterThan(ratio, floor,
                    "\(style) pressed fill is only \(String(format: "%.2f", ratio)):1 from its resting fill in \(modeName)")
            }

            // Unfilled styles: the pressed fill arrives over the canvas, so that is
            // what it has to separate from.
            for style in [SousButtonStyle.secondary, .secondaryAccent, .text] {
                let ratio = contrast(fill(style, pressed: true, mode), canvas(mode))
                XCTAssertGreaterThan(ratio, floor,
                    "\(style) pressed fill is only \(String(format: "%.2f", ratio)):1 against the canvas in \(modeName)")
            }
        }
    }

    /// A pressed label must stay readable on the fill that arrives underneath it.
    func test_pressedLabelsStayLegibleOnTheirNewFill() {
        let styles: [SousButtonStyle] = [.primary, .inverse, .secondary, .secondaryAccent, .text]
        for style in styles {
            for mode in [UIUserInterfaceStyle.light, .dark] {
                let ratio = contrast(label(style, pressed: true, mode), fill(style, pressed: true, mode))
                XCTAssertGreaterThan(ratio, 4.0,
                    "\(style) pressed label reads at \(String(format: "%.1f", ratio)):1 on its pressed fill")
            }
        }
    }
}

import SwiftUI
import UIKit

// MARK: - Keyboard Prewarm

/// A zero-footprint UITextField kept in the view hierarchy while the recipe canvas is visible.
/// Toggling `shouldPrewarm` to true calls becomeFirstResponder() immediately. The sheet is
/// opened in the same runloop frame so both animations kick off simultaneously. The chat
/// input's @FocusState steals first responder on sheet appear — no explicit resign needed.
struct KeyboardPrewarmField: UIViewRepresentable {
    @Binding var shouldPrewarm: Bool

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.tintColor = .clear
        field.textColor = .clear
        field.backgroundColor = .clear
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.inputAssistantItem.leadingBarButtonGroups = []
        field.inputAssistantItem.trailingBarButtonGroups = []
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        guard shouldPrewarm else { return }
        uiView.becomeFirstResponder()
        shouldPrewarm = false
    }
}

// MARK: - BottomZoneView

/// The persistent bottom bar rendered as .overlay(alignment: .bottom) in ContentView.
///
/// Structure (top → bottom):
///   1. Active timer banners — zero or more rows, stacked downward; new banners add above
///   2. SousRule
///   3. Talk to Sous button
///   4. Chevron affordance hint
///
/// The Talk to Sous button is always the last item in the VStack, so its screen position
/// is determined by the bottom of the overlay — it never moves regardless of banner count.
///
/// ContentView measures this view's height via onHeightChange and applies a matching
/// .safeAreaInset to RecipeCanvasView so scroll content is never hidden behind the bar.
///
/// ThumbDrop (recipe canvas → chat) is handled by a root-level ThumbDropOverlay that
/// installs a UIPanGestureRecognizer on the window, covering the bottom 25% of the
/// screen. It uses OR commit logic (≥50pt translation OR ≥400pt/s peak velocity) and
/// fires the same slingshot haptic sequence as the chat→canvas direction.
struct BottomZoneView: View {
    var timerManager: StepTimerManager
    var onOpenChat: () -> Void
    var onPrewarmKeyboard: () -> Void = {}
    var onTimerBannerTap: (UUID) -> Void
    var onHeightChange: (CGFloat) -> Void
    var isEnabled: Bool = true

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if !timerManager.activeSessions.isEmpty {
                TimerBannerStack(timerManager: timerManager, onTapBanner: onTimerBannerTap)
                    .allowsHitTesting(true)
            }
            SousRule()
            Button {
                onPrewarmKeyboard()
                onOpenChat()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message")
                        .font(.system(size: 14, weight: .semibold))
                    Text("TALK TO SOUS")
                        .font(.sousButton)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.sousTerracotta)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.sousBackground)
            .offset(y: dragOffset)
            .zIndex(1) // keep button above chevron strip during drag translation
            .allowsHitTesting(true)
            // ThumbDrop affordance hint
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color.sousMuted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                .background(Color.sousBackground)
                .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
        .background(Color.sousBackground.ignoresSafeArea(edges: .bottom))
        // Report height to ContentView for the matching safeAreaInset on RecipeCanvasView.
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { onHeightChange(geo.size.height) }
                .onChange(of: geo.size.height) { _, h in onHeightChange(h) }
        })
        // Root-level ThumbDrop zone for the recipe canvas → chat direction.
        // ThumbDropOverlay installs a UIPanGestureRecognizer on the window and gates to
        // the bottom 25% of the screen (matching the chat→canvas side). The view lifecycle
        // auto-removes the recognizer when BottomZoneView leaves the hierarchy (i.e. when
        // the chat sheet opens), so no explicit isActive toggle is needed here.
        .background {
            ThumbDropOverlay(
                isActive: isEnabled,
                onOffsetChanged: { dragOffset = $0 },
                onCommit: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onOpenChat()
                },
                onCancel: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                },
                onUpwardCommit: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onOpenChat()
                }
            )
        }
    }
}

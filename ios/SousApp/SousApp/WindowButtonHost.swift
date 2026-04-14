import SwiftUI
import UIKit

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
/// installs a UIPanGestureRecognizer on the window, covering the bottom 30% of the
/// screen. It uses OR commit logic (≥50pt translation OR ≥400pt/s peak velocity) and
/// fires the same slingshot haptic sequence as the chat→canvas direction.
struct BottomZoneView: View {
    var timerManager: StepTimerManager
    var onOpenChat: () -> Void
    var onTimerBannerTap: (UUID) -> Void
    var onHeightChange: (CGFloat) -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if !timerManager.activeSessions.isEmpty {
                TimerBannerStack(timerManager: timerManager, onTapBanner: onTimerBannerTap)
            }
            SousRule()
            Button {
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
            // ThumbDrop affordance hint
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color.sousMuted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                .background(Color.sousBackground)
                .allowsHitTesting(false)
        }
        .background(Color.sousBackground.ignoresSafeArea(edges: .bottom))
        // Report height to ContentView for the matching safeAreaInset on RecipeCanvasView.
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { onHeightChange(geo.size.height) }
                .onChange(of: geo.size.height) { _, h in onHeightChange(h) }
        })
        // Root-level ThumbDrop zone for the recipe canvas → chat direction.
        // ThumbDropOverlay installs a UIPanGestureRecognizer on the window and gates to
        // the bottom 30% of the screen (matching the chat→canvas side). The view lifecycle
        // auto-removes the recognizer when BottomZoneView leaves the hierarchy (i.e. when
        // the chat sheet opens), so no explicit isActive toggle is needed here.
        .background {
            ThumbDropOverlay(
                isActive: true,
                onOffsetChanged: { dragOffset = $0 },
                onCommit: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onOpenChat()
                },
                onCancel: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            )
        }
    }
}

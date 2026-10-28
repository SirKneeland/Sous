import SwiftUI
import UIKit

// MARK: - ShadeView

/// The window shade: the recipe-navigation panel, pulled down over cook mode like
/// a roller blind.
///
/// It is a temporary layer, never a home screen — the recipe canvas stays mounted
/// and untouched underneath, so scroll position, checked ingredients, a recipe
/// still streaming in, a pending patch and every running timer survive the trip.
///
/// Shape, from top to bottom: the drawer's content, then the grab bar as the
/// shade's hem. The hem is the whole affordance. While the shade is coming down it
/// is the only part of it you can see — a burgundy bar reading RECIPES with the
/// chevron pointing the way it is travelling. Once the shade is open the same bar
/// turns around and says CLOSE.
struct ShadeView: View {
    @ObservedObject var store: AppStore
    var presentation: ShadePresentation
    var tuning: ShadeGesture
    var onSettings: () -> Void
    var onNewRecipe: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            panel(height: height)
                .frame(width: geo.size.width, height: height)
                // With Reduce Motion on the shade does not travel: it is already in
                // place and crossfades instead.
                .offset(y: reduceMotion ? 0 : -(1 - presentation.progress) * height)
                .opacity(reduceMotion ? Double(presentation.progress) : 1)
                .background {
                    dismissGesture(height: height)
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(presentation.isOpen || presentation.isClosing)
        // VoiceOver must not reach the canvas behind an open shade, and must not
        // reach the shade at all while it is away.
        .accessibilityHidden(!presentation.isVisible)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(named: Text("Close")) {
            presentation.close()
        }
        .onAppear { presentation.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, newValue in presentation.reduceMotion = newValue }
    }

    // MARK: - Panel

    private func panel(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            contents
                .opacity(presentation.showsContent ? 1 : 0)

            // Being pulled: one burgundy sheet with nothing on it but where it is
            // going. The panel's own footer and hem would otherwise show through
            // the peek as a second burgundy bar with a seam between them, which
            // reads as two things rather than one shade coming down.
            if !presentation.showsContent {
                Color.sousTerracotta
                    .overlay(alignment: .bottom) {
                        SousGrabBar.Lockup(title: "Recipes", direction: .down)
                            .padding(.bottom, ShadeMetrics.windowInsets.bottom)
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(height: height)
        .background(Color.sousBackground)
    }

    private var contents: some View {
        VStack(spacing: 0) {
            DrawerContent(
                store: store,
                isPresented: presentation.isVisible,
                topPadding: ShadeMetrics.windowInsets.top + 16,
                footerExtendsToSafeArea: false,
                onSettings: {
                    presentation.close { onSettings() }
                },
                onNewRecipe: {
                    presentation.close { onNewRecipe() }
                },
                onDismiss: {
                    presentation.close()
                }
            )

            // Always the dismiss affordance: while the shade is being pulled this
            // whole stack is hidden behind the sheet above, which draws its own.
            SousGrabBar(
                title: "Close",
                direction: .up,
                edge: .bottom,
                accessibilityActionLabel: "Close recipes",
                action: { presentation.close() }
            )

            // The hem reaches the bottom edge of the screen; the bar's own 52pt
            // stays clear of the home indicator.
            Color.sousTerracotta
                .frame(height: ShadeMetrics.windowInsets.bottom)
        }
    }

    // MARK: - Dismissal

    /// The grab bar is a ThumbDrop zone: swipe up anywhere in it and the shade
    /// follows the finger back up, one-to-one across the whole screen.
    ///
    /// ThumbDrop's own escalating haptic ramp runs on the way up; the medium impact
    /// on commit comes from `ShadePresentation`. Downward commits are ignored here —
    /// there is nowhere further down for the shade to go.
    private func dismissGesture(height: CGFloat) -> some View {
        ThumbDropOverlay(
            isActive: presentation.isOpen || presentation.isClosing,
            triggerZone: .viewEdge(.bottom, height: tuning.dismissZoneHeight),
            offsetClamp: ThumbDropOverlay.unlimitedOffset,
            // The shade tracks the finger exactly — it is a physical object being
            // pushed, not an element being nudged.
            damping: 1,
            commitDistance: tuning.dismissCommitDistance,
            commitVelocity: tuning.dismissCommitVelocity,
            onOffsetChanged: { offset in
                guard offset < 0 else {
                    if presentation.isClosing { presentation.driveClosing(progress: 1) }
                    return
                }
                presentation.beginClosing()
                presentation.driveClosing(progress: 1 - min(1, -offset / max(1, height)))
            },
            // A downward commit inside the zone is not a dismissal; let it settle back.
            onCommit: { presentation.finishClosing(commit: false) },
            onCancel: { presentation.finishClosing(commit: false) },
            onUpwardCommit: { presentation.finishClosing(commit: true) }
        )
    }

}

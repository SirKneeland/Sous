import SwiftUI
import SousCore
import UIKit

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var showSettings = false
    @State private var timerManager = StepTimerManager()
    /// stepId to scroll to in the recipe canvas. Set by timer banner taps.
    @State private var scrollToStepId: UUID? = nil
    /// stepId whose step row should be highlighted in terracotta. Cleared on any interaction.
    @State private var highlightedStepId: UUID? = nil
    @State private var gearFrame: CGRect = .zero
    /// Measured height of BottomZoneView. Applied as .safeAreaInset to RecipeCanvasView
    /// so scroll content is never hidden behind the bar.
    @State private var bottomZoneHeight: CGFloat = 0
    /// Controls whether the Ingredients section is expanded. Lifted here so it survives
    /// RecipeCanvasView being replaced by PatchReviewView.
    @State private var ingredientsExpanded: Bool = true
    /// Controls whether the completed steps section is expanded.
    @State private var stepsCompletedExpanded: Bool = true
    /// Whether the collapsible top nav bar (New / History / Settings) is currently revealed.
    @State private var navBarVisible: Bool = false
    /// True while the user is editing the recipe title inline.
    @State private var isTitleEditing: Bool = false

    private var hasDoneBanner: Bool { !timerManager.doneQueue.isEmpty }

    /// True when the recipe canvas is the active screen (not covered by a sheet or patch review).
    private var isRecipeCanvasActive: Bool {
        store.hasCanvas
            && !store.uiState.isSheetPresented
            && !store.uiState.isPatchReview
    }

    /// True when the bottom zone (banners + Talk to Sous button) should be visible.
    private var shouldShowBottomZone: Bool {
        store.hasCanvas
            && !store.uiState.isSheetPresented
            && !store.uiState.isPatchReview
            && !hasDoneBanner
            && !isTitleEditing
    }

    var body: some View {
        ZStack {
            Color.sousBackground.ignoresSafeArea()

            if case .patchReview(let recipe, let patchSet, let validation, _) = store.uiState {
                PatchReviewView(recipe: recipe, patchSet: patchSet, validation: validation, store: store)
            } else if !store.hasCanvas {
                ChatSheetView(
                    store: store,
                    isFullscreen: true,
                    onStartNew: { store.requestNewSession(); timerManager.clearAll() },
                    onOpenSettings: { showSettings = true },
                    onOpenRecents: { store.showRecentRecipes = true },
                    onOpenImport: { store.isShowingImportSheet = true }
                )
            } else {
                RecipeCanvasView(
                    recipe: store.uiState.recipe,
                    onMarkStepDone: { id in
                        if timerManager.isTimerActive(for: id) {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            return
                        }
                        store.send(.markStepDone(stepId: id))
                    },
                    onMarkStepUndone: { id in
                        store.send(.markStepUndone(stepId: id))
                    },
                    onMarkSubStepDone: { parentId, subId in
                        store.send(.markSubStepDone(parentStepId: parentId, subStepId: subId))
                    },
                    onMarkMiseEnPlaceDone: { id in store.markMiseEnPlaceDone(id) },
                    onTriggerMiseEnPlace: { store.triggerMiseEnPlace() },
                    onOpenSettings: { showSettings = true },
                    onStartNew: { store.requestNewSession(); timerManager.clearAll() },
                    onOpenRecents: { store.showRecentRecipes = true },
                    onResetRecipe: {
                        store.resetRecipe()
                        timerManager.clearAll()
                        ingredientsExpanded = true
                        stepsCompletedExpanded = true
                    },
                    onUpdateTitle: { newTitle in store.updateTitle(newTitle) },
                    onEditingTitleChanged: { editing in isTitleEditing = editing },
                    onAskSousAbout: { type, text in
                        let rowType: QuotedRowContext.RowType = type == "ingredient" ? .ingredient : .step
                        store.openChatWithRowContext(type: rowType, text: text)
                    },
                    miseEnPlaceIsLoading: store.miseEnPlaceIsLoading,
                    miseEnPlaceError: store.miseEnPlaceError,
                    llmDebugStatus: store.llmDebugStatus,
                    timerManager: timerManager,
                    scrollToStepId: $scrollToStepId,
                    highlightedStepId: $highlightedStepId,
                    ingredientsExpanded: $ingredientsExpanded,
                    stepsCompletedExpanded: $stepsCompletedExpanded,
                    navBarVisible: $navBarVisible,
                    bottomZoneHeight: bottomZoneHeight
                )
                // Reserve space for the collapsible nav bar so list content
                // is never hidden behind it when revealed.
                // 44pt keeps the thrash-free gap wider than the inset shift
                // (collapse at -60 → after inset removed position jumps to -16, which
                //  stays below the reveal threshold of -10).
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: navBarVisible && isRecipeCanvasActive ? 44 : 0)
                }
                // Reserve space equal to the bottom zone height so the last scroll item
                // is never hidden behind the bar.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: shouldShowBottomZone ? bottomZoneHeight : 0)
                }

                if store.uiState.isSheetPresented && !store.uiState.isPatchReview {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        }
        .coordinateSpace(name: "contentRoot")
        // Bottom zone: timer banners (growing upward) + Talk to Sous button.
        // Rendered as an overlay so it never affects the recipe canvas layout.
        .overlay(alignment: .bottom) {
            if shouldShowBottomZone {
                BottomZoneView(
                    timerManager: timerManager,
                    onOpenChat: { store.send(.openChat) },
                    onTimerBannerTap: { stepId in
                        scrollToStepId = stepId
                        highlightedStepId = stepId
                    },
                    onHeightChange: { bottomZoneHeight = $0 }
                )
            }
        }
        .onAppear {
            timerManager.registerNotificationDelegate()
            timerManager.isRecipeCanvasActive = isRecipeCanvasActive
        }
        .onChange(of: isRecipeCanvasActive) { _, active in
            timerManager.isRecipeCanvasActive = active
        }
        .onChange(of: store.hasCanvas) { _, hasCanvas in
            // Show nav bar when the canvas first appears (user is at the top).
            if hasCanvas { navBarVisible = true }
        }
        .onChange(of: store.uiState.recipe.id) { _, _ in
            ingredientsExpanded = true
            stepsCompletedExpanded = true
        }
        .onChange(of: store.uiState) { prev, current in
            // Auto-expand ingredients when accepting a patch that has ingredient changes.
            if case .patchReview(_, let patchSet, _, _) = prev,
               case .recipeOnly = current,
               patchSet.patches.contains(where: {
                   switch $0 {
                   case .addIngredient, .updateIngredient, .removeIngredient: return true
                   default: return false
                   }
               }) {
                ingredientsExpanded = true
            }
        }
        .sheet(isPresented: Binding(
            get: { store.hasCanvas && store.uiState.isSheetPresented && !store.uiState.isPatchReview },
            set: { isPresented in
                if !isPresented { store.send(.closeChat) }
            }
        )) {
            ChatSheetView(store: store)
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
        .sheet(isPresented: $store.showRecentRecipes) {
            RecentRecipesView(store: store, onDismiss: { store.showRecentRecipes = false })
        }
        .sheet(isPresented: $store.isShowingImportSheet) {
            RecipeImportSheet(store: store, onCancel: {
                store.importError = nil
                store.isShowingImportSheet = false
            })
        }
        .onPreferenceChange(GearButtonFrameKey.self) { gearFrame = $0 }
        .overlay {
            // Only show when nav bar is visible so the callout arrow points at the
            // actual on-screen gear button.
            if !store.hasAPIKey && gearFrame != .zero && navBarVisible && isRecipeCanvasActive {
                APIKeyCallout(gearFrame: gearFrame)
                    .allowsHitTesting(false)
            }
        }
        // Collapsible top nav bar: burgundy bar below the status bar with New / History / Settings.
        // The bar's background also fills the status bar area via ignoresSafeArea.
        .overlay(alignment: .top) {
            if isRecipeCanvasActive {
                CollapsibleNavBar(
                    isVisible: navBarVisible,
                    onNew: { store.requestNewSession() },
                    onHistory: { store.showRecentRecipes = true },
                    onSettings: { showSettings = true }
                )
                .animation(.easeInOut(duration: 0.2), value: navBarVisible)
            }
        }
        // Transparent tap zone covering the top of the screen to trigger nav reveal.
        // Only active when nav is collapsed; removed when nav is visible so buttons receive taps.
        .overlay(alignment: .top) {
            if isRecipeCanvasActive && !navBarVisible {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .ignoresSafeArea(edges: .top)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { navBarVisible = true }
                    }
            }
        }
        .overlay(alignment: .bottom) {
            if let session = timerManager.doneQueue.first {
                TimerDoneBanner(session: session) { stepId in
                    timerManager.dismissDone(session)
                    scrollToStepId = stepId
                    highlightedStepId = stepId
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: timerManager.doneQueue.count)
            }
        }
    }
}

// MARK: - Collapsible Nav Bar

/// Burgundy bar that slides down from below the status bar.
///
/// When `isVisible` is false, only the status bar area has a burgundy background
/// (via `.background(...ignoresSafeArea(.top))`). When true, the 52pt button row
/// slides in below the status bar containing New, History, and Settings icons.
struct CollapsibleNavBar: View {
    var isVisible: Bool
    var onNew: () -> Void
    var onHistory: () -> Void
    var onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                HStack(spacing: 0) {
                    Spacer()
                    navButton("plus", action: onNew)
                    Spacer()
                    navButton("books.vertical.fill", action: onHistory)
                    Spacer()
                    navButton("gearshape", action: onSettings)
                        .background(GeometryReader { geo in
                            Color.clear.preference(
                                key: GearButtonFrameKey.self,
                                value: geo.frame(in: .named("contentRoot"))
                            )
                        })
                    Spacer()
                }
                .frame(height: 44)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        // The background extends behind the status bar via ignoresSafeArea.
        // This keeps the status bar burgundy even when the button row is collapsed.
        .background(Color.sousTerracotta.ignoresSafeArea(edges: .top))
        .animation(.easeInOut(duration: 0.25), value: isVisible)
    }

    @ViewBuilder
    private func navButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}

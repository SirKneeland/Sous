import SwiftUI
import SousCore
import UIKit

struct ContentView: View {
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var storeKit: StoreKitManager
    @StateObject private var store = AppStore()
    @StateObject private var voiceCoordinator = VoiceModeCoordinator()
    @State private var showSettings = false
    /// Which billing wall (if any) is being presented over the app.
    @State private var billingPresentation: BillingPresentation = .none
    /// Usage snapshot for the cap-reached hard stop.
    @State private var capSummary: UsageSummary?
    @State private var navigateToMemoriesInSettings = false
    @State private var timerManager = StepTimerManager()
    /// stepId to scroll to in the recipe canvas. Set by timer banner taps.
    @State private var scrollToStepId: UUID? = nil
    /// stepId whose step row should be highlighted in terracotta. Cleared on any interaction.
    @State private var highlightedStepId: UUID? = nil
    /// Measured height of BottomZoneView. Applied as .safeAreaInset to RecipeCanvasView
    /// so scroll content is never hidden behind the bar.
    @State private var bottomZoneHeight: CGFloat = 0
    @State private var navBarVisible: Bool = false
    /// True while the user is editing the recipe title inline.
    @State private var isTitleEditing: Bool = false
    @State private var isCanvasEnabled: Bool = true
    /// Driven by HistoryDrawer each animation frame — offsets the canvas rightward as drawer opens.
    @State private var canvasOffset: CGFloat = 0
    /// Drives the chat overlay vertical offset. Set explicitly per-direction so open and
    /// close can use different animations (spring bounce on open, straight easeIn on close).
    @State private var chatOverlayOffset: CGFloat = UIScreen.main.bounds.height
    @State private var isCameraPresented: Bool = false

    private var hasDoneBanner: Bool { !timerManager.doneQueue.isEmpty }

    /// Voice mode is hidden during the free trial and in soft wall (BillingGate).
    private var voiceEnabled: Bool { BillingGate.isVoiceAvailable(authState.entitlement) }

    /// Gate a generative entry point (New Recipe / Import) behind billing. Soft-wall
    /// users get the paywall; paid users at the monthly cap get the hard stop; anyone
    /// else proceeds. The backend still enforces independently on the proxy call.
    private func gateGenerative(_ proceed: @escaping () -> Void) {
        switch authState.entitlement {
        case .softWall:
            billingPresentation = .paywall
        case .subscriber, .grace:
            Task {
                let summary = await store.fetchUsageSummary()
                if let s = summary, s.recipesUsed >= s.recipeCap {
                    capSummary = s
                    billingPresentation = .capReached
                } else {
                    proceed()
                }
            }
        case .byok, .trialing, .none:
            proceed()
        }
    }

    /// True when the chat overlay should be visible above the recipe canvas.
    private var isChatOpen: Bool {
        store.hasCanvas && store.uiState.isSheetPresented && !store.uiState.isPatchReview
    }

    /// True when the recipe canvas is the active screen (not covered by a sheet or patch review).
    private var isRecipeCanvasActive: Bool {
        store.hasCanvas
            && !store.uiState.isSheetPresented
            && !store.uiState.isPatchReview
    }

    /// True when the bottom zone (banners + Talk to Sous button) should be visible.
    private var isVoiceActive: Bool { store.uiState.isVoiceActive }

    private var shouldShowBottomZone: Bool {
        store.hasCanvas
            && !store.uiState.isSheetPresented
            && !store.uiState.isPatchReview
            && !hasDoneBanner
            && !isTitleEditing
            && !isVoiceActive
    }

    var body: some View {
        Group {
            switch authState.status {
            case .unknown:
                // Neutral loading state — not the sign-in screen, not the main app.
                ZStack {
                    Color.sousBackground.ignoresSafeArea()
                    Text("SOUS")
                        .font(.sousLogotype)
                        .kerning(2)
                        .foregroundStyle(Color.sousMuted)
                }
            case .signedOut:
                SignInView()
            case .signedIn:
                appContent
            }
        }
        // Wire the backend once, regardless of auth status, so the sign-in
        // hydrate hook and 401 handler are in place before sign-in completes.
        .task {
            store.attachBackend(SousAPIClient.shared)
            // Lets AppStore fork BYOK (direct OpenAI) vs. non-BYOK (Sous proxy) per call.
            store.entitlementProvider = { [weak authState] in authState?.entitlement }
            SousAPIClient.shared.onUnauthorized = { [weak authState] in
                authState?.handleUnauthorized()
            }
            authState.onSignInHydrate = { [weak store] in
                await store?.hydrateFromBackend()
            }
        }
    }

    private var appContent: some View {
        ZStack {
            Color.sousBackground.ignoresSafeArea()

            if case .patchReview(let recipe, let patchSet, let validation, _) = store.uiState {
                PatchReviewView(recipe: recipe, patchSet: patchSet, validation: validation, store: store, voiceCoordinator: voiceCoordinator)
            } else if !store.hasCanvas {
                ChatSheetView(
                    store: store,
                    isFullscreen: true,
                    onStartNew: { gateGenerative { store.requestNewSession(); timerManager.clearAll() } },
                    onOpenSettings: { showSettings = true },
                    onOpenRecents: { store.showRecentRecipes = true },
                    onOpenImport: { gateGenerative { store.isShowingImportSheet = true } },
                    onNavigateToMemories: { showSettings = true; navigateToMemoriesInSettings = true }
                )
                .offset(x: canvasOffset)
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
                    onMarkMiseEnPlaceDone: { id in store.markMiseEnPlaceDone(id) },
                    onMarkMiseEnPlaceUndone: { id in store.markMiseEnPlaceUndone(id) },
                    onTriggerMiseEnPlace: { store.triggerMiseEnPlace() },
                    onOpenSettings: { showSettings = true },
                    onStartNew: { gateGenerative { store.requestNewSession(); timerManager.clearAll() } },
                    onOpenRecents: { store.showRecentRecipes = true },
                    onResetRecipe: {
                        store.resetRecipe()
                        timerManager.clearAll()
                    },
                    onRestoreOriginalRecipe: {
                        store.restoreOriginalRecipe()
                        timerManager.clearAll()
                    },
                    onRescaleServings: { newServings in
                        store.requestServingsRescale(to: newServings)
                    },
                    preferredServingSize: store.userPreferences.servingSize,
                    originalRecipe: store.originalRecipe,
                    onUpdateTitle: { newTitle in store.updateTitle(newTitle) },
                    onEditingTitleChanged: { editing in isTitleEditing = editing },
                    onAskSousAbout: { type, text in
                        let rowType: QuotedRowContext.RowType = type == "ingredient" ? .ingredient : .step
                        store.openChatWithRowContext(type: rowType, text: text)
                    },
                    isStreamingRecipe: store.isStreamingRecipe,
                    miseEnPlaceIsLoading: store.miseEnPlaceIsLoading,
                    miseEnPlaceError: store.miseEnPlaceError,
                    llmDebugStatus: store.llmDebugStatus,
                    timerManager: timerManager,
                    scrollToStepId: $scrollToStepId,
                    highlightedStepId: $highlightedStepId,
                    ingredientsExpanded: $store.ingredientsExpanded,
                    stepsCompletedExpanded: $store.stepsCompletedExpanded,
                    miseEnPlaceExpanded: $store.miseEnPlaceExpanded,
                    navBarVisible: $navBarVisible,
                    bottomZoneHeight: bottomZoneHeight
                )
                .disabled(!isCanvasEnabled)
                // Extend the paper-texture background under the home indicator. The
                // List's own .contentMargins(.bottom) reserves the scroll-content space
                // for the Talk to Sous bar, so no .safeAreaInset is needed here (a second
                // one double-counted the inset and contributed to the snap-back).
                .ignoresSafeArea(edges: .bottom)
                .offset(x: canvasOffset)

                // Scrim dims the canvas while chat is open. Hidden when camera is presented
                // so it doesn't darken the overlay visible behind the camera sheet corners.
                Color.black.opacity(isChatOpen && !isCameraPresented ? 0.4 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.25), value: isChatOpen)
                    .animation(.easeOut(duration: 0.2), value: isCameraPresented)

                // Chat overlay — always in the ZStack so the TextEditor is permanently in
                // the view hierarchy. This means @FocusState fires instantly on open,
                // and the keyboard rises in the same frame the overlay starts animating.
                ChatSheetView(store: store, isPresented: isChatOpen, onOpenSettings: { showSettings = true }, onCameraPresented: { isCameraPresented = $0 }, onNavigateToMemories: { showSettings = true; navigateToMemoriesInSettings = true })
                    .ignoresSafeArea(.container, edges: .bottom)
                    .offset(y: chatOverlayOffset)
                    .opacity(isChatOpen ? 1 : 0)
                    .allowsHitTesting(isChatOpen)
                    .animation(.easeOut(duration: 0.25), value: isChatOpen)
                    .onChange(of: isChatOpen) { _, newValue in
                        if newValue {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                                chatOverlayOffset = 0
                            }
                        } else {
                            withAnimation(.easeIn(duration: 0.28)) {
                                chatOverlayOffset = UIScreen.main.bounds.height
                            }
                        }
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
                    onOpenVoiceMode: {
                        store.send(.openVoiceMode)
                        Task { await voiceCoordinator.activate() }
                    },
                    onTimerBannerTap: { stepId in
                        scrollToStepId = stepId
                        highlightedStepId = stepId
                    },
                    onHeightChange: { bottomZoneHeight = $0 },
                    isEnabled: isCanvasEnabled,
                    voiceEnabled: voiceEnabled
                )
                .offset(x: canvasOffset)
                .disabled(!isCanvasEnabled)
            }
        }
        .overlay(alignment: .bottom) {
            if voiceCoordinator.isActive && !store.uiState.isPatchReview {
                VoiceBarView(
                    coordinator: voiceCoordinator,
                    onExit: {
                        voiceCoordinator.deactivate()
                        store.send(.closeVoiceMode)
                    },
                    onAccept: { store.send(.acceptPatch) },
                    onReject: { store.send(.rejectPatch(userText: "")) }
                )
                .background {
                    ThumbDropOverlay(
                        isActive: true,
                        onOffsetChanged: { _ in },
                        onCommit: {},
                        onCancel: {},
                        onVoiceModeExit: {
                            voiceCoordinator.deactivate()
                            store.send(.closeVoiceMode)
                        }
                    )
                }
            }
        }
        .onAppear {
            voiceCoordinator.configure(store: store)
            voiceCoordinator.onExit = { store.send(.closeVoiceMode) }
            voiceCoordinator.onVoiceAccept = { store.send(.acceptPatch) }
            voiceCoordinator.onVoiceReject = { store.send(.rejectPatch(userText: "")) }
            timerManager.registerNotificationDelegate()
            timerManager.isRecipeCanvasActive = isRecipeCanvasActive
        }
        .onChange(of: isRecipeCanvasActive) { _, active in
            timerManager.isRecipeCanvasActive = active
        }
        .onChange(of: store.hasCanvas) { _, hasCanvas in
            if hasCanvas { navBarVisible = true }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store, authState: authState, navigateToMemories: $navigateToMemoriesInSettings)
        }
        .overlay {
            HistoryDrawer(
                store: store,
                isCanvasEnabled: $isCanvasEnabled,
                canvasOffset: $canvasOffset,
                onNewRecipe: { gateGenerative { store.requestNewSession(); timerManager.clearAll() } },
                onSettings: { showSettings = true },
                isHamburgerVisible: !isChatOpen
            )
        }
        .sheet(isPresented: $store.isShowingImportSheet) {
            RecipeImportSheet(store: store, onCancel: {
                store.importError = nil
                store.isShowingImportSheet = false
            })
        }
        .fullScreenCover(isPresented: Binding(
            get: { billingPresentation != .none },
            set: { if !$0 { billingPresentation = .none } }
        )) {
            switch billingPresentation {
            case .paywall:
                // Full-screen cover lacks a swipe-to-dismiss back gesture, so a
                // close control is shown to avoid trapping the user (deviation from
                // DesignSpec's "no dismiss" — never trap; the backend still gates).
                PaywallView(
                    storeKit: storeKit,
                    showsCloseButton: true,
                    onClose: { billingPresentation = .none }
                )
                .onChange(of: authState.entitlement) { _, newValue in
                    if newValue == .subscriber || newValue == .grace { billingPresentation = .none }
                }
            case .capReached:
                CapReachedView(
                    recipesUsed: capSummary?.recipesUsed ?? 0,
                    recipeCap: capSummary?.recipeCap ?? 100,
                    resetsInDays: capSummary?.resetsInDays ?? 0,
                    userEmail: authState.profile?.email,
                    accountId: authState.profile?.userId,
                    onClose: { billingPresentation = .none }
                )
            case .none:
                EmptyView()
            }
        }
        .alert("Convert Units?", isPresented: $store.showUnitConversionPrompt) {
            Button("Convert") { store.convertImportedRecipeUnits() }
                .keyboardShortcut(.defaultAction)
            Button("Keep Original", role: .cancel) { store.showUnitConversionPrompt = false }
        } message: {
            let detected = store.userPreferences.preferredUnitSystem == .metric ? "imperial" : "metric"
            let preferred = store.userPreferences.preferredUnitSystem == .metric ? "metric" : "imperial"
            Text("This recipe uses \(detected) units. Would you like to convert it to \(preferred)?")
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


#Preview {
    ContentView()
        .environmentObject(AuthState())
        .environmentObject(StoreKitManager(validateReceipt: { _ in }, listenForTransactions: false))
}

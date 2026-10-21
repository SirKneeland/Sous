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
    /// The window shade — the recipe-navigation panel pulled down over cook mode.
    @State private var shade = ShadePresentation()
    /// Mirrored out of the canvas's scroll geometry; gates the shade's pull-down.
    @State private var isCanvasAtTop: Bool = true
    /// How far the Talk to Sous bar has been dragged down by the shade's bar pull.
    @State private var bottomBarPullOffset: CGFloat = 0

    // MARK: - TEMP: shade tunables
    //
    // Motion, which the design system has no tokens for yet (Milestone 32). These
    // live in the Settings DEBUG section until they have been felt on a device.
    @AppStorage(ShadeTuning.enabledKey) private var shadeNavigationEnabled: Bool = true
    @AppStorage(ShadeTuning.pullCommitDistanceKey) private var shadePullCommitDistance: Double = Double(ShadeTuningValues.Defaults.pullCommitDistance)
    @AppStorage(ShadeTuning.pullCommitVelocityKey) private var shadePullCommitVelocity: Double = Double(ShadeTuningValues.Defaults.pullCommitVelocity)
    @AppStorage(ShadeTuning.pullResistanceKey) private var shadePullResistance: Double = Double(ShadeTuningValues.Defaults.pullResistance)
    @AppStorage(ShadeTuning.peekAppearDistanceKey) private var shadePeekAppearDistance: Double = Double(ShadeTuningValues.Defaults.peekAppearDistance)
    @AppStorage(ShadeTuning.openResponseKey) private var shadeOpenResponse: Double = ShadeTuningValues.Defaults.openResponse
    @AppStorage(ShadeTuning.openDampingKey) private var shadeOpenDamping: Double = ShadeTuningValues.Defaults.openDamping
    @AppStorage(ShadeTuning.closeResponseKey) private var shadeCloseResponse: Double = ShadeTuningValues.Defaults.closeResponse
    @AppStorage(ShadeTuning.closeDampingKey) private var shadeCloseDamping: Double = ShadeTuningValues.Defaults.closeDamping
    @AppStorage(ShadeTuning.dismissZoneHeightKey) private var shadeDismissZoneHeight: Double = Double(ShadeTuningValues.Defaults.dismissZoneHeight)
    @AppStorage(ShadeTuning.dismissCommitDistanceKey) private var shadeDismissCommitDistance: Double = Double(ShadeTuningValues.Defaults.dismissCommitDistance)
    @AppStorage(ShadeTuning.dismissCommitVelocityKey) private var shadeDismissCommitVelocity: Double = Double(ShadeTuningValues.Defaults.dismissCommitVelocity)

    private var shadeTuning: ShadeTuningValues {
        ShadeTuningValues(
            pullCommitDistance: CGFloat(shadePullCommitDistance),
            pullCommitVelocity: CGFloat(shadePullCommitVelocity),
            pullResistance: CGFloat(shadePullResistance),
            peekAppearDistance: CGFloat(shadePeekAppearDistance),
            openResponse: shadeOpenResponse,
            openDamping: shadeOpenDamping,
            closeResponse: shadeCloseResponse,
            closeDamping: shadeCloseDamping,
            dismissZoneHeight: CGFloat(shadeDismissZoneHeight),
            dismissCommitDistance: CGFloat(shadeDismissCommitDistance),
            dismissCommitVelocity: CGFloat(shadeDismissCommitVelocity)
        )
    }

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
            // The shade's grab bar owns the bottom of the screen once the shade is
            // actually down there. During an opening pull the shade is still only
            // at the top, so the bar stays — see `coversBottomZone`.
            && !shade.coversBottomZone
    }

    /// True on every screen the shade is responsible for navigating away from:
    /// cook mode, whatever is happening on top of it. This is what hides the
    /// hamburger and reclaims the title's inset — deliberately coarser than
    /// `canPullShade`, so the button does not blink back during a title edit.
    private var shadeGovernsCanvas: Bool {
        shadeNavigationEnabled && store.hasCanvas
    }

    /// Where the pull-down is actually armed. Chat, voice, title editing and patch
    /// review each take the canvas away; the left-edge drawer owns the gesture
    /// space while it is open.
    private var canPullShade: Bool {
        shadeGovernsCanvas
            && !isChatOpen
            && !store.uiState.isSheetPresented
            && !store.uiState.isPatchReview
            && !isVoiceActive
            && !isTitleEditing
            && !store.showRecentRecipes
            && isCanvasEnabled
            && shade.isClosed
    }

    /// The band of the screen the bottom bar owns. Everything above it belongs to
    /// the canvas. The shade can be pulled from either, and the two gestures are
    /// kept apart by where the touch starts rather than by what it does.
    private var bottomBarBand: Range<CGFloat> {
        ThumbDropOverlay.defaultZoneTopY ..< (UIScreen.main.bounds.height + 1)
    }

    private var canvasBand: Range<CGFloat> {
        0 ..< ThumbDropOverlay.defaultZoneTopY
    }

    /// The canvas counts as frontmost only when nothing is over it — the shade
    /// included, so a timer finishing behind the shade still raises its notification.
    private var isCanvasFrontmost: Bool {
        isRecipeCanvasActive && !shade.isVisible
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
                        .kerning(SousType.wordmarkTracking)
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
#if DEBUG
            if let fixture = DebugFixture.requested() {
                store.applyDebugFixture(fixture)
                switch fixture {
                case .paywall:
                    billingPresentation = .paywall
                case .capReached:
                    capSummary = DebugFixture.cappedUsage()
                    billingPresentation = .capReached
                case .canvas, .review, .explore, .memoryToast, .importLoading, .photoFailed,
                     .miseEnPlace, .attachPreparing, .attachFailed, .chatRetry, .chatWall:
                    // importLoading presents itself: applyDebugFixture sets
                    // isShowingImportSheet, which the canvas already observes.
                    break
                }
            }
#endif
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
                    bottomZoneHeight: bottomZoneHeight,
                    reservesHamburgerInset: !shadeGovernsCanvas,
                    isScrolledToTop: $isCanvasAtTop
                )
                .disabled(!isCanvasEnabled)
                // Pull down past the top of the canvas to bring the shade down. A
                // background on the canvas, so the window recognizer is removed the
                // moment the canvas is.
                .background {
                    if shadeNavigationEnabled {
                        ShadePullInstaller(
                            isActive: canPullShade,
                            isAtTop: isCanvasAtTop,
                            startYRange: canvasBand,
                            tuning: shadeTuning,
                            shadeHeight: UIScreen.main.bounds.height,
                            onBegin: { shade.beginOpening() },
                            onProgress: { progress, _ in shade.driveOpening(progress: progress) },
                            onEnd: { shade.finishOpening(commit: $0) }
                        )
                    }
                }
                .accessibilityActions {
                    if shadeGovernsCanvas {
                        Button("Show recipes") { shade.open() }
                    }
                }
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
                    voiceEnabled: voiceEnabled,
                    pullOffset: bottomBarPullOffset
                )
                .offset(x: canvasOffset)
                .disabled(!isCanvasEnabled)
                // The shade's second entry point: pull the bar down and the shade
                // comes down from the top. Same gesture engine, same haptics, its
                // own shorter distances — a thumb on the bar has about 90pt of
                // screen left beneath it.
                .background {
                    if shadeNavigationEnabled {
                        ShadePullInstaller(
                            isActive: canPullShade,
                            requiresCanvasAtTop: false,
                            isAtTop: isCanvasAtTop,
                            startYRange: bottomBarBand,
                            tuning: shadeTuning.forBarPull,
                            shadeHeight: UIScreen.main.bounds.height,
                            onBegin: { shade.beginOpening() },
                            onProgress: { progress, pull in
                                shade.driveOpening(progress: progress)
                                // The bar yields under the thumb exactly as it did
                                // when this drag opened chat: 65% of the travel,
                                // capped at 60pt.
                                bottomBarPullOffset = min(pull * 0.65, 60)
                            },
                            onEnd: { commit in
                                shade.finishOpening(commit: commit)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    bottomBarPullOffset = 0
                                }
                            }
                        )
                    }
                }
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
            timerManager.isRecipeCanvasActive = isCanvasFrontmost
        }
        .onChange(of: isCanvasFrontmost) { _, active in
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
                isHamburgerVisible: !isChatOpen && !shadeGovernsCanvas,
                isEdgeSwipeEnabled: !shade.isVisible
            )
        }
        // The shade is the last overlay, so it covers the bottom zone, the voice
        // bar, the drawer's hamburger and the timer banners — everything.
        .overlay {
            if shadeGovernsCanvas {
                ShadeView(
                    store: store,
                    presentation: shade,
                    tuning: shadeTuning,
                    onSettings: { showSettings = true },
                    onNewRecipe: { gateGenerative { store.requestNewSession(); timerManager.clearAll() } }
                )
            }
        }
        .sheet(isPresented: $store.isShowingImportSheet) {
            RecipeImportSheet(store: store, onCancel: {
                store.importError = nil
                store.isShowingImportSheet = false
            })
        }
        // Milestone 30: a failed chat turn that hit a wall routes here. The cap CTA
        // reuses gateGenerative so a trial user sees the paywall and a subscriber at
        // the cap sees the hard stop — the same fork every other entry point uses.
        .onChange(of: store.billingWallRequested) { _, requested in
            guard requested else { return }
            store.billingWallRequested = false
            gateGenerative {}
        }
        .onChange(of: store.signInWallRequested) { _, requested in
            guard requested else { return }
            store.signInWallRequested = false
            authState.handleUnauthorized()
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

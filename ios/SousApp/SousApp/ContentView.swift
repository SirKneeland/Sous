import SwiftUI
import SousCore

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var showSettings = false
    @StateObject private var windowButtonModel = TalkToSousWindowModel()

    private var shouldShowTalkToSousButton: Bool {
        store.hasCanvas && !store.uiState.isSheetPresented && !store.uiState.isPatchReview
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
                    onStartNew: { store.requestNewSession() },
                    onOpenSettings: { showSettings = true },
                    onOpenRecents: { store.showRecentRecipes = true }
                )
            } else {
                RecipeCanvasView(
                    recipe: store.uiState.recipe,
                    onMarkStepDone: { id in store.send(.markStepDone(stepId: id)) },
                    onOpenSettings: { showSettings = true },
                    onStartNew: { store.requestNewSession() },
                    onOpenRecents: { store.showRecentRecipes = true },
                    llmDebugStatus: store.llmDebugStatus
                )

                if store.uiState.isSheetPresented && !store.uiState.isPatchReview {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        }
        // Installs the Talk to Sous bar directly into UIWindow — no SwiftUI ancestor can clip it
        .background(
            TalkToSousWindowHost(model: windowButtonModel)
                .frame(width: 0, height: 0)
        )
        .onAppear {
            windowButtonModel.onOpenChat = { store.send(.openChat) }
            windowButtonModel.isVisible = shouldShowTalkToSousButton
        }
        .onChange(of: shouldShowTalkToSousButton) { newValue in
            windowButtonModel.isVisible = newValue
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
    }
}

#Preview {
    ContentView()
}

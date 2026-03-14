import SwiftUI
import SousCore

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.sousBackground.ignoresSafeArea()

            if case .patchReview(let recipe, let patchSet, let validation, _) = store.uiState {
                PatchReviewView(recipe: recipe, patchSet: patchSet, validation: validation, store: store)
            } else if !store.hasCanvas {
                ChatSheetView(
                    store: store,
                    isFullscreen: true,
                    onOpenSettings: { showSettings = true },
                    onOpenRecents: { store.showRecentRecipes = true }
                )
            } else {
                RecipeCanvasView(
                    recipe: store.uiState.recipe,
                    onOpenChat: { store.send(.openChat) },
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
        .sheet(isPresented: Binding(
            get: { store.hasCanvas && store.uiState.isSheetPresented && !store.uiState.isPatchReview },
            set: { isPresented in
                if !isPresented { store.send(.closeChat) }
            }
        )) {
            ChatSheetView(store: store)
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

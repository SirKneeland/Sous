import SwiftUI
import SousCore

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            if case .patchReview(let recipe, let patchSet, let validation, _) = store.uiState {
                PatchReviewView(recipe: recipe, patchSet: patchSet, validation: validation, store: store)
            } else {
                RecipeCanvasView(
                    recipe: store.uiState.recipe,
                    onOpenChat: { store.send(.openChat) },
                    onMarkStepDone: { id in store.send(.markStepDone(stepId: id)) },
                    onOpenSettings: { showSettings = true },
                    llmDebugStatus: store.llmDebugStatus
                )
            }

            if store.uiState.isSheetPresented && !store.uiState.isPatchReview {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: Binding(
            get: { store.uiState.isSheetPresented && !store.uiState.isPatchReview },
            set: { isPresented in
                if !isPresented { store.send(.closeChat) }
            }
        )) {
            ChatSheetView(store: store)
                .interactiveDismissDisabled(store.uiState.isPatchProposed)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(keyProvider: store.keyProvider)
        }
    }
}

#Preview {
    ContentView()
}

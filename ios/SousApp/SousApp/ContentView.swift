import SwiftUI
import SousCore

struct ContentView: View {
    @StateObject private var store = AppStore()

    var body: some View {
        ZStack {
            if case .patchReview(let recipe, let patchSet, let validation, _) = store.uiState {
                PatchReviewView(recipe: recipe, patchSet: patchSet, validation: validation, store: store)
            } else {
                RecipeCanvasView(recipe: store.uiState.recipe, onOpenChat: { store.send(.openChat) })
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
    }
}

#Preview {
    ContentView()
}

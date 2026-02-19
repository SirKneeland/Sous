import SwiftUI
import SousCore

struct ContentView: View {
    @StateObject private var store = AppStore()

    var body: some View {
        ZStack {
            RecipeCanvasView(recipe: store.uiState.recipe, onOpenChat: { store.send(.openChat) })

            if store.uiState.isSheetPresented {
                Color.black.opacity(0.4).ignoresSafeArea()
            }
        }
        .sheet(isPresented: Binding(
            get: { store.uiState.isSheetPresented },
            set: { isPresented in
                if !isPresented { store.send(.closeChat) }
            }
        )) {
            sheetContent
                .interactiveDismissDisabled(store.uiState.isPatchProposed || store.uiState.isPatchReview)
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        switch store.uiState {
        case .patchReview(_, let patchSet, let validation, _):
            PatchReviewView(patchSet: patchSet, validation: validation, store: store)
        default:
            ChatSheetView(store: store)
        }
    }
}

#Preview {
    ContentView()
}

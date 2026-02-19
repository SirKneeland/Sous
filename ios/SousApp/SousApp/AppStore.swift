import Combine
import Foundation
import SousCore

// MARK: - UIState projection helpers

extension UIState {
    var recipe: Recipe {
        switch self {
        case .recipeOnly(let r):             return r
        case .chatOpen(let r, _, _):         return r
        case .patchProposed(let r, _, _, _): return r
        case .patchReview(let r, _, _, _):   return r
        }
    }

    var isSheetPresented: Bool {
        if case .recipeOnly = self { return false }
        return true
    }

    var isPatchProposed: Bool {
        if case .patchProposed = self { return true }
        return false
    }

    var isPatchReview: Bool {
        if case .patchReview = self { return true }
        return false
    }
}

// MARK: - AppStore

@MainActor
final class AppStore: ObservableObject {
    @Published var uiState: UIState
    @Published var chatTranscript: [ChatMessage] = []

    private let maxMessages = 200

    private static let recipeId          = UUID(uuidString: "00000000-0000-0000-FFFF-000000000001")!
    private static let ingredientFlourId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let ingredientSaltId  = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let ingredientWaterId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private static let stepMixId         = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    private static let stepBakeId        = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!
    private static let stepDoneId        = UUID(uuidString: "00000000-0000-0000-0001-000000000003")!

    init() {
        let recipe = Recipe(
            id: Self.recipeId,
            version: 1,
            title: "Simple Bread",
            ingredients: [
                Ingredient(id: Self.ingredientFlourId, text: "2 cups flour"),
                Ingredient(id: Self.ingredientSaltId,  text: "1 tsp salt"),
                Ingredient(id: Self.ingredientWaterId, text: "3/4 cup water"),
            ],
            steps: [
                Step(id: Self.stepMixId,  text: "Mix dry ingredients",       status: .todo),
                Step(id: Self.stepBakeId, text: "Bake at 375°F for 30 min",  status: .todo),
                Step(id: Self.stepDoneId, text: "Let cool on rack",           status: .done),
            ],
            notes: ["Original family recipe"]
        )
        uiState = .recipeOnly(recipe: recipe)

        chatTranscript = [
            ChatMessage(role: .system,    text: "Sous is ready. Tap the mic or type to get started."),
            ChatMessage(role: .assistant, text: "Hi! I'm looking at your Simple Bread recipe. What would you like to change?"),
            ChatMessage(role: .assistant, text: "Tip: use the Debug panel to simulate a patch if you want to test the review flow."),
        ]
    }

    // MARK: - Chat

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        append(ChatMessage(role: .user, text: trimmed))
        append(ChatMessage(role: .assistant, text: "Got it. I can propose edits — use Debug to simulate a patch for now."))
    }

    private func append(_ message: ChatMessage) {
        chatTranscript.append(message)
        if chatTranscript.count > maxMessages {
            chatTranscript.removeFirst(chatTranscript.count - maxMessages)
        }
    }

    func send(_ event: UIEvent) {
        uiState = UIStateMachine.reduce(uiState, event)
    }

    // MARK: - Debug simulation

    func simulateValidPatch() {
        let recipe = uiState.recipe
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [.addNote(text: "Add a pinch of yeast for better rise")]
        )
        send(.patchReceived(patchSet))
    }

    func simulateInvalidPatch() {
        let recipe = uiState.recipe
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [.updateIngredient(id: UUID(), text: "ghost ingredient")]
        )
        send(.patchReceived(patchSet))
    }
}

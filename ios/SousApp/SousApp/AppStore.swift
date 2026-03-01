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
    @Published var llmDebugStatus: String? = nil

    var useLiveLLM = true

    private let maxMessages = 200
    private let liveLLMModel = "gpt-4o-mini"
    private let proposer: any PatchProposer = MockPatchProposer()
    private var nextLLMContext: NextLLMContext? = nil

    private var hasPendingPatch: Bool {
        switch uiState {
        case .patchProposed, .patchReview: return true
        default: return false
        }
    }

    private func resolvedAPIKey() -> String? {
        let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        return (key?.isEmpty == false) ? key : nil
    }

    static let recipeId          = UUID(uuidString: "00000000-0000-0000-FFFF-000000000001")!
    static let ingredientFlourId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let ingredientSaltId  = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let ingredientWaterId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let stepMixId         = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let stepBakeId        = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!
    static let stepDoneId        = UUID(uuidString: "00000000-0000-0000-0001-000000000003")!

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
        guard !hasPendingPatch else { return }
        append(ChatMessage(role: .user, text: trimmed))
        if useLiveLLM {
            Task { await sendWithLLM(trimmed) }
        } else {
            let patchSet = proposer.propose(userText: trimmed, recipe: uiState.recipe)
            send(.patchReceived(patchSet))
            append(ChatMessage(role: .assistant, text: "Proposed changes are ready — review them on the recipe."))
        }
    }

    private func sendWithLLM(_ userText: String) async {
        llmDebugStatus = "calling"
        let recipe = uiState.recipe
        let hidden: HiddenContext
        if case .chatOpen(_, _, let h) = uiState { hidden = h } else { hidden = HiddenContext() }

        let request = LLMRequest(
            recipeId: recipe.id.uuidString,
            recipeVersion: recipe.version,
            hasCanvas: true,
            userMessage: LLMContextComposer.composeUserMessage(userText: userText, hidden: hidden),
            recipeSnapshotForPrompt: recipe,
            // TODO: wire real user prefs (Prompt 8)
            userPrefs: LLMUserPrefs(hardAvoids: ["cilantro"]),
            nextLLMContext: nextLLMContext
        )

        let orchestrator = OpenAILLMOrchestrator(
            client: OpenAIClient(apiKey: resolvedAPIKey()),
            model: liveLLMModel
        )
        let result = await orchestrator.run(request)

        switch result {
        case .valid(let patchSet, let assistantMessage, _, _):
            nextLLMContext = nil
            send(.patchReceived(patchSet))
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"

        case .noPatches(let assistantMessage, _, _):
            nextLLMContext = nil
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"

        case .failure(let fallbackPatchSet, let assistantMessage, _, _, _):
            if let fallback = fallbackPatchSet {
                send(.patchReceived(fallback))
            }
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "failed"
        }
    }

    private func append(_ message: ChatMessage) {
        chatTranscript.append(message)
        if chatTranscript.count > maxMessages {
            chatTranscript.removeFirst(chatTranscript.count - maxMessages)
        }
    }

    func send(_ event: UIEvent) {
        let prev = uiState
        uiState = UIStateMachine.reduce(uiState, event)
        // Record patch decision only after the transition succeeds.
        switch event {
        case .acceptPatch:
            if case .patchReview(_, let ps, _, _) = prev, case .recipeOnly = uiState {
                nextLLMContext = NextLLMContext(lastPatchDecision: PatchDecision(
                    patchSetId: ps.patchSetId.uuidString,
                    decision: .accepted,
                    decidedAtMs: Int(Date().timeIntervalSinceReferenceDate * 1000)
                ))
            }
        case .rejectPatch:
            if case .patchReview(_, let ps, _, _) = prev, case .chatOpen = uiState {
                nextLLMContext = NextLLMContext(lastPatchDecision: PatchDecision(
                    patchSetId: ps.patchSetId.uuidString,
                    decision: .rejected,
                    decidedAtMs: Int(Date().timeIntervalSinceReferenceDate * 1000)
                ))
            }
        default:
            break
        }
    }

    // MARK: - Debug simulation

    func simulateValidPatch() {
        let recipe = uiState.recipe
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [
                .addIngredient(text: "1 tsp yeast", afterId: Self.ingredientFlourId),
                .updateIngredient(id: Self.ingredientSaltId, text: "2 tsp salt"),
                .removeIngredient(id: Self.ingredientWaterId),

                .addStep(text: "Knead dough for 5 minutes", afterStepId: Self.stepMixId),
                .updateStep(id: Self.stepBakeId, text: "Bake at 350°F for 30 min"),

                .addNote(text: "From UI"),
            ]
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

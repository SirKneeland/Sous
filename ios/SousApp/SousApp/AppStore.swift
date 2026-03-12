import Combine
import Foundation
import SousCore

// MARK: - UIState projection helpers (app-layer only)

extension UIState {
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
    /// True while any LLM call (text or multimodal) is in flight. Drives the thinking indicator.
    @Published var isThinking: Bool = false
    /// The debug bundle from the most recent LLM run. Updated on every result path.
    @Published var lastDebugBundle: LLMDebugBundle? = nil
    /// True when a recipe canvas exists (user has at least one recipe). False in blank/exploration state.
    @Published var hasCanvas: Bool

    /// Toggle via setUseLiveLLM(_:) so cancellation side-effects are applied correctly.
    private(set) var useLiveLLM = true

    /// False when a test orchestrator is injected; skips all disk I/O so tests
    /// are isolated from the real session file and from each other.
    private let isPersistenceEnabled: Bool

    /// Override in tests to avoid touching the real Documents directory.
    /// Nil means use SessionPersistence.defaultFileURL.
    private let sessionFileURL: URL?

    private let maxMessages = 200
    private let liveLLMModel = "gpt-4o-mini"
    private let multimodalLLMModel = "gpt-4o"
    private let proposer: any PatchProposer = MockPatchProposer()
    private var nextLLMContext: NextLLMContext? = nil

    // MARK: - In-flight tracking

    /// Injected at init for testing; nil means use the live OpenAI orchestrator.
    private let testOrchestrator: (any LLMOrchestrator)?
    /// The active LLM Task. Non-nil while a call is in flight.
    private var llmTask: Task<Void, Never>?
    /// Monotonically incremented per send. Used by the deferred cleanup to avoid
    /// clearing a newer task's reference when an old (cancelled) task finishes.
    private var llmGeneration = 0

    private var hasPendingPatch: Bool {
        switch uiState {
        case .patchProposed, .patchReview: return true
        default: return false
        }
    }

    let keyProvider: any OpenAIKeyProviding

    private func resolvedAPIKey() -> String? {
        if let key = keyProvider.currentKey() { return key }
#if DEBUG
        let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        if envKey?.isEmpty == false { return envKey }
#endif
        return nil
    }

    static let recipeId          = UUID(uuidString: "00000000-0000-0000-FFFF-000000000001")!
    static let ingredientFlourId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let ingredientSaltId  = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let ingredientWaterId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let stepMixId         = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let stepBakeId        = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!
    static let stepDoneId        = UUID(uuidString: "00000000-0000-0000-0001-000000000003")!

    init(testOrchestrator: (any LLMOrchestrator)? = nil,
         sessionFileURL: URL? = nil,
         keyProvider: any OpenAIKeyProviding = KeychainOpenAIKeyProvider()) {
        self.testOrchestrator = testOrchestrator
        self.keyProvider = keyProvider
        self.sessionFileURL = sessionFileURL
        isPersistenceEnabled = (testOrchestrator == nil)

        if testOrchestrator == nil,
           let snapshot = SessionPersistence.load(from: sessionFileURL),
           snapshot.schemaVersion == SessionSnapshot.currentSchemaVersion {
            // Restore saved session
            hasCanvas = snapshot.hasCanvas
            chatTranscript = snapshot.chatMessages
            nextLLMContext = snapshot.nextLLMContext
            if snapshot.hasCanvas {
                if let patch = snapshot.pendingPatchSet {
                    uiState = .patchProposed(
                        recipe: snapshot.recipe,
                        patchSet: patch,
                        validation: nil,
                        hidden: HiddenContext()
                    )
                } else {
                    uiState = .recipeOnly(recipe: snapshot.recipe)
                }
            } else {
                // Restore blank/exploration state — preserve transcript for ongoing exploration
                uiState = .chatOpen(recipe: snapshot.recipe, draftUserText: "", hidden: HiddenContext())
            }
        } else if testOrchestrator != nil {
            // Test mode: predictable seed data so existing tests remain stable
            hasCanvas = true
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
        } else {
            // First launch (no valid session): blank/exploration state
            hasCanvas = false
            uiState = .chatOpen(
                recipe: Recipe(id: UUID(), version: 1, title: "New Recipe"),
                draftUserText: "",
                hidden: HiddenContext()
            )
            chatTranscript = []
        }
    }

    deinit {
        llmTask?.cancel()
    }

    // MARK: - New Session

    /// Clears the current session and returns to the blank starting state.
    /// Called when the user taps "New Recipe".
    func startNewSession() {
        cancelLiveLLM()
        hasCanvas = false
        uiState = .chatOpen(
            recipe: Recipe(id: UUID(), version: 1, title: "New Recipe"),
            draftUserText: "",
            hidden: HiddenContext()
        )
        chatTranscript = []
        nextLLMContext = nil
        if isPersistenceEnabled {
            SessionPersistence.clear(at: sessionFileURL)
        }
    }

    // MARK: - Live LLM toggle

    /// Canonical way to toggle useLiveLLM. Cancels any in-flight request when turning off.
    func setUseLiveLLM(_ enabled: Bool) {
        if useLiveLLM && !enabled { cancelLiveLLM() }
        useLiveLLM = enabled
    }

    /// Cancels the in-flight LLM Task (if any) and clears the task reference immediately.
    /// The Task body checks Task.isCancelled after the orchestrator returns and discards
    /// the result without mutating state.
    func cancelLiveLLM() {
        llmTask?.cancel()
        llmTask = nil
    }

    // MARK: - Chat

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !hasPendingPatch else { return }
        // Single-flight: block (not cancel) if a live LLM call is already in flight.
        // User bubble is intentionally NOT appended when blocked.
        if useLiveLLM && llmTask != nil {
            llmDebugStatus = "blocked_inflight_llm"
            return
        }
        append(ChatMessage(role: .user, text: trimmed))
        if useLiveLLM {
            llmGeneration += 1
            let gen = llmGeneration
            llmTask = Task { await self.sendWithLLM(trimmed, generation: gen) }
        } else {
            let patchSet = proposer.propose(userText: trimmed, recipe: uiState.recipe)
            send(.patchReceived(patchSet))
            append(ChatMessage(role: .assistant, text: "Proposed changes are ready — review them on the recipe."))
        }
    }

    private func sendWithLLM(_ userText: String, generation: Int) async {
        // Clear llmTask when this generation's call ends (natural or cancelled).
        // The generation guard prevents an old cancelled task from clearing a newer task's ref.
        defer {
            if llmGeneration == generation {
                llmTask = nil
                isThinking = false
            }
        }
        isThinking = true
        llmDebugStatus = "calling"
        let recipe = uiState.recipe
        let hidden: HiddenContext
        if case .chatOpen(_, _, let h) = uiState { hidden = h } else { hidden = HiddenContext() }

        let request = LLMRequest(
            recipeId: recipe.id.uuidString,
            recipeVersion: recipe.version,
            hasCanvas: hasCanvas,
            userMessage: LLMContextComposer.composeUserMessage(userText: userText, hidden: hidden),
            recipeSnapshotForPrompt: recipe,
            // TODO: wire real user prefs (Prompt 8)
            userPrefs: LLMUserPrefs(hardAvoids: ["cilantro"]),
            nextLLMContext: nextLLMContext,
            conversationHistory: buildConversationHistory()
        )

        let orchestrator: any LLMOrchestrator = testOrchestrator ?? OpenAILLMOrchestrator(
            client: OpenAIClient(apiKey: resolvedAPIKey()),
            model: liveLLMModel
        )
        let result = await orchestrator.run(request)

        // Cancellation guard: if the task was cancelled while awaiting, discard the result.
        // nextLLMContext is intentionally NOT cleared so it applies to the next successful call.
        guard !Task.isCancelled else {
            llmDebugStatus = "cancelled"
            return
        }

        switch result {
        case .valid(let patchSet, let assistantMessage, _, let debug):
            lastDebugBundle = debug
            // Receipt-time stale-state check against CURRENT recipe (not the request snapshot).
            // Guards races where the recipe was mutated while the LLM call was in flight.
            let current = uiState.recipe
            if patchSet.baseRecipeId != current.id {
                append(ChatMessage(role: .assistant, text: assistantMessage))
                llmDebugStatus = "fatal_recipeIdMismatch"
                return
            }
            if patchSet.baseRecipeVersion != current.version {
                append(ChatMessage(role: .assistant, text: assistantMessage))
                llmDebugStatus = "expired_recipeVersionMismatch"
                return
            }
            nextLLMContext = nil
            send(.patchReceived(patchSet))
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"

        case .noPatches(let assistantMessage, _, let debug):
            lastDebugBundle = debug
            nextLLMContext = nil
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"

        case .failure(let fallbackPatchSet, let assistantMessage, _, let debug, _):
            lastDebugBundle = debug
            if let fallback = fallbackPatchSet {
                send(.patchReceived(fallback))
            }
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "failed"
        }
    }

    // MARK: - Photo send support

    /// Whether a patch is currently pending review. Exposed for photo send guard checks.
    var hasActivePatch: Bool { hasPendingPatch }

    /// Whether a live LLM call (text or multimodal) is currently in flight.
    var isLLMCallInFlight: Bool { useLiveLLM && llmTask != nil }

    /// Appends a user chat message after successful photo preparation.
    /// Called by the view only after `PhotoSendCoordinator.send(text:recipe:)` returns non-nil.
    func appendPhotoMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        append(ChatMessage(role: .user, text: trimmed.isEmpty ? "[Photo]" : trimmed))
    }

    /// Dispatches a multimodal LLM call using the prepared image.
    ///
    /// Single-flight enforced identically to text sends: blocked if a call is already
    /// in-flight or a patch is pending.  The `base` LLMRequest from the coordinator is
    /// rebuilt here so that `nextLLMContext`, `userPrefs`, and a fresh recipe snapshot
    /// are always injected from AppStore's canonical state.
    func sendMultimodalRequest(_ multimodalReq: MultimodalLLMRequest) {
        guard !hasPendingPatch else { return }
        guard useLiveLLM else { return }
        if llmTask != nil {
            llmDebugStatus = "blocked_inflight_llm"
            return
        }
        llmGeneration += 1
        let gen = llmGeneration
        llmTask = Task { await self.sendWithMultimodalLLM(multimodalReq, generation: gen) }
    }

    private func sendWithMultimodalLLM(_ multimodalReq: MultimodalLLMRequest, generation: Int) async {
        defer {
            if llmGeneration == generation {
                llmTask = nil
                isThinking = false
            }
        }
        isThinking = true
        llmDebugStatus = "calling"
        let recipe = uiState.recipe
        let hidden: HiddenContext
        if case .chatOpen(_, _, let h) = uiState { hidden = h } else { hidden = HiddenContext() }

        // Rebuild the base LLMRequest with proper session context from AppStore state.
        // The coordinator's base.userMessage carries the user's text; everything else is
        // sourced fresh so stale snapshots from the coordinator don't reach the orchestrator.
        let base = LLMRequest(
            recipeId: recipe.id.uuidString,
            recipeVersion: recipe.version,
            hasCanvas: hasCanvas,
            userMessage: LLMContextComposer.composeUserMessage(
                userText: multimodalReq.base.userMessage,
                hidden: hidden
            ),
            recipeSnapshotForPrompt: recipe,
            userPrefs: LLMUserPrefs(hardAvoids: ["cilantro"]),
            nextLLMContext: nextLLMContext,
            conversationHistory: buildConversationHistory()
        )
        let request = MultimodalLLMRequest(base: base, image: multimodalReq.image)

        let orchestrator: any LLMOrchestrator = testOrchestrator ?? OpenAILLMOrchestrator(
            client: OpenAIClient(apiKey: resolvedAPIKey()),
            model: multimodalLLMModel
        )
        let result = await orchestrator.run(request)

        guard !Task.isCancelled else {
            llmDebugStatus = "cancelled"
            return
        }

        switch result {
        case .valid(let patchSet, let assistantMessage, _, let debug):
            lastDebugBundle = debug
            let current = uiState.recipe
            if patchSet.baseRecipeId != current.id {
                append(ChatMessage(role: .assistant, text: assistantMessage))
                llmDebugStatus = "fatal_recipeIdMismatch"
                return
            }
            if patchSet.baseRecipeVersion != current.version {
                append(ChatMessage(role: .assistant, text: assistantMessage))
                llmDebugStatus = "expired_recipeVersionMismatch"
                return
            }
            nextLLMContext = nil
            send(.patchReceived(patchSet))
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"

        case .noPatches(let assistantMessage, _, let debug):
            lastDebugBundle = debug
            nextLLMContext = nil
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"

        case .failure(let fallbackPatchSet, let assistantMessage, _, let debug, _):
            lastDebugBundle = debug
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
        // Persist after every user or assistant message so the transcript
        // survives a crash between the user sending and the AI replying.
        if message.role == .user || message.role == .assistant {
            saveSession()
        }
    }

    /// Builds the prior-turn history to include in the next LLM request.
    ///
    /// Drops the last transcript entry (the current user message, which was just appended
    /// before the async send), filters out system messages, and caps at 20 entries
    /// (10 full turns) to control token cost on long sessions.
    private func buildConversationHistory() -> [LLMMessage] {
        chatTranscript
            .dropLast()
            .filter { $0.role == .user || $0.role == .assistant }
            .suffix(20)
            .map { msg in
                let role: LLMMessage.Role = msg.role == .user ? .user : .assistant
                return LLMMessage(role: role, content: msg.text)
            }
    }

    func send(_ event: UIEvent) {
        let prev = uiState
        uiState = UIStateMachine.reduce(uiState, event)
        // When the first recipe is accepted from blank state, reveal the canvas.
        if case .acceptPatch = event, !hasCanvas, case .recipeOnly = uiState {
            hasCanvas = true
        }
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
        // Persist after events that change recipe state, pending patch, or nextLLMContext.
        switch event {
        case .patchReceived, .acceptPatch, .rejectPatch, .markStepDone:
            saveSession()
        default:
            break
        }
    }

    // MARK: - Session persistence

    /// Saves a snapshot of the current session state to disk.
    ///
    /// Called synchronously on the main actor.  The JSON payload is small
    /// (recipe + ≤20 messages + optional patch) so the write is negligible.
    /// `Data.write(options: .atomic)` handles crash-safety via temp-file + rename.
    private func saveSession() {
        guard isPersistenceEnabled else { return }
        try? SessionPersistence.save(makeSnapshot(), to: sessionFileURL)
    }

    private func makeSnapshot() -> SessionSnapshot {
        let pendingPatch: PatchSet? = {
            switch uiState {
            case .patchProposed(_, let ps, _, _),
                 .patchReview(_, let ps, _, _):
                return ps
            default:
                return nil
            }
        }()
        // Persist the last 20 user/assistant messages — same cap as
        // buildConversationHistory() so the LLM always has the full context.
        let messages = Array(
            chatTranscript
                .filter { $0.role == .user || $0.role == .assistant }
                .suffix(20)
        )
        return SessionSnapshot(
            schemaVersion: SessionSnapshot.currentSchemaVersion,
            hasCanvas: hasCanvas,
            recipe: uiState.recipe,
            pendingPatchSet: pendingPatch,
            chatMessages: messages,
            nextLLMContext: nextLLMContext,
            savedAt: Date()
        )
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

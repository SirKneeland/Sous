import Combine
import Foundation
import SousCore
import UIKit

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
    /// Partial assistant message text being streamed in real time. Non-nil while streaming
    /// is in progress and content has been received. Cleared when the result is processed.
    @Published var streamingAssistantMessage: String? = nil
    /// The debug bundle from the most recent LLM run. Updated on every result path.
    @Published var lastDebugBundle: LLMDebugBundle? = nil
    /// True when a recipe canvas exists (user has at least one recipe). False in blank/exploration state.
    @Published var hasCanvas: Bool

    /// Toggle via setUseLiveLLM(_:) so cancellation side-effects are applied correctly.
    private(set) var useLiveLLM = true

    /// False when a test orchestrator is injected; skips all disk I/O so tests
    /// are isolated from the real session file and from each other.
    private let isPersistenceEnabled: Bool

    /// Override in tests to point AppStore at a temp directory.
    /// Nil means use SessionPersistence.sessionsDirectory (Documents).
    private let sessionsDirectory: URL?

    /// Override in tests to isolate UserDefaults reads/writes.
    /// Nil means use UserDefaults.standard.
    private let preferencesDefaults: UserDefaults?

    @Published var showRecentRecipes: Bool = false
    @Published var userPreferences: UserPreferences = UserPreferences()
    /// User-declared memories included as context in every LLM request.
    @Published var memories: [MemoryItem] = []
    /// A memory text the LLM has proposed to save. Non-nil while the toast is showing.
    @Published var pendingMemoryProposal: String? = nil

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
         sessionsDirectory: URL? = nil,
         preferencesDefaults: UserDefaults? = nil,
         keyProvider: any OpenAIKeyProviding = KeychainOpenAIKeyProvider()) {
        self.testOrchestrator = testOrchestrator
        self.keyProvider = keyProvider
        self.sessionsDirectory = sessionsDirectory
        self.preferencesDefaults = preferencesDefaults
        isPersistenceEnabled = (testOrchestrator == nil)

        if isPersistenceEnabled {
            userPreferences = UserPreferencesPersistence.load(from: preferencesDefaults ?? .standard)
            memories = MemoriesPersistence.load(from: preferencesDefaults ?? .standard)
        }

        if testOrchestrator == nil {
            // Try loading the most recent per-recipe session.
            var snapshot = SessionPersistence.listAll(in: sessionsDirectory).first

            // Migration from M10/M11: if no per-recipe sessions exist, check the legacy file.
            if snapshot == nil {
                let legacyURL = (sessionsDirectory ?? SessionPersistence.sessionsDirectory)
                    .appendingPathComponent("sous_session.json")
                if let legacy = SessionPersistence.load(from: legacyURL),
                   legacy.schemaVersion == SessionSnapshot.currentSchemaVersion {
                    let newURL = SessionPersistence.fileURL(for: legacy.recipe.id, in: sessionsDirectory)
                    try? SessionPersistence.save(legacy, to: newURL)
                    SessionPersistence.clear(at: legacyURL)
                    snapshot = legacy
                }
            }

            if let snapshot {
                // Restore saved session
                hasCanvas = snapshot.hasCanvas
                chatTranscript = snapshot.chatMessages
                nextLLMContext = snapshot.nextLLMContext
                if snapshot.hasCanvas {
                    if let patch = snapshot.pendingPatchSet {
                        // Auto-advance past patchProposed: restore directly into patchReview.
                        let proposed = UIState.patchProposed(
                            recipe: snapshot.recipe,
                            patchSet: patch,
                            validation: nil,
                            hidden: HiddenContext()
                        )
                        uiState = UIStateMachine.reduce(proposed, .validatePatch)
                    } else {
                        uiState = .recipeOnly(recipe: snapshot.recipe)
                    }
                } else {
                    // Restore blank/exploration state — preserve transcript for ongoing exploration
                    uiState = .chatOpen(recipe: snapshot.recipe, draftUserText: "", hidden: HiddenContext())
                }
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
        } else {
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
        }
    }

    deinit {
        llmTask?.cancel()
    }

    // MARK: - Preferences

    /// Updates in-memory preferences and persists them to UserDefaults.
    func updatePreferences(_ prefs: UserPreferences) {
        userPreferences = prefs
        guard isPersistenceEnabled else { return }
        UserPreferencesPersistence.save(prefs, to: preferencesDefaults ?? .standard)
    }

    // MARK: - Memories

    /// Adds a new memory and persists it.
    func addMemory(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        memories.append(MemoryItem(text: trimmed))
        saveMemories()
    }

    /// Replaces an existing memory (matched by id) and persists.
    func updateMemory(_ item: MemoryItem) {
        guard let idx = memories.firstIndex(where: { $0.id == item.id }) else { return }
        memories[idx] = item
        saveMemories()
    }

    /// Removes a memory and persists.
    func deleteMemory(_ item: MemoryItem) {
        memories.removeAll { $0.id == item.id }
        saveMemories()
    }

    /// Sets the pending memory proposal shown in the toast. Replaces any existing proposal.
    func proposeMemory(text: String) {
        pendingMemoryProposal = text
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Saves the proposed memory (with optional edits) and clears the toast.
    func confirmMemory(text: String) {
        addMemory(text)
        pendingMemoryProposal = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Discards the pending memory proposal without saving.
    func dismissMemoryProposal() {
        pendingMemoryProposal = nil
    }

    private func saveMemories() {
        guard isPersistenceEnabled else { return }
        MemoriesPersistence.save(memories, to: preferencesDefaults ?? .standard)
    }

    // MARK: - New Session

    /// Clears the current session and returns to the blank starting state.
    /// The previous recipe stays on disk so it appears in Recent Recipes.
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
    }

    /// Starts a new session immediately (previous session stays on disk in Recent Recipes).
    func requestNewSession() {
        startNewSession()
    }

    // MARK: - Recent Recipes

    /// Returns all saved recipe sessions, most recent first (current recipe is always first slot).
    func loadRecentSessions() -> [SessionSnapshot] {
        guard isPersistenceEnabled else { return [] }
        return Array(SessionPersistence.listAll(in: sessionsDirectory).prefix(20))
    }

    /// Deletes the on-disk session for `snapshot`.
    func deleteRecentSession(_ snapshot: SessionSnapshot) {
        guard isPersistenceEnabled else { return }
        SessionPersistence.delete(recipeId: snapshot.recipe.id, in: sessionsDirectory)
    }

    /// Resumes a previous session immediately (switch is non-destructive — current session stays on disk).
    func requestResumeSession(_ snapshot: SessionSnapshot) {
        resumeSession(snapshot)
    }

    /// Loads `snapshot` into the store as the active session.
    func resumeSession(_ snapshot: SessionSnapshot) {
        cancelLiveLLM()
        hasCanvas = snapshot.hasCanvas
        chatTranscript = snapshot.chatMessages
        nextLLMContext = snapshot.nextLLMContext
        if snapshot.hasCanvas {
            if let patch = snapshot.pendingPatchSet {
                // Auto-advance past patchProposed: restore directly into patchReview.
                let proposed = UIState.patchProposed(
                    recipe: snapshot.recipe,
                    patchSet: patch,
                    validation: nil,
                    hidden: HiddenContext()
                )
                uiState = UIStateMachine.reduce(proposed, .validatePatch)
            } else {
                uiState = .recipeOnly(recipe: snapshot.recipe)
            }
        } else {
            uiState = .chatOpen(recipe: snapshot.recipe, draftUserText: "", hidden: HiddenContext())
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

    private func buildLLMUserPrefs() -> LLMUserPrefs {
        LLMUserPrefs(
            hardAvoids: userPreferences.hardAvoids,
            servingSize: userPreferences.servingSize,
            equipment: userPreferences.equipment,
            customInstructions: userPreferences.customInstructions,
            memories: memories.map { $0.text },
            personalityMode: userPreferences.personalityMode
        )
    }

    private func sendWithLLM(_ userText: String, generation: Int) async {
        // Clear llmTask when this generation's call ends (natural or cancelled).
        // The generation guard prevents an old cancelled task from clearing a newer task's ref.
        defer {
            if llmGeneration == generation {
                llmTask = nil
                isThinking = false
                streamingAssistantMessage = nil
            }
        }
        isThinking = true
        streamingAssistantMessage = nil
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
            userPrefs: buildLLMUserPrefs(),
            nextLLMContext: nextLLMContext,
            conversationHistory: buildConversationHistory()
        )

        let llmClient = OpenAIClient(apiKey: resolvedAPIKey())
        let orchestrator: any LLMOrchestrator = testOrchestrator ?? OpenAILLMOrchestrator(
            client: llmClient,
            streamingClient: llmClient,   // explicit injection avoids runtime existential cast
            model: liveLLMModel
        )

        // Each streaming token is dispatched directly to the main actor via a fire-and-forget
        // Task. These tasks are enqueued on the main actor queue *before* orchestrator.run
        // returns, so they execute before sendWithLLM's continuation resumes — no extra
        // synchronisation needed.
        let result = await orchestrator.run(request, onStreamToken: { [weak self] token in
            guard let self else { return }
            Task { @MainActor [self] in
                self.streamingAssistantMessage = (self.streamingAssistantMessage ?? "") + token
            }
        })

        // Cancellation guard: if the task was cancelled while awaiting, discard the result.
        // nextLLMContext is intentionally NOT cleared so it applies to the next successful call.
        guard !Task.isCancelled else {
            llmDebugStatus = "cancelled"
            return
        }

        switch result {
        case .valid(let patchSet, let assistantMessage, _, let debug, let proposedMemory):
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
            if let memory = proposedMemory { proposeMemory(text: memory) }

        case .noPatches(let assistantMessage, _, let debug, let proposedMemory):
            lastDebugBundle = debug
            nextLLMContext = nil
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"
            if let memory = proposedMemory { proposeMemory(text: memory) }

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
            userPrefs: buildLLMUserPrefs(),
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
        case .valid(let patchSet, let assistantMessage, _, let debug, let proposedMemory):
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
            if let memory = proposedMemory { proposeMemory(text: memory) }

        case .noPatches(let assistantMessage, _, let debug, let proposedMemory):
            lastDebugBundle = debug
            nextLLMContext = nil
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"
            if let memory = proposedMemory { proposeMemory(text: memory) }

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

        // Auto-advance: skip the patchProposed intermediate state.
        // Any transition that lands in patchProposed immediately runs validation
        // and enters patchReview — no separate user action required.
        if case .patchProposed = uiState {
            uiState = UIStateMachine.reduce(uiState, .validatePatch)
        }

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
        let url = SessionPersistence.fileURL(for: uiState.recipe.id, in: sessionsDirectory)
        try? SessionPersistence.save(makeSnapshot(), to: url)
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

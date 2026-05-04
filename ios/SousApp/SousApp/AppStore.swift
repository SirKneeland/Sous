import Combine
import Foundation
import SousCore
import UIKit

// MARK: - QuotedRowContext

/// Carries the recipe row the user tapped "Ask Sous" on. Cleared after the message is sent.
struct QuotedRowContext: Equatable {
    enum RowType: Equatable { case ingredient, step }
    let type: RowType
    let text: String
}

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

/// Tracks the active stage of the import pipeline. Used by the loading UI to show stage-aware copy.
enum ImportLoadingStage { case ocr, llm }

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
#if DEBUG
    /// The LLMRequest most recently dispatched to the orchestrator. Used by the
    /// 5-tap diagnostic exporter to reconstruct the exact system prompt snapshot.
    var lastDebugLLMRequest: LLMRequest? = nil
#endif
    /// True when a recipe canvas exists (user has at least one recipe). False in blank/exploration state.
    @Published var hasCanvas: Bool
    /// True when the LLM has signalled readiness to generate a recipe (exploration phase only).
    /// Drives the "Make this recipe" pill in the chat input bar.
    @Published var canGenerateRecipe: Bool = false

    /// Toggle via setUseLiveLLM(_:) so cancellation side-effects are applied correctly.
    private(set) var useLiveLLM = true

    /// False when a test orchestrator is injected; skips all disk I/O so tests
    /// are isolated from the real session file and from each other.
    private let isPersistenceEnabled: Bool

    /// True once the current session has earned a history entry — either the user has sent a
    /// message or a recipe canvas has been created.  False for freshly-created blank sessions
    /// so that tapping "New Recipe" and immediately leaving doesn't litter the history store.
    private var isSessionPersistable: Bool = false

    /// Override in tests to point AppStore at a temp directory.
    /// Nil means use SessionPersistence.sessionsDirectory (Documents).
    private let sessionsDirectory: URL?

    /// Override in tests to isolate photo file I/O.
    /// Nil means use PhotoPersistence.defaultBaseDirectory (Documents/photos).
    private let photosBaseDirectory: URL?

    /// Override in tests to isolate UserDefaults reads/writes.
    /// Nil means use UserDefaults.standard.
    private let preferencesDefaults: UserDefaults?

    @Published var showRecentRecipes: Bool = false
    /// True while the import sheet is presented. Set to false by AppStore on successful import or by the sheet on cancel.
    @Published var isShowingImportSheet: Bool = false
    /// Non-nil when an import attempt failed. Observed by RecipeImportSheet to switch into error state.
    @Published var importError: String? = nil
    /// True while the mise en place LLM call is in flight. Drives the trigger loading state.
    @Published var miseEnPlaceIsLoading: Bool = false
    /// Non-nil when mise en place fails or finds nothing. Shown inline near the trigger.
    @Published var miseEnPlaceError: String? = nil
    /// Fires once when import succeeds, so the loading view can animate to 100% before the sheet dismisses.
    @Published var importSuccess: Bool = false
    /// Tracks the active stage of the import pipeline for stage-aware loading UI.
    @Published var importLoadingStage: ImportLoadingStage = .llm
    @Published var userPreferences: UserPreferences = UserPreferences()
    /// User-declared memories included as context in every LLM request.
    @Published var memories: [MemoryItem] = []
    /// A memory text the LLM has proposed to save. Non-nil while the toast is showing.
    @Published var pendingMemoryProposal: String? = nil
    /// True when a non-empty API key is stored in the Keychain. Drives the first-launch onboarding callout.
    @Published var hasAPIKey: Bool
    /// The recipe row the user asked Sous about via the swipe action. Shown as a quote chip
    /// in the chat composer; consumed and cleared when the user sends a message.
    @Published var quotedRowContext: QuotedRowContext? = nil
    /// Whether the Ingredients section is expanded on the recipe canvas.
    /// Persisted in SessionSnapshot so it survives relaunch and recipe switches.
    @Published var ingredientsExpanded: Bool = true
    /// Whether completed steps are shown on the recipe canvas.
    /// When false, done steps are hidden while TODO steps remain visible.
    /// Persisted in SessionSnapshot so it survives relaunch and recipe switches.
    @Published var stepsCompletedExpanded: Bool = false
    /// Whether the mise en place section is expanded on the recipe canvas.
    /// Persisted in SessionSnapshot so it survives relaunch and recipe switches.
    @Published var miseEnPlaceExpanded: Bool = false

    private let maxMessages = 200
    private let liveLLMModel = "gpt-5.4-mini"
    private let multimodalLLMModel = "gpt-5.4-mini"
    private let proposer: any PatchProposer = MockPatchProposer()
    private var nextLLMContext: NextLLMContext? = nil

    // MARK: - In-flight tracking

    /// Injected at init for testing; nil means use the live OpenAI orchestrator.
    private let testOrchestrator: (any LLMOrchestrator)?
    /// Injected at init for testing mise en place; nil means use the live MiseEnPlaceService.
    private let testMiseEnPlaceService: (any MiseEnPlaceServiceProtocol)?
    /// The active LLM Task. Non-nil while a call is in flight.
    private var llmTask: Task<Void, Never>?
    /// Separate task slot for mise en place — independent of the chat LLM task.
    private var miseEnPlaceTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    /// Monotonically incremented per send. Used by the deferred cleanup to avoid
    /// clearing a newer task's reference when an old (cancelled) task finishes.
    private var llmGeneration = 0

    /// Cache of AI-generated summaries for pre-canvas sessions.
    /// Key: recipe UUID. Warmed from disk on every `loadRecentSessions()` call.
    /// Mutated on the main actor; not published — RecentRecipesView drives its own
    /// shimmer/display state and consults this cache on every sidebar open.
    var sessionSummaryCache: [UUID: SessionSummaryCacheEntry] = [:]

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

    static let recipeId            = UUID(uuidString: "00000000-0000-0000-FFFF-000000000001")!
    static let ingredientGroupId   = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    static let ingredientFlourId   = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let ingredientSaltId    = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let ingredientWaterId   = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let stepMixId         = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let stepBakeId        = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!
    static let stepDoneId        = UUID(uuidString: "00000000-0000-0000-0001-000000000003")!

    init(testOrchestrator: (any LLMOrchestrator)? = nil,
         testMiseEnPlaceService: (any MiseEnPlaceServiceProtocol)? = nil,
         sessionsDirectory: URL? = nil,
         photosBaseDirectory: URL? = nil,
         preferencesDefaults: UserDefaults? = nil,
         keyProvider: any OpenAIKeyProviding = KeychainOpenAIKeyProvider()) {
        self.testOrchestrator = testOrchestrator
        self.testMiseEnPlaceService = testMiseEnPlaceService
        self.keyProvider = keyProvider
        self.sessionsDirectory = sessionsDirectory
        self.photosBaseDirectory = photosBaseDirectory
        self.preferencesDefaults = preferencesDefaults
        isPersistenceEnabled = (testOrchestrator == nil)
        hasAPIKey = keyProvider.currentKey() != nil

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
                isSessionPersistable = true
                hasCanvas = snapshot.hasCanvas
                chatTranscript = snapshot.chatMessages
                nextLLMContext = snapshot.nextLLMContext
                ingredientsExpanded = snapshot.ingredientsExpanded
                stepsCompletedExpanded = snapshot.stepsCompletedExpanded
                miseEnPlaceExpanded = snapshot.miseEnPlaceExpanded
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
                    IngredientGroup(id: Self.ingredientGroupId, header: nil, items: [
                        Ingredient(id: Self.ingredientFlourId, text: "2 cups flour"),
                        Ingredient(id: Self.ingredientSaltId,  text: "1 tsp salt"),
                        Ingredient(id: Self.ingredientWaterId, text: "3/4 cup water"),
                    ]),
                ],
                steps: [
                    Step(id: Self.stepMixId,  text: "Mix dry ingredients",       status: .todo),
                    Step(id: Self.stepBakeId, text: "Bake at 375°F for 30 min",  status: .todo),
                    Step(id: Self.stepDoneId, text: "Let cool on rack",           status: .done),
                ]
            )
            uiState = .recipeOnly(recipe: recipe)
            chatTranscript = [
                ChatMessage(role: .system,    text: "Sous is ready. Tap the mic or type to get started."),
                ChatMessage(role: .assistant, text: "Hi! I'm looking at your Simple Bread recipe. What would you like to change?"),
                ChatMessage(role: .assistant, text: "Tip: use the Debug panel to simulate a patch if you want to test the review flow."),
            ]
        }

        // Persist collapsed-section state whenever the user toggles either section.
        // .dropFirst() skips the initial emission so these don't fire during init/restore.
        // newValue is passed through to saveSession because @Published fires in willSet —
        // before the backing store is updated — so reading self.ingredientsExpanded /
        // self.stepsCompletedExpanded at sink time would capture the old value.
        $ingredientsExpanded
            .dropFirst()
            .sink { [weak self] newValue in
                self?.saveSession(ingredientsExpanded: newValue)
            }
            .store(in: &cancellables)
        $stepsCompletedExpanded
            .dropFirst()
            .sink { [weak self] newValue in
                self?.saveSession(stepsCompletedExpanded: newValue)
            }
            .store(in: &cancellables)
        $miseEnPlaceExpanded
            .dropFirst()
            .sink { [weak self] newValue in
                self?.saveSession(miseEnPlaceExpanded: newValue)
            }
            .store(in: &cancellables)
    }

    deinit {
        llmTask?.cancel()
        miseEnPlaceTask?.cancel()
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
    func addMemory(_ text: String, firstPersonText: String? = nil) {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed.last == "." { trimmed = String(trimmed.dropLast()) }
        let fp = firstPersonText ?? MemoryPersonConverter.naiveToFirstPerson(trimmed)
        memories.append(MemoryItem(text: trimmed, firstPersonText: fp))
        saveMemories()
    }

    /// Replaces an existing memory (matched by id) and persists.
    func updateMemory(_ item: MemoryItem) {
        guard let idx = memories.firstIndex(where: { $0.id == item.id }) else { return }
        var sanitized = item
        if sanitized.text.last == "." { sanitized.text = String(sanitized.text.dropLast()) }
        memories[idx] = sanitized
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
    /// When firstPersonText is nil, generates it via MemoryPersonConverter before saving.
    func confirmMemory(text: String, firstPersonText: String? = nil) async {
        let fp: String
        if let provided = firstPersonText {
            fp = provided
        } else {
            fp = await MemoryPersonConverter.toFirstPerson(text: text)
        }
        addMemory(text, firstPersonText: fp)
        pendingMemoryProposal = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Saves the proposed memory without dismissing the toast. The toast remains visible
    /// so the countdown can complete before `dismissMemoryProposal` is called.
    func saveMemoryOnly(text: String, firstPersonText: String? = nil) async {
        let fp: String
        if let provided = firstPersonText {
            fp = provided
        } else {
            fp = await MemoryPersonConverter.toFirstPerson(text: text)
        }
        addMemory(text, firstPersonText: fp)
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
        canGenerateRecipe = false
        isSessionPersistable = false
        uiState = .chatOpen(
            recipe: Recipe(id: UUID(), version: 1, title: "New Recipe"),
            draftUserText: "",
            hidden: HiddenContext()
        )
        chatTranscript = []
        nextLLMContext = nil
        ingredientsExpanded = true
        stepsCompletedExpanded = false
        miseEnPlaceExpanded = false
    }

    /// Starts a new session immediately (previous session stays on disk in Recent Recipes).
    func requestNewSession() {
        startNewSession()
    }

    // MARK: - Recipe Reset

    /// Resets all step statuses to todo, clears mise en place check states, and clears any pending patch.
    /// Recipe content (title, ingredients, steps text, notes, mise en place entries) is unchanged.
    /// Chat history is preserved.
    func resetRecipe() {
        cancelLiveLLM()
        let recipe = uiState.recipe
        let resetSteps = recipe.steps.map { Step(id: $0.id, text: $0.text, status: .todo) }
        let resetMEP = recipe.miseEnPlace.map { entries in
            entries.map { entry in
                switch entry.content {
                case .solo(let instruction, _):
                    return MiseEnPlaceEntry(id: entry.id, content: .solo(instruction: instruction, isDone: false))
                case .group(let vesselName, let components):
                    let reset = components.map { MiseEnPlaceComponent(id: $0.id, text: $0.text, isDone: false) }
                    return MiseEnPlaceEntry(id: entry.id, content: .group(vesselName: vesselName, components: reset))
                }
            }
        }
        let reset = Recipe(
            id: recipe.id,
            version: recipe.version + 1,
            title: recipe.title,
            ingredients: recipe.ingredients,
            steps: resetSteps,
            notes: recipe.notes,
            miseEnPlace: resetMEP
        )
        uiState = .recipeOnly(recipe: reset)
        ingredientsExpanded = true
        stepsCompletedExpanded = false
        miseEnPlaceExpanded = false
        saveSession()
    }

    // MARK: - Recent Recipes

    /// Returns all saved recipe sessions, most recent first (current recipe is always first slot).
    /// Also warms `sessionSummaryCache` from each pre-canvas session's persisted cachedSummary,
    /// so the sidebar can display stored summaries immediately without re-running the model.
    func loadRecentSessions() -> [SessionSnapshot] {
        guard isPersistenceEnabled else { return [] }
        let sessions = Array(SessionPersistence.listAll(in: sessionsDirectory).prefix(20))
        for snapshot in sessions where !snapshot.hasCanvas {
            if let entry = snapshot.cachedSummary {
                sessionSummaryCache[snapshot.recipe.id] = entry
            }
        }
        return sessions
    }

    /// Persists an AI-generated summary for a pre-canvas session.
    /// Updates the in-memory cache and writes to the session file on disk so the
    /// summary survives app restarts without re-running the model.
    func updateSessionSummary(recipeId: UUID, messageCount: Int, summary: String) {
        let entry = SessionSummaryCacheEntry(messageCount: messageCount, summary: summary)
        sessionSummaryCache[recipeId] = entry
        guard isPersistenceEnabled else { return }
        let url = SessionPersistence.fileURL(for: recipeId, in: sessionsDirectory)
        if recipeId == uiState.recipe.id {
            // Active session: use the normal save path so makeSnapshot includes the entry.
            saveSession()
        } else {
            // Non-active session: load, patch cachedSummary only, save.
            guard let existing = SessionPersistence.load(from: url) else { return }
            let updated = SessionSnapshot(
                schemaVersion: existing.schemaVersion,
                hasCanvas: existing.hasCanvas,
                recipe: existing.recipe,
                pendingPatchSet: existing.pendingPatchSet,
                chatMessages: existing.chatMessages,
                nextLLMContext: existing.nextLLMContext,
                savedAt: existing.savedAt,
                ingredientsExpanded: existing.ingredientsExpanded,
                stepsCompletedExpanded: existing.stepsCompletedExpanded,
                miseEnPlaceExpanded: existing.miseEnPlaceExpanded,
                cachedSummary: entry
            )
            try? SessionPersistence.save(updated, to: url)
        }
    }

    /// Deletes the on-disk session for `snapshot`.
    func deleteRecentSession(_ snapshot: SessionSnapshot) {
        guard isPersistenceEnabled else { return }
        SessionPersistence.delete(recipeId: snapshot.recipe.id, in: sessionsDirectory)
        PhotoPersistence.deletePhotoDirectory(for: snapshot.recipe.id, baseDirectory: photosBaseDirectory)
    }

    /// Deletes the currently active recipe's session from disk and transitions to a new blank session.
    /// Called when the user confirms deletion of the active recipe from the History screen.
    func deleteActiveSessionAndStartNew() {
        if isPersistenceEnabled {
            let recipeId = uiState.recipe.id
            SessionPersistence.delete(recipeId: recipeId, in: sessionsDirectory)
            PhotoPersistence.deletePhotoDirectory(for: recipeId, baseDirectory: photosBaseDirectory)
        }
        startNewSession()
    }

    /// Resumes a previous session immediately (switch is non-destructive — current session stays on disk).
    /// No-ops if the snapshot's recipe ID matches the already-active session, preventing spurious
    /// duplicate resumes triggered by RecentRecipesView's initial render on app launch.
    func requestResumeSession(_ snapshot: SessionSnapshot) {
        guard snapshot.recipe.id != uiState.recipe.id else { return }
        resumeSession(snapshot)
    }

    /// Loads `snapshot` into the store as the active session.
    func resumeSession(_ snapshot: SessionSnapshot) {
        cancelLiveLLM()
        canGenerateRecipe = false
        isSessionPersistable = true
        hasCanvas = snapshot.hasCanvas
        chatTranscript = snapshot.chatMessages
        nextLLMContext = snapshot.nextLLMContext
        // uiState must be set before ingredientsExpanded / stepsCompletedExpanded so that
        // the Combine sinks — which call saveSession() — write to the new recipe's file,
        // not the outgoing recipe's file.
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
        ingredientsExpanded = snapshot.ingredientsExpanded
        stepsCompletedExpanded = snapshot.stepsCompletedExpanded
        miseEnPlaceExpanded = snapshot.miseEnPlaceExpanded
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

    /// Opens the chat sheet and sets a quoted row context (from the "Ask Sous" swipe action).
    func openChatWithRowContext(type: QuotedRowContext.RowType, text: String) {
        quotedRowContext = QuotedRowContext(type: type, text: text)
        send(.openChat)
    }

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
        #if DEBUG
        switch trimmed.lowercased() {
        case "trigger":
            canGenerateRecipe = true
            return
        case "trigger lorem":
            canGenerateRecipe = true
            append(ChatMessage(role: .assistant, text: """
                Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

                Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.

                Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?
                """))
            return
        default:
            break
        }
        #endif
        append(ChatMessage(role: .user, text: trimmed))
        // Capture and clear quoted context before dispatching — it applies only to this send.
        let capturedItem: ReferencedItem? = quotedRowContext.map { ctx in
            ReferencedItem(type: ctx.type == .ingredient ? .ingredient : .step, text: ctx.text)
        }
        quotedRowContext = nil
        if useLiveLLM {
            llmGeneration += 1
            let gen = llmGeneration
            llmTask = Task { await self.sendWithLLM(trimmed, referencedItem: capturedItem, generation: gen) }
        } else {
            let patchSet = proposer.propose(userText: trimmed, recipe: uiState.recipe)
            send(.patchReceived(patchSet))
            append(ChatMessage(role: .assistant, text: "Proposed changes are ready — review them on the recipe."))
        }
    }

    /// Returns a safe display string for the assistant's conversational message.
    /// If the model returns JSON in assistant_message (e.g. a bare "{" when it confused
    /// which field to put the patchSet in), substitute a context-appropriate fallback so
    /// the PatchReview "Sous says..." banner always shows natural language.
    private func sanitizedAssistantMessage(_ message: String, hasCanvas: Bool) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.first != "{", trimmed.first != "[" else {
            return hasCanvas ? "Here are the proposed changes." : "Your recipe is ready to review."
        }
        return message
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

    private func sendWithLLM(_ userText: String, referencedItem: ReferencedItem? = nil, dropConversationHistoryTail: Bool = true, generation: Int) async {
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
            conversationHistory: buildConversationHistory(dropLastEntry: dropConversationHistoryTail),
            referencedItem: referencedItem
        )
#if DEBUG
        lastDebugLLMRequest = request
#endif

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
            // Guard against the model embedding JSON in assistant_message (e.g. returning
            // "{" when it starts to write the patchSet into the wrong field). Only a
            // natural-language string should ever appear in the PatchReview "Sous says..." banner.
            let safeMessage = sanitizedAssistantMessage(assistantMessage, hasCanvas: hasCanvas)
            append(ChatMessage(role: .assistant, text: safeMessage))
            llmDebugStatus = "succeeded"
            if let memory = proposedMemory { proposeMemory(text: memory) }

        case .noPatches(let assistantMessage, _, let debug, let proposedMemory, let suggestGenerate):
            lastDebugBundle = debug
            nextLLMContext = nil
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "succeeded"
            if let memory = proposedMemory { proposeMemory(text: memory) }
            if !hasCanvas, let sg = suggestGenerate { canGenerateRecipe = sg }

        case .failure(let fallbackPatchSet, let assistantMessage, _, let debug, _):
            lastDebugBundle = debug
            if let fallback = fallbackPatchSet {
                send(.patchReceived(fallback))
            }
            append(ChatMessage(role: .assistant, text: assistantMessage))
            llmDebugStatus = "failed"
        }
    }

    // MARK: - Generate recipe silently

    /// Sends "Generate the recipe." to the LLM without appending a user bubble to the transcript.
    /// Used by the "Make this recipe" pill button.
    func sendGenerateRecipeSilently() {
        guard !hasPendingPatch else { return }
        if useLiveLLM && llmTask != nil {
            llmDebugStatus = "blocked_inflight_llm"
            return
        }
        if useLiveLLM {
            llmGeneration += 1
            let gen = llmGeneration
            llmTask = Task { await self.sendWithLLM("Generate the recipe.", dropConversationHistoryTail: false, generation: gen) }
        }
    }

    // MARK: - Photo send support

    /// Whether a patch is currently pending review. Exposed for photo send guard checks.
    var hasActivePatch: Bool { hasPendingPatch }

    /// Whether a live LLM call (text or multimodal) is currently in flight.
    var isLLMCallInFlight: Bool { useLiveLLM && llmTask != nil }

    /// Appends a user chat message after successful photo preparation.
    /// Called by the view only after `PhotoSendCoordinator.send(text:recipe:)` returns non-nil.
    /// If `imageData` is provided, the JPEG bytes are written to disk and the relative path
    /// is stored in the message for inline rendering.
    func appendPhotoMessage(_ text: String, imageData: Data? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageId = UUID()
        var photoPath: String? = nil
        if let data = imageData, isPersistenceEnabled {
            photoPath = PhotoPersistence.save(
                imageData: data,
                messageId: messageId,
                recipeId: uiState.recipe.id,
                baseDirectory: photosBaseDirectory
            )
        }
        append(ChatMessage(
            id: messageId,
            role: .user,
            text: trimmed.isEmpty ? "[Photo]" : trimmed,
            photoPath: photoPath
        ))
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

        case .noPatches(let assistantMessage, _, let debug, let proposedMemory, _):
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

    // MARK: - Mise en place

    /// Triggers the mise en place transformation for the current recipe.
    /// Single-flight: does nothing if a call is already in flight.
    func triggerMiseEnPlace() {
        guard miseEnPlaceTask == nil else { return }
        miseEnPlaceError = nil
        miseEnPlaceIsLoading = true
        miseEnPlaceTask = Task { await self.runMiseEnPlaceLLM() }
    }

    /// Reverts a mise en place item to not-done. Only called during the drain-phase
    /// countdown window; the UI guards the call site.
    /// The `id` may be a solo entry's ID or a component's ID inside a group.
    func markMiseEnPlaceUndone(_ id: UUID) {
        var recipe = uiState.recipe
        guard var entries = recipe.miseEnPlace else { return }
        var found = false
        for i in entries.indices {
            let entry = entries[i]
            switch entry.content {
            case .solo(let instruction, true) where entry.id == id:
                entries[i] = MiseEnPlaceEntry(id: entry.id, content: .solo(instruction: instruction, isDone: false))
                found = true
            case .group(let vesselName, var components):
                if let j = components.firstIndex(where: { $0.id == id && $0.isDone }) {
                    components[j] = MiseEnPlaceComponent(id: components[j].id, text: components[j].text, isDone: false)
                    entries[i] = MiseEnPlaceEntry(id: entry.id, content: .group(vesselName: vesselName, components: components))
                    found = true
                }
            default:
                break
            }
            if found { break }
        }
        guard found else { return }
        recipe.miseEnPlace = entries
        uiState = uiState.replacingRecipe(recipe)
        saveSession()
    }

    /// Marks a mise en place item as done. The `id` may be a solo entry's ID or
    /// a component's ID inside a group.
    func markMiseEnPlaceDone(_ id: UUID) {
        var recipe = uiState.recipe
        guard var entries = recipe.miseEnPlace else { return }
        var found = false
        for i in entries.indices {
            let entry = entries[i]
            switch entry.content {
            case .solo(let instruction, false) where entry.id == id:
                entries[i] = MiseEnPlaceEntry(id: entry.id, content: .solo(instruction: instruction, isDone: true))
                found = true
            case .group(let vesselName, var components):
                if let j = components.firstIndex(where: { $0.id == id && !$0.isDone }) {
                    components[j] = MiseEnPlaceComponent(id: components[j].id, text: components[j].text, isDone: true)
                    entries[i] = MiseEnPlaceEntry(id: entry.id, content: .group(vesselName: vesselName, components: components))
                    found = true
                }
            default:
                break
            }
            if found { break }
        }
        guard found else { return }
        recipe.miseEnPlace = entries
        uiState = uiState.replacingRecipe(recipe)
        saveSession()
    }

    func updateTitle(_ newTitle: String) {
        var recipe = uiState.recipe
        recipe.title = newTitle
        uiState = uiState.replacingRecipe(recipe)
        saveSession()
    }

    private func runMiseEnPlaceLLM() async {
        defer {
            miseEnPlaceTask = nil
            miseEnPlaceIsLoading = false
        }

        // When a test service is injected, bypass the API key check — the mock ignores it.
        let service: any MiseEnPlaceServiceProtocol
        let apiKey: String
        if let testService = testMiseEnPlaceService {
            service = testService
            apiKey = "__test__"
        } else {
            guard let key = resolvedAPIKey() else {
                miseEnPlaceError = "Couldn't generate mise en place — try again"
                return
            }
            service = MiseEnPlaceService()
            apiKey = key
        }

        let recipe = uiState.recipe

        do {
            let response = try await service.run(recipe: recipe, apiKey: apiKey)

            guard !Task.isCancelled else { return }

            if response.miseEnPlace.isEmpty {
                miseEnPlaceError = "No prep steps found to separate"
                return
            }

            let mepSteps: [MiseEnPlaceEntry] = response.miseEnPlace.map { entry in
                switch entry {
                case .group(let vesselName, let componentTexts):
                    let components = componentTexts.map { MiseEnPlaceComponent(text: $0) }
                    return MiseEnPlaceEntry(content: .group(vesselName: vesselName, components: components))
                case .solo(let instruction):
                    return MiseEnPlaceEntry(content: .solo(instruction: instruction, isDone: false))
                }
            }
            let updatedProcedure = preservingDoneStatus(
                newTexts: response.updatedSteps,
                existingSteps: recipe.steps
            )

            var updatedRecipe = recipe
            updatedRecipe.version += 1
            updatedRecipe.miseEnPlace = mepSteps
            updatedRecipe.steps = updatedProcedure
            uiState = uiState.replacingRecipe(updatedRecipe)
            saveSession()

        } catch {
            guard !Task.isCancelled else { return }
            miseEnPlaceError = "Couldn't generate mise en place — try again"
        }
    }

    /// Re-creates procedure steps from the LLM-returned texts, preserving `done` status
    /// where the step text matches an existing done step exactly.
    private func preservingDoneStatus(newTexts: [String], existingSteps: [Step]) -> [Step] {
        let doneTexts = Set(existingSteps.filter { $0.status == .done }.map { $0.text })
        return newTexts.map { text in
            Step(text: text, status: doneTexts.contains(text) ? .done : .todo)
        }
    }

    // MARK: - Recipe Import

    /// Starts an import from pasted text. Skips OCR — text goes directly to the LLM structuring call.
    func sendImportRequest(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        importError = nil
        importSuccess = false
        importLoadingStage = .llm
        llmGeneration += 1
        let gen = llmGeneration
        llmTask = Task { await self.sendWithImportLLM(trimmed, generation: gen) }
    }

    /// Starts an import from a UIImage. Runs Vision OCR on-device first, then sends the
    /// extracted text to the LLM structuring call. No image is sent to OpenAI.
    func sendImportRequest(image: UIImage) {
        importError = nil
        importSuccess = false
        importLoadingStage = .ocr
        llmGeneration += 1
        let gen = llmGeneration
        llmTask = Task { await self.sendWithImportFromImage(image, generation: gen) }
    }

    private func sendWithImportFromImage(_ image: UIImage, generation: Int) async {
        defer {
            if llmGeneration == generation {
                llmTask = nil
                isThinking = false
            }
        }
        isThinking = true
        llmDebugStatus = "calling"

        guard let ocrText = await RecipeOCRService.recognizeText(in: image), !ocrText.isEmpty else {
            importError = "Couldn't read text from this photo. Try a clearer image or paste the recipe text instead."
            return
        }

        guard !Task.isCancelled else {
            llmDebugStatus = "cancelled"
            return
        }

        importLoadingStage = .llm
        await runImportLLM(userText: ocrText, generation: generation, isTextImport: false)
    }

    private func sendWithImportLLM(_ userText: String, generation: Int) async {
        defer {
            if llmGeneration == generation {
                llmTask = nil
                isThinking = false
            }
        }
        isThinking = true
        llmDebugStatus = "calling"
        await runImportLLM(userText: userText, generation: generation, isTextImport: true)
    }

    /// Shared LLM call body for both image and text import paths.
    /// Applies the extracted PatchSet directly — no patch review.
    private func runImportLLM(userText: String, generation: Int, isTextImport: Bool) async {
        let recipe = uiState.recipe

        let request = LLMRequest(
            recipeId: recipe.id.uuidString,
            recipeVersion: recipe.version,
            hasCanvas: false,
            userMessage: userText,
            recipeSnapshotForPrompt: recipe,
            userPrefs: buildLLMUserPrefs(),
            nextLLMContext: nil,
            conversationHistory: [],
            isImportExtraction: true
        )

        let llmClient = OpenAIClient(apiKey: resolvedAPIKey())
        let orchestrator: any LLMOrchestrator = testOrchestrator ?? OpenAILLMOrchestrator(
            client: llmClient,
            streamingClient: llmClient,
            model: liveLLMModel
        )

        let result = await orchestrator.run(request)

        #if DEBUG
        print("[runImportLLM] raw result: \(result)")
        #endif

        guard !Task.isCancelled else {
            llmDebugStatus = "cancelled"
            return
        }

        switch result {
        case .valid(let patchSet, let assistantMessage, _, let debug, _):
            lastDebugBundle = debug
            let current = uiState.recipe
            guard patchSet.baseRecipeId == current.id,
                  patchSet.baseRecipeVersion == current.version else {
                importError = "Couldn't extract this recipe. Please try again."
                llmDebugStatus = "fatal_recipeIdMismatch"
                return
            }
            guard let extracted = try? PatchApplier.apply(patchSet: patchSet, to: current) else {
                importError = "Couldn't apply the extracted recipe. Please try again."
                llmDebugStatus = "failed"
                return
            }
            // Apply directly — no patch review for import.
            uiState = .recipeOnly(recipe: extracted)
            hasCanvas = true
            isSessionPersistable = true
            chatTranscript = [ChatMessage(role: .assistant, text: assistantMessage)]
            nextLLMContext = nil
            llmDebugStatus = "succeeded"
            saveSession()
            importSuccess = true
            // Sheet handles dismissal after animating progress to 100% — see RecipeImportSheet.

        case .noPatches(_, _, let debug, _, _):
            lastDebugBundle = debug
            importError = isTextImport
                ? "Couldn't extract a recipe from this text — please check the text and try again."
                : "Couldn't extract a recipe here. Try a clearer photo or paste the text instead."
            llmDebugStatus = "failed"

        case .failure(_, _, _, let debug, _):
            lastDebugBundle = debug
            importError = isTextImport
                ? "Couldn't extract a recipe from this text — please check the text and try again."
                : "Couldn't extract this recipe — try a clearer photo, or paste the text instead."
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
            if message.role == .user { isSessionPersistable = true }
            saveSession()
        }
    }

    /// Builds the prior-turn history to include in the next LLM request.
    ///
    /// When `dropLastEntry` is true (the default), the last transcript entry is removed
    /// because it is the user message that was just appended before the async send and
    /// is already carried in LLMRequest.userMessage — including it again would duplicate it.
    /// Pass `false` for silent sends (e.g. "Generate the recipe.") that append no user
    /// bubble to the transcript; in those cases the tail entry is an assistant message
    /// and must be preserved so the model has full context.
    ///
    /// Filters out system messages and caps at 20 entries (10 full turns).
    private func buildConversationHistory(dropLastEntry: Bool = true) -> [LLMMessage] {
        let base = dropLastEntry ? Array(chatTranscript.dropLast()) : chatTranscript
        return base
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
            isSessionPersistable = true
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
                // Auto-expand ingredients when accepting a patch that touched them.
                if ps.patches.contains(where: {
                    switch $0 {
                    case .addIngredient, .updateIngredient, .removeIngredient: return true
                    default: return false
                    }
                }) {
                    ingredientsExpanded = true
                }
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
        case .patchReceived, .acceptPatch, .rejectPatch, .markStepDone, .markStepUndone:
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
    private func saveSession(
        ingredientsExpanded overrideIngredients: Bool? = nil,
        stepsCompletedExpanded overrideStepsCompleted: Bool? = nil,
        miseEnPlaceExpanded overrideMiseEnPlace: Bool? = nil
    ) {
        guard isPersistenceEnabled else { return }
        guard isSessionPersistable else { return }
        let url = SessionPersistence.fileURL(for: uiState.recipe.id, in: sessionsDirectory)
        try? SessionPersistence.save(
            makeSnapshot(
                ingredientsExpanded: overrideIngredients,
                stepsCompletedExpanded: overrideStepsCompleted,
                miseEnPlaceExpanded: overrideMiseEnPlace
            ),
            to: url
        )
    }

    private func makeSnapshot(
        ingredientsExpanded overrideIngredients: Bool? = nil,
        stepsCompletedExpanded overrideStepsCompleted: Bool? = nil,
        miseEnPlaceExpanded overrideMiseEnPlace: Bool? = nil
    ) -> SessionSnapshot {
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
            savedAt: Date(),
            ingredientsExpanded: overrideIngredients ?? ingredientsExpanded,
            stepsCompletedExpanded: overrideStepsCompleted ?? stepsCompletedExpanded,
            miseEnPlaceExpanded: overrideMiseEnPlace ?? miseEnPlaceExpanded,
            cachedSummary: sessionSummaryCache[uiState.recipe.id]
        )
    }

    // MARK: - Debug simulation

    func simulateValidPatch() {
        let recipe = uiState.recipe
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [
                .addIngredient(groupId: Self.ingredientGroupId, afterId: Self.ingredientFlourId, text: "1 tsp yeast"),
                .updateIngredient(id: Self.ingredientSaltId, text: "2 tsp salt"),
                .removeIngredient(id: Self.ingredientWaterId),

                .addStep(parentId: nil, afterId: Self.stepMixId, text: "Knead dough for 5 minutes", preassignedId: nil),
                .updateStep(id: Self.stepBakeId, text: "Bake at 350°F for 30 min"),

                .addNoteSection(afterId: nil, header: nil, items: ["From UI"]),
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

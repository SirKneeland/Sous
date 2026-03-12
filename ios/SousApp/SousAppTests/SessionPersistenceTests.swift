import XCTest
import SousCore
@testable import SousApp

// Tests use an in-memory temp URL so they never touch the real session file
// and clean up after themselves automatically.

@MainActor
final class SessionPersistenceTests: XCTestCase {

    private var testURL: URL!

    override func setUp() {
        super.setUp()
        testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sous_test_session_\(UUID().uuidString).json")
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testURL)
    }

    // MARK: - Helpers

    private func makeRecipe() -> Recipe {
        Recipe(
            id: UUID(),
            version: 3,
            title: "Persisted Pasta",
            ingredients: [
                Ingredient(id: UUID(), text: "200g pasta"),
                Ingredient(id: UUID(), text: "2 tbsp olive oil"),
            ],
            steps: [
                Step(id: UUID(), text: "Boil water",   status: .done),
                Step(id: UUID(), text: "Cook pasta",   status: .todo),
                Step(id: UUID(), text: "Drain and serve", status: .todo),
            ],
            notes: ["Add salt to the water"]
        )
    }

    private func makeSnapshot(withPatch: Bool = false, hasCanvas: Bool = true) -> SessionSnapshot {
        let recipe = makeRecipe()
        let patch: PatchSet? = withPatch ? PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: [.addNote(text: "Pending suggestion")]
        ) : nil
        return SessionSnapshot(
            schemaVersion: SessionSnapshot.currentSchemaVersion,
            hasCanvas: hasCanvas,
            recipe: recipe,
            pendingPatchSet: patch,
            chatMessages: [
                ChatMessage(role: .user,      text: "Make it spicier"),
                ChatMessage(role: .assistant, text: "How about adding chilli flakes?"),
            ],
            nextLLMContext: nil,
            savedAt: Date()
        )
    }

    // MARK: - Basic round-trip

    func test_save_andLoad_roundTrip() throws {
        let snapshot = makeSnapshot()
        try SessionPersistence.save(snapshot, to: testURL)
        let loaded = SessionPersistence.load(from: testURL)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.schemaVersion, SessionSnapshot.currentSchemaVersion)
        XCTAssertEqual(loaded?.recipe, snapshot.recipe)
        XCTAssertNil(loaded?.pendingPatchSet)
    }

    func test_save_andLoad_withPendingPatch() throws {
        let snapshot = makeSnapshot(withPatch: true)
        try SessionPersistence.save(snapshot, to: testURL)
        let loaded = SessionPersistence.load(from: testURL)

        XCTAssertNotNil(loaded?.pendingPatchSet)
        XCTAssertEqual(loaded?.pendingPatchSet, snapshot.pendingPatchSet)
    }

    func test_snapshot_preservesChatMessages() throws {
        let snapshot = makeSnapshot()
        try SessionPersistence.save(snapshot, to: testURL)
        let loaded = SessionPersistence.load(from: testURL)

        XCTAssertEqual(loaded?.chatMessages.count, 2)
        XCTAssertEqual(loaded?.chatMessages.first?.role, .user)
        XCTAssertEqual(loaded?.chatMessages.first?.text, "Make it spicier")
        XCTAssertEqual(loaded?.chatMessages.last?.role, .assistant)
        XCTAssertEqual(loaded?.chatMessages.last?.text, "How about adding chilli flakes?")
    }

    func test_snapshot_preservesRecipeDoneStep() throws {
        let snapshot = makeSnapshot()
        try SessionPersistence.save(snapshot, to: testURL)
        let loaded = SessionPersistence.load(from: testURL)

        let doneStep = loaded?.recipe.steps.first { $0.status == .done }
        XCTAssertNotNil(doneStep, "Done step must survive round-trip")
        XCTAssertEqual(doneStep?.text, "Boil water")
    }

    func test_snapshot_preservesNextLLMContext() throws {
        let context = NextLLMContext(lastPatchDecision: PatchDecision(
            patchSetId: UUID().uuidString,
            decision: .rejected,
            decidedAtMs: 99999
        ))
        let snapshot = SessionSnapshot(
            schemaVersion: SessionSnapshot.currentSchemaVersion,
            hasCanvas: true,
            recipe: makeRecipe(),
            pendingPatchSet: nil,
            chatMessages: [],
            nextLLMContext: context,
            savedAt: Date()
        )
        try SessionPersistence.save(snapshot, to: testURL)
        let loaded = SessionPersistence.load(from: testURL)

        XCTAssertEqual(loaded?.nextLLMContext?.lastPatchDecision?.decision, .rejected)
        XCTAssertEqual(loaded?.nextLLMContext?.lastPatchDecision?.decidedAtMs, 99999)
    }

    // MARK: - Failure modes

    func test_load_returnsNil_whenFileAbsent() {
        let absent = FileManager.default.temporaryDirectory
            .appendingPathComponent("sous_nonexistent_\(UUID().uuidString).json")
        XCTAssertNil(SessionPersistence.load(from: absent))
    }

    func test_load_returnsNil_whenFileCorrupt() throws {
        try "NOT VALID JSON !!!".data(using: .utf8)!.write(to: testURL)
        XCTAssertNil(SessionPersistence.load(from: testURL),
                     "Corrupt file must return nil, not crash")
    }

    func test_save_overwritesPreviousSave() throws {
        let snapshot1 = makeSnapshot()
        try SessionPersistence.save(snapshot1, to: testURL)

        var recipe2 = snapshot1.recipe
        recipe2.version = 999
        let snapshot2 = SessionSnapshot(
            schemaVersion: SessionSnapshot.currentSchemaVersion,
            hasCanvas: true,
            recipe: recipe2,
            pendingPatchSet: nil,
            chatMessages: [],
            nextLLMContext: nil,
            savedAt: Date()
        )
        try SessionPersistence.save(snapshot2, to: testURL)

        let loaded = SessionPersistence.load(from: testURL)
        XCTAssertEqual(loaded?.recipe.version, 999, "Second save must overwrite first")
    }

    // MARK: - AppStore restore integration

    func test_appStore_startsBlank_whenNoSnapshot() async {
        // Point AppStore at a nonexistent temp URL so it never finds a snapshot.
        // M11: first launch should produce blank/exploration state, not seed data.
        let noFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("sous_nosnapshot_\(UUID().uuidString).json")
        let store = AppStore(sessionFileURL: noFile)
        XCTAssertFalse(store.hasCanvas,
                       "AppStore must start in blank state when no snapshot is on disk")
        if case .chatOpen = store.uiState {} else {
            XCTFail("Expected chatOpen (exploration) state on first launch, got \(store.uiState)")
        }
        XCTAssertTrue(store.chatTranscript.isEmpty,
                      "Chat transcript must be empty on first launch")
    }

    func test_appStore_persistsRecipeOnAccept() async {
        // Drive AppStore through an accept-patch cycle and verify
        // that saveSession() is called (indirectly, by confirming it doesn't crash).
        let mock = SyncNoPatchOrchestrator()
        let store = AppStore(testOrchestrator: mock)

        // Simulate valid patch → validate → accept
        store.send(.openChat)
        let patchSet = PatchSet(
            baseRecipeId: AppStore.recipeId,
            baseRecipeVersion: 1,
            patches: [.addNote(text: "persistence test")]
        )
        store.send(.patchReceived(patchSet))
        store.send(.validatePatch)
        store.send(.acceptPatch)

        XCTAssertEqual(store.uiState.recipe.version, 2,
                       "Recipe version must increment after Accept")
        XCTAssertFalse(store.uiState.isPatchProposed,
                       "Patch must be cleared after Accept")
    }
}

// MARK: - Minimal test helper

private actor SyncNoPatchOrchestrator: LLMOrchestrator {
    func run(_ request: LLMRequest) async -> LLMResult {
        .noPatches(assistantMessage: "ok", raw: nil, debug: LLMDebugBundle(
            status: .succeeded, attemptCount: 1, maxAttempts: 2,
            requestId: "t", extractionUsed: false, repairUsed: false, timingTotalMs: 0
        ))
    }
}

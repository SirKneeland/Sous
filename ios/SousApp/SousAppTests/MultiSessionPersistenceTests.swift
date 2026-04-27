import XCTest
import SousCore
@testable import SousApp

@MainActor
final class MultiSessionPersistenceTests: XCTestCase {

    private var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sous_multi_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testDir)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        title: String,
        savedAt: Date = Date(),
        hasCanvas: Bool = true
    ) -> SessionSnapshot {
        let recipe = Recipe(
            id: UUID(),
            version: 1,
            title: title,
            ingredients: [IngredientGroup(items: [Ingredient(id: UUID(), text: "1 cup flour")])],
            steps: [Step(id: UUID(), text: "Mix", status: .todo)],
            notes: nil
        )
        return SessionSnapshot(
            schemaVersion: SessionSnapshot.currentSchemaVersion,
            hasCanvas: hasCanvas,
            recipe: recipe,
            pendingPatchSet: nil,
            chatMessages: [],
            nextLLMContext: nil,
            savedAt: savedAt
        )
    }

    private func save(_ snapshot: SessionSnapshot) throws {
        let url = SessionPersistence.fileURL(for: snapshot.recipe.id, in: testDir)
        try SessionPersistence.save(snapshot, to: url)
    }

    // MARK: - listAll

    func test_listAll_returnsEmpty_whenDirectoryIsEmpty() {
        XCTAssertTrue(SessionPersistence.listAll(in: testDir).isEmpty)
    }

    func test_listAll_returnsSavedSessions() throws {
        try save(makeSnapshot(title: "Pasta"))
        try save(makeSnapshot(title: "Bread"))
        XCTAssertEqual(SessionPersistence.listAll(in: testDir).count, 2)
    }

    func test_listAll_sortedByRecencyDescending() throws {
        let older = makeSnapshot(title: "Old Recipe", savedAt: Date(timeIntervalSinceNow: -3600))
        let newer = makeSnapshot(title: "New Recipe", savedAt: Date())
        try save(older)
        try save(newer)
        let sessions = SessionPersistence.listAll(in: testDir)
        XCTAssertEqual(sessions.first?.recipe.title, "New Recipe")
        XCTAssertEqual(sessions.last?.recipe.title, "Old Recipe")
    }

    func test_listAll_includesBlankSessions() throws {
        try save(makeSnapshot(title: "Blank", hasCanvas: false))
        XCTAssertEqual(
            SessionPersistence.listAll(in: testDir).count, 1,
            "Exploration sessions (no canvas) must appear in history"
        )
    }

    func test_listAll_excludesWrongSchemaVersion() throws {
        let recipe = Recipe(id: UUID(), version: 1, title: "Old", ingredients: [], steps: [], notes: [])
        let badSnapshot = SessionSnapshot(
            schemaVersion: 0,
            hasCanvas: true,
            recipe: recipe,
            pendingPatchSet: nil,
            chatMessages: [],
            nextLLMContext: nil,
            savedAt: Date()
        )
        let url = SessionPersistence.fileURL(for: recipe.id, in: testDir)
        try SessionPersistence.save(badSnapshot, to: url)
        XCTAssertTrue(
            SessionPersistence.listAll(in: testDir).isEmpty,
            "Sessions with a stale schema version must be excluded"
        )
    }

    // MARK: - fileURL

    func test_fileURL_usesExpectedNamingConvention() {
        let id = UUID()
        let url = SessionPersistence.fileURL(for: id, in: testDir)
        XCTAssertTrue(url.lastPathComponent.hasPrefix("sous_session_"))
        XCTAssertTrue(url.pathExtension == "json")
        XCTAssertTrue(url.lastPathComponent.contains(id.uuidString))
    }

    // MARK: - delete

    func test_delete_removesSessionFromDisk() throws {
        let snapshot = makeSnapshot(title: "To Delete")
        try save(snapshot)
        XCTAssertEqual(SessionPersistence.listAll(in: testDir).count, 1)
        SessionPersistence.delete(recipeId: snapshot.recipe.id, in: testDir)
        XCTAssertTrue(SessionPersistence.listAll(in: testDir).isEmpty)
    }

    func test_delete_isNoOp_whenFileDoesNotExist() {
        // Should not crash
        SessionPersistence.delete(recipeId: UUID(), in: testDir)
    }

    // MARK: - AppStore integration

    func test_appStore_loadsMostRecentSession_onInit() async throws {
        let older = makeSnapshot(title: "Older Soup", savedAt: Date(timeIntervalSinceNow: -200))
        let newer = makeSnapshot(title: "Newer Pasta", savedAt: Date())
        try save(older)
        try save(newer)
        let store = AppStore(sessionsDirectory: testDir)
        XCTAssertEqual(store.uiState.recipe.title, "Newer Pasta",
                       "AppStore must restore the most recently saved session")
    }

    func test_appStore_loadRecentSessions_includesCurrentRecipe() async throws {
        let snap = makeSnapshot(title: "Carbonara")
        try save(snap)
        let store = AppStore(sessionsDirectory: testDir)
        // Carbonara is the current recipe — it must appear first in recents.
        let recents = store.loadRecentSessions()
        XCTAssertEqual(recents.count, 1)
        XCTAssertEqual(recents.first?.recipe.title, "Carbonara",
                       "The currently active recipe must appear in the recent recipes list")
    }

    func test_appStore_loadRecentSessions_includesAllSessions() async throws {
        let current = makeSnapshot(title: "Current",  savedAt: Date())
        let other1  = makeSnapshot(title: "Pasta",    savedAt: Date(timeIntervalSinceNow: -100))
        let other2  = makeSnapshot(title: "Bread",    savedAt: Date(timeIntervalSinceNow: -200))
        try save(current)
        try save(other1)
        try save(other2)
        let store = AppStore(sessionsDirectory: testDir)
        // Current is most recent and loads as active session — it must appear first in recents.
        let recents = store.loadRecentSessions()
        XCTAssertEqual(recents.count, 3)
        XCTAssertEqual(recents[0].recipe.title, "Current")
        XCTAssertEqual(recents[1].recipe.title, "Pasta")
        XCTAssertEqual(recents[2].recipe.title, "Bread")
    }

    func test_appStore_startNewSession_keepsOldSessionOnDisk() async throws {
        let original = makeSnapshot(title: "Old Bread")
        try save(original)
        let store = AppStore(sessionsDirectory: testDir)
        // The store loaded Old Bread. Start a new session.
        store.startNewSession()
        // Old Bread must still be on disk.
        let all = SessionPersistence.listAll(in: testDir)
        XCTAssertTrue(
            all.contains { $0.recipe.title == "Old Bread" },
            "Starting a new session must not delete previous recipe sessions"
        )
    }

    func test_newSession_doesNotWriteBlankEntryToHistory() async throws {
        let original = makeSnapshot(title: "Old Bread")
        try save(original)
        let store = AppStore(sessionsDirectory: testDir)
        store.startNewSession()
        let blankRecipeId = store.uiState.recipe.id
        // History must still contain only the previous session — no blank entry for the new one.
        let all = SessionPersistence.listAll(in: testDir)
        XCTAssertFalse(
            all.contains { $0.recipe.id == blankRecipeId },
            "A blank new session must not be written to history before the user interacts"
        )
        XCTAssertEqual(all.count, 1,
                       "History must still have exactly one entry after tapping New Recipe without interacting")
    }

    func test_newSession_persistsAfterFirstUserMessage() async throws {
        let original = makeSnapshot(title: "Old Bread")
        try save(original)
        let store = AppStore(sessionsDirectory: testDir)
        store.startNewSession()
        let blankRecipeId = store.uiState.recipe.id
        // Simulate the user sending a message (appendPhotoMessage appends a .user bubble).
        store.appendPhotoMessage("Make it spicier")
        // Now the session must be on disk.
        let all = SessionPersistence.listAll(in: testDir)
        XCTAssertTrue(
            all.contains { $0.recipe.id == blankRecipeId },
            "Session must be saved once the user sends a message"
        )
    }

    func test_firstLaunch_doesNotWriteBlankEntry() async throws {
        // testDir is empty — simulates first launch with no history.
        let store = AppStore(sessionsDirectory: testDir)
        // No user interaction — history must remain empty.
        XCTAssertTrue(
            SessionPersistence.listAll(in: testDir).isEmpty,
            "First launch blank session must not be written to history before user interaction"
        )
        _ = store.uiState // silence unused warning
    }

    func test_appStore_resumeSession_restoresRecipeAndTranscript() async throws {
        let snapshot = SessionSnapshot(
            schemaVersion: SessionSnapshot.currentSchemaVersion,
            hasCanvas: true,
            recipe: Recipe(
                id: UUID(), version: 2, title: "Bolognese",
                ingredients: [IngredientGroup(items: [Ingredient(id: UUID(), text: "500g mince")])],
                steps: [Step(id: UUID(), text: "Brown the mince", status: .done)],
                notes: [NoteSection(items: ["Classic Italian"])]
            ),
            pendingPatchSet: nil,
            chatMessages: [
                ChatMessage(role: .user,      text: "Add more garlic"),
                ChatMessage(role: .assistant, text: "Sure, adding garlic now"),
            ],
            nextLLMContext: nil,
            savedAt: Date()
        )
        try save(snapshot)

        // Start with a different active session, then resume Bolognese.
        let other = makeSnapshot(title: "Other Recipe", savedAt: Date(timeIntervalSinceNow: 1))
        try save(other)
        let store = AppStore(sessionsDirectory: testDir)
        store.resumeSession(snapshot)

        XCTAssertEqual(store.uiState.recipe.title, "Bolognese")
        XCTAssertEqual(store.uiState.recipe.version, 2)
        XCTAssertTrue(store.hasCanvas)
        XCTAssertEqual(store.chatTranscript.count, 2)
        XCTAssertEqual(store.chatTranscript.first?.text, "Add more garlic")
    }
}

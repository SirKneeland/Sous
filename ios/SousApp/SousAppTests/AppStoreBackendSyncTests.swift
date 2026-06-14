import XCTest
import SousCore
@testable import SousApp

@MainActor
final class AppStoreBackendSyncTests: XCTestCase {

    /// Builds a persistence-enabled store wired to a mock backend, isolated to a
    /// throwaway defaults suite + temp sessions directory.
    private func makeStore(backend: MockBackend) -> (AppStore, UserDefaults) {
        let suite = UserDefaults(suiteName: "appstore-sync-\(UUID().uuidString)")!
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = AppStore(sessionsDirectory: dir, preferencesDefaults: suite, backend: backend)
        return (store, suite)
    }

    private func drainMain() async {
        for _ in 0..<10 { await Task.yield() }
    }

    // MARK: sync on save

    func test_updatePreferences_syncsToBackend() async {
        let backend = MockBackend()
        let (store, _) = makeStore(backend: backend)

        var prefs = store.userPreferences
        prefs.hardAvoids = ["cilantro"]
        store.updatePreferences(prefs)
        await drainMain()

        XCTAssertEqual(backend.syncedPreferences.last?.hardAvoids, ["cilantro"])
    }

    func test_addMemory_syncsToBackend() async {
        let backend = MockBackend()
        let (store, _) = makeStore(backend: backend)

        store.addMemory("hates cilantro")
        await drainMain()

        XCTAssertEqual(backend.syncedMemories.last?.map(\.text), ["hates cilantro"])
    }

    func test_deleteMemory_syncsUpdatedList() async {
        let backend = MockBackend()
        let (store, _) = makeStore(backend: backend)
        store.addMemory("one")
        store.addMemory("two")
        await drainMain()
        let toDelete = store.memories.first { $0.text == "one" }!

        store.deleteMemory(toDelete)
        await drainMain()

        XCTAssertEqual(backend.syncedMemories.last?.map(\.text), ["two"])
    }

    // MARK: hydrate (server-wins merge)

    func test_hydrate_serverWinsOnOwnedFields_preservesLocalOnly() async {
        let backend = MockBackend()
        var serverPrefs = UserPreferences()
        serverPrefs.hardAvoids = ["shellfish"]
        serverPrefs.personalityMode = "playful"
        backend.fetchPreferencesResult = .success(serverPrefs)
        let (store, _) = makeStore(backend: backend)

        // Local-only field that the server does not own.
        var local = store.userPreferences
        local.voiceGender = .masculine
        local.hardAvoids = ["peanuts"]
        store.updatePreferences(local)
        await drainMain()

        await store.hydrateFromBackend()

        XCTAssertEqual(store.userPreferences.hardAvoids, ["shellfish"], "server wins on owned field")
        XCTAssertEqual(store.userPreferences.personalityMode, "playful")
        XCTAssertEqual(store.userPreferences.voiceGender, .masculine, "local-only field preserved")
    }

    func test_hydrate_emptyServer_pushesLocalMemoriesUp() async {
        let backend = MockBackend()
        backend.fetchMemoriesResult = .success([])
        let (store, _) = makeStore(backend: backend)
        store.addMemory("local memory")
        await drainMain()
        let beforeCount = backend.syncedMemories.count

        await store.hydrateFromBackend()
        await drainMain()

        XCTAssertEqual(store.memories.map(\.text), ["local memory"], "local memory retained")
        XCTAssertGreaterThan(backend.syncedMemories.count, beforeCount, "local memories pushed up")
    }

    func test_hydrate_mergesMemoriesUnion_serverWinsOnConflict() async {
        let backend = MockBackend()
        let serverMemory = MemoryItem(text: "server memory")
        backend.fetchMemoriesResult = .success([serverMemory])
        let (store, _) = makeStore(backend: backend)
        store.addMemory("device memory")
        await drainMain()

        await store.hydrateFromBackend()
        await drainMain()

        let texts = store.memories.map(\.text)
        XCTAssertTrue(texts.contains("server memory"))
        XCTAssertTrue(texts.contains("device memory"))
    }

    // MARK: delete account wipes local data

    func test_clearAllLocalData_wipesEverything() async {
        let backend = MockBackend()
        let (store, suite) = makeStore(backend: backend)
        store.addMemory("a memory")
        var prefs = store.userPreferences
        prefs.hardAvoids = ["gluten"]
        store.updatePreferences(prefs)
        await drainMain()

        store.clearAllLocalData()

        XCTAssertTrue(store.memories.isEmpty)
        XCTAssertEqual(store.userPreferences, UserPreferences())
        XCTAssertTrue(MemoriesPersistence.load(from: suite).isEmpty)
        XCTAssertFalse(store.hasCanvas, "returns to blank state")
    }
}

import XCTest
import SousCore
@testable import SousApp

@MainActor
final class MemoriesTests: XCTestCase {

    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suiteName = "com.sous.memorytests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - MemoryItem

    func test_memoryItem_defaultCreatedAt_isNow() {
        let before = Date()
        let item = MemoryItem(text: "I avoid shellfish")
        let after = Date()
        XCTAssertTrue(item.createdAt >= before && item.createdAt <= after)
    }

    func test_memoryItem_hasUniqueIds() {
        let a = MemoryItem(text: "first")
        let b = MemoryItem(text: "second")
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - MemoriesPersistence

    func test_saveAndLoad_roundTrip() {
        let items = [
            MemoryItem(text: "I avoid cilantro"),
            MemoryItem(text: "I cook on induction"),
        ]
        MemoriesPersistence.save(items, to: testDefaults)
        let loaded = MemoriesPersistence.load(from: testDefaults)
        XCTAssertEqual(loaded.map { $0.text }, items.map { $0.text })
    }

    func test_load_returnsEmpty_whenNothingSaved() {
        let loaded = MemoriesPersistence.load(from: testDefaults)
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_clear_removesMemories() {
        MemoriesPersistence.save([MemoryItem(text: "test")], to: testDefaults)
        MemoriesPersistence.clear(from: testDefaults)
        XCTAssertTrue(MemoriesPersistence.load(from: testDefaults).isEmpty)
    }

    // MARK: - AppStore memory CRUD

    func test_addMemory_appendsAndPersists() async {
        let store = AppStore(testOrchestrator: MockMemoryOrchestrator())
        store.addMemory("I avoid peanuts")
        XCTAssertEqual(store.memories.count, 1)
        XCTAssertEqual(store.memories.first?.text, "I avoid peanuts")
    }

    func test_addMemory_ignoresBlankText() async {
        let store = AppStore(testOrchestrator: MockMemoryOrchestrator())
        store.addMemory("   ")
        XCTAssertTrue(store.memories.isEmpty)
    }

    func test_deleteMemory_removesItem() async {
        let store = AppStore(testOrchestrator: MockMemoryOrchestrator())
        store.addMemory("I avoid gluten")
        let item = store.memories[0]
        store.deleteMemory(item)
        XCTAssertTrue(store.memories.isEmpty)
    }

    func test_updateMemory_replacesText() async {
        let store = AppStore(testOrchestrator: MockMemoryOrchestrator())
        store.addMemory("I avoid shellfish")
        var updated = store.memories[0]
        updated.text = "I avoid all seafood"
        store.updateMemory(updated)
        XCTAssertEqual(store.memories[0].text, "I avoid all seafood")
    }

    // MARK: - Memory proposal flow

    func test_proposeMemory_setsPendingProposal() async {
        let store = AppStore(testOrchestrator: MockMemoryOrchestrator())
        store.proposeMemory(text: "I cook on induction")
        XCTAssertEqual(store.pendingMemoryProposal, "I cook on induction")
    }

    func test_confirmMemory_addsMemoryAndClearsProposal() async {
        let store = AppStore(testOrchestrator: MockMemoryOrchestrator())
        store.proposeMemory(text: "I avoid garlic")
        store.confirmMemory(text: "I avoid garlic")
        XCTAssertNil(store.pendingMemoryProposal, "Proposal must be cleared after confirm")
        XCTAssertEqual(store.memories.first?.text, "I avoid garlic")
    }

    func test_dismissMemoryProposal_clearsProposalWithoutSaving() async {
        let store = AppStore(testOrchestrator: MockMemoryOrchestrator())
        store.proposeMemory(text: "I avoid garlic")
        store.dismissMemoryProposal()
        XCTAssertNil(store.pendingMemoryProposal, "Proposal must be cleared after dismiss")
        XCTAssertTrue(store.memories.isEmpty, "No memory must be saved after dismiss")
    }

    // MARK: - Memory loaded from UserDefaults on init

    func test_appStore_loadsMemories_onInit() async throws {
        let items = [MemoryItem(text: "I avoid nuts")]
        MemoriesPersistence.save(items, to: testDefaults)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sous_memtest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppStore(sessionsDirectory: dir, preferencesDefaults: testDefaults)
        XCTAssertEqual(store.memories.map { $0.text }, ["I avoid nuts"])
    }

    // MARK: - Memories injected into LLM request

    func test_memories_areInjectedIntoLLMRequest() async {
        let capturer = CapturingMemoryOrchestrator()
        let store = AppStore(testOrchestrator: capturer)
        store.addMemory("I cook on induction")
        store.send(.openChat)
        store.sendUserMessage("help me cook pasta")

        // Give async task time to run
        for _ in 0..<5 { await Task.yield() }

        let requests = await capturer.requests
        XCTAssertFalse(requests.isEmpty, "Expected at least one LLM call")
        XCTAssertTrue(requests[0].userPrefs.memories.contains("I cook on induction"),
                      "Memories must be injected into LLM request")
    }
}

// MARK: - Test helpers

private actor MockMemoryOrchestrator: LLMOrchestrator {
    func run(_ request: LLMRequest) async -> LLMResult {
        .noPatches(assistantMessage: "ok", raw: nil, debug: LLMDebugBundle(
            status: .succeeded, attemptCount: 1, maxAttempts: 2,
            requestId: "t", extractionUsed: false, repairUsed: false, timingTotalMs: 0
        ), proposedMemory: nil)
    }
}

private actor CapturingMemoryOrchestrator: LLMOrchestrator {
    private(set) var requests: [LLMRequest] = []
    func run(_ request: LLMRequest) async -> LLMResult {
        requests.append(request)
        return .noPatches(assistantMessage: "ok", raw: nil, debug: LLMDebugBundle(
            status: .succeeded, attemptCount: 1, maxAttempts: 2,
            requestId: "t", extractionUsed: false, repairUsed: false, timingTotalMs: 0
        ), proposedMemory: nil)
    }
}

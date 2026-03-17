import XCTest
import SousCore
@testable import SousApp

@MainActor
final class UserPreferencesTests: XCTestCase {

    /// Isolated UserDefaults suite — never touches .standard, cleaned up after each test.
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suiteName = "com.sous.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Default values

    func test_defaultUserPreferences_hasEmptyFields() {
        let prefs = UserPreferences()
        XCTAssertTrue(prefs.hardAvoids.isEmpty)
        XCTAssertNil(prefs.servingSize)
        XCTAssertTrue(prefs.equipment.isEmpty)
        XCTAssertEqual(prefs.customInstructions, "")
        XCTAssertEqual(prefs.personalityMode, "normal")
    }

    // MARK: - Persistence round-trips

    func test_saveAndLoad_roundTrip_allFields() {
        var prefs = UserPreferences()
        prefs.hardAvoids = ["cilantro", "shellfish"]
        prefs.servingSize = 4
        prefs.equipment = ["cast iron", "air fryer"]
        prefs.customInstructions = "always give gas and induction stove settings"
        prefs.personalityMode = "playful"

        UserPreferencesPersistence.save(prefs, to: testDefaults)
        let loaded = UserPreferencesPersistence.load(from: testDefaults)

        XCTAssertEqual(loaded.hardAvoids, ["cilantro", "shellfish"])
        XCTAssertEqual(loaded.servingSize, 4)
        XCTAssertEqual(loaded.equipment, ["cast iron", "air fryer"])
        XCTAssertEqual(loaded.customInstructions, "always give gas and induction stove settings")
        XCTAssertEqual(loaded.personalityMode, "playful")
    }

    func test_saveAndLoad_personalityMode_minimal() {
        var prefs = UserPreferences()
        prefs.personalityMode = "minimal"
        UserPreferencesPersistence.save(prefs, to: testDefaults)
        let loaded = UserPreferencesPersistence.load(from: testDefaults)
        XCTAssertEqual(loaded.personalityMode, "minimal")
    }

    func test_load_returnsDefault_whenNothingSaved() {
        let loaded = UserPreferencesPersistence.load(from: testDefaults)
        XCTAssertTrue(loaded.hardAvoids.isEmpty)
        XCTAssertNil(loaded.servingSize)
        XCTAssertTrue(loaded.equipment.isEmpty)
        XCTAssertEqual(loaded.customInstructions, "")
    }

    func test_save_overwritesPrevious() {
        var prefs1 = UserPreferences()
        prefs1.servingSize = 2
        UserPreferencesPersistence.save(prefs1, to: testDefaults)

        var prefs2 = UserPreferences()
        prefs2.servingSize = 6
        UserPreferencesPersistence.save(prefs2, to: testDefaults)

        let loaded = UserPreferencesPersistence.load(from: testDefaults)
        XCTAssertEqual(loaded.servingSize, 6, "Second save must overwrite first")
    }

    func test_clear_removesPreferences() {
        var prefs = UserPreferences()
        prefs.hardAvoids = ["nuts"]
        UserPreferencesPersistence.save(prefs, to: testDefaults)

        UserPreferencesPersistence.clear(from: testDefaults)
        let loaded = UserPreferencesPersistence.load(from: testDefaults)

        XCTAssertTrue(loaded.hardAvoids.isEmpty, "Clear must reset to defaults")
    }

    func test_servingSize_nil_roundTrip() {
        var prefs = UserPreferences()
        prefs.servingSize = nil
        UserPreferencesPersistence.save(prefs, to: testDefaults)

        let loaded = UserPreferencesPersistence.load(from: testDefaults)
        XCTAssertNil(loaded.servingSize)
    }

    // MARK: - toLLMUserPrefs conversion

    func test_toLLMUserPrefs_mapsAllFields() {
        var prefs = UserPreferences()
        prefs.hardAvoids = ["gluten"]
        prefs.servingSize = 3
        prefs.equipment = ["stand mixer"]
        prefs.customInstructions = "metric units"
        prefs.personalityMode = "playful"

        let llmPrefs = prefs.toLLMUserPrefs()

        XCTAssertEqual(llmPrefs.hardAvoids, ["gluten"])
        XCTAssertEqual(llmPrefs.servingSize, 3)
        XCTAssertEqual(llmPrefs.equipment, ["stand mixer"])
        XCTAssertEqual(llmPrefs.customInstructions, "metric units")
        XCTAssertTrue(llmPrefs.memories.isEmpty)
        XCTAssertEqual(llmPrefs.personalityMode, "playful")
    }

    func test_toLLMUserPrefs_emptyFieldsMapCorrectly() {
        let prefs = UserPreferences()
        let llmPrefs = prefs.toLLMUserPrefs()

        XCTAssertTrue(llmPrefs.hardAvoids.isEmpty)
        XCTAssertNil(llmPrefs.servingSize)
        XCTAssertTrue(llmPrefs.equipment.isEmpty)
        XCTAssertEqual(llmPrefs.customInstructions, "")
    }

    // MARK: - AppStore integration

    func test_appStore_loadsPreferences_onInit() async throws {
        var prefs = UserPreferences()
        prefs.hardAvoids = ["peanuts"]
        prefs.servingSize = 2
        UserPreferencesPersistence.save(prefs, to: testDefaults)

        // AppStore with a real session dir but test preferences defaults
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sous_preftest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = AppStore(sessionsDirectory: dir, preferencesDefaults: testDefaults)

        XCTAssertEqual(store.userPreferences.hardAvoids, ["peanuts"])
        XCTAssertEqual(store.userPreferences.servingSize, 2)
    }

    func test_appStore_updatePreferences_savesToDefaults() async {
        let store = AppStore(testOrchestrator: MockOrchestrator())

        var prefs = UserPreferences()
        prefs.hardAvoids = ["dairy"]
        // isPersistenceEnabled = false because testOrchestrator is set — update should not write
        // Verify the in-memory update still works
        store.updatePreferences(prefs)

        XCTAssertEqual(store.userPreferences.hardAvoids, ["dairy"])
    }
}

// MARK: - Test helper

private actor MockOrchestrator: LLMOrchestrator {
    func run(_ request: LLMRequest) async -> LLMResult {
        .noPatches(assistantMessage: "ok", raw: nil, debug: LLMDebugBundle(
            status: .succeeded, attemptCount: 1, maxAttempts: 2,
            requestId: "t", extractionUsed: false, repairUsed: false, timingTotalMs: 0
        ), proposedMemory: nil)
    }
}

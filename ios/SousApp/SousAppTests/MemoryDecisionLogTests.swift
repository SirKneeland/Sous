import XCTest
import SousCore
@testable import SousApp

// MARK: - MemoryDecisionLogTests

/// Covers the debug-only memory decision log that backs section 8 of the diagnostic export.
@MainActor
final class MemoryDecisionLogTests: XCTestCase {

    private func makeStore() -> AppStore {
        AppStore(testOrchestrator: SilentOrchestrator())
    }

    private func markdown(_ store: AppStore) -> String {
        DebugDiagnosticExporter(store: store).buildMarkdown()
    }

    // MARK: - Logging

    func test_proposal_isLoggedAsPending() async throws {
        let store = makeStore()
        store.handleProposedMemory("You avoid cilantro", turnSource: "no cilantro please")

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertEqual(record.proposedText, "You avoid cilantro")
        XCTAssertEqual(record.turnSource, "no cilantro please")
        XCTAssertEqual(record.fate, .pending)
        XCTAssertEqual(store.pendingMemoryProposal, "You avoid cilantro",
                       "Logging must not change the existing proposal behaviour")
    }

    func test_turnWithoutProposal_isStillLogged() async throws {
        let store = makeStore()
        store.handleProposedMemory(nil, turnSource: "how long do I boil this")

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertNil(record.proposedText)
        XCTAssertEqual(record.fate, .noProposal,
                       "No-proposal turns are what make the proposal rate legible")
        XCTAssertNil(store.pendingMemoryProposal)
    }

    // MARK: - Fates

    func test_countdownSave_isRecordedAsAutomatic() async throws {
        let store = makeStore()
        store.handleProposedMemory("You cook on induction", turnSource: "I have an induction hob")
        await store.saveMemoryOnly(text: "You cook on induction", firstPersonText: "I cook on induction",
                                   trigger: .countdownExpired)

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertEqual(record.fate, .saved(trigger: .countdownExpired, savedText: "You cook on induction"))
    }

    func test_tappedSave_isDistinguishedFromCountdown() async throws {
        let store = makeStore()
        store.handleProposedMemory("You love garlic", turnSource: "garlic is the best")
        await store.saveMemoryOnly(text: "You love garlic", firstPersonText: "I love garlic",
                                   trigger: .tappedSave)

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertEqual(record.fate, .saved(trigger: .tappedSave, savedText: "You love garlic"))
    }

    func test_editedSave_recordsBothProposedAndSavedText() async throws {
        let store = makeStore()
        store.handleProposedMemory("You love garlic", turnSource: "garlic is the best")
        await store.saveMemoryOnly(text: "You love roasted garlic", firstPersonText: "I love roasted garlic",
                                   trigger: .editedThenSaved)

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertEqual(record.proposedText, "You love garlic")
        XCTAssertEqual(record.fate, .saved(trigger: .editedThenSaved, savedText: "You love roasted garlic"))
    }

    func test_skip_isRecorded() async throws {
        let store = makeStore()
        store.handleProposedMemory("You avoid cilantro", turnSource: "not today")
        store.dismissMemoryProposal()

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertEqual(record.fate, .skipped)
        XCTAssertTrue(store.memories.isEmpty)
    }

    func test_dismissAfterSave_doesNotOverwriteTheSave() async throws {
        let store = makeStore()
        store.handleProposedMemory("You cook for two kids", turnSource: "I cook for my kids")
        await store.saveMemoryOnly(text: "You cook for two kids", firstPersonText: "I cook for two kids",
                                   trigger: .countdownExpired)
        // The toast takes itself off screen after saving; that must not read as a skip.
        store.dismissMemoryProposal()

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertEqual(record.fate, .saved(trigger: .countdownExpired, savedText: "You cook for two kids"))
    }

    func test_secondProposal_supersedesAnUnresolvedFirst() async throws {
        let store = makeStore()
        store.handleProposedMemory("You avoid cilantro", turnSource: "first turn")
        store.handleProposedMemory("You love garlic", turnSource: "second turn")

        XCTAssertEqual(store.memoryDecisionLog.count, 2)
        XCTAssertEqual(store.memoryDecisionLog[0].fate, .supersededByLaterProposal)
        XCTAssertEqual(store.memoryDecisionLog[1].fate, .pending)
    }

    // MARK: - Duplicate Detection

    func test_proposalMatchingSavedMemory_isFlaggedAsDuplicate() async throws {
        let store = makeStore()
        store.addMemory("You avoid cilantro")
        store.handleProposedMemory("you avoid cilantro.", turnSource: "still no cilantro")

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertEqual(record.duplicateOf, "You avoid cilantro",
                       "Case and trailing punctuation must not defeat duplicate detection")
    }

    func test_unrelatedProposal_isNotFlaggedAsDuplicate() async throws {
        let store = makeStore()
        store.addMemory("You avoid cilantro")
        store.handleProposedMemory("You cook on induction", turnSource: "induction hob")

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertNil(record.duplicateOf)
    }

    // MARK: - Log Cap

    func test_logIsCappedAndDropsOldestFirst() async {
        let store = makeStore()
        let cap = AppStore.maxMemoryDecisionLogEntries
        for i in 0..<(cap + 5) {
            store.handleProposedMemory(nil, turnSource: "turn \(i)")
        }

        XCTAssertEqual(store.memoryDecisionLog.count, cap)
        XCTAssertEqual(store.memoryDecisionLog.first?.turnSource, "turn 5",
                       "The oldest entries must be the ones dropped")
    }

    func test_pendingProposalSurvivesLogTrimming() async throws {
        let store = makeStore()
        for i in 0..<AppStore.maxMemoryDecisionLogEntries {
            store.handleProposedMemory(nil, turnSource: "turn \(i)")
        }
        store.handleProposedMemory("You love garlic", turnSource: "garlic")
        await store.saveMemoryOnly(text: "You love garlic", firstPersonText: "I love garlic",
                                   trigger: .countdownExpired)

        let record = try XCTUnwrap(store.memoryDecisionLog.last)
        XCTAssertEqual(record.fate, .saved(trigger: .countdownExpired, savedText: "You love garlic"),
                       "Trimming must not leave the pending index pointing at the wrong entry")
    }

    // MARK: - Export Rendering

    func test_export_includesMemoryDecisionsWithCounts() async {
        let store = makeStore()
        store.handleProposedMemory(nil, turnSource: "how long do I boil this")
        store.handleProposedMemory("You avoid cilantro", turnSource: "no cilantro")
        await store.saveMemoryOnly(text: "You avoid cilantro", firstPersonText: "I avoid cilantro",
                                   trigger: .countdownExpired)

        let md = markdown(store)
        XCTAssertTrue(md.contains("## 8. Memory Decisions"))
        XCTAssertTrue(md.contains("**Turns with a proposal:** 1 of 2"))
        XCTAssertTrue(md.contains("**Proposals saved:** 1 — of which 1 saved themselves without a tap"))
        XCTAssertTrue(md.contains("no cilantro"), "The message that triggered the proposal must appear")
        XCTAssertTrue(md.contains("countdown expired"), "How it saved must be visible")
    }

    func test_export_withNoTurns_saysSo() async {
        let store = makeStore()
        let md = markdown(store)
        XCTAssertTrue(md.contains("## 8. Memory Decisions"))
        XCTAssertTrue(md.contains("(no turns yet that could have produced a memory)"))
    }

    func test_export_marksMemoriesAddedDuringThisRun() async {
        let store = makeStore()
        store.addMemory("You avoid cilantro")

        let md = markdown(store)
        XCTAssertTrue(md.contains("You avoid cilantro  ← added during this app run"))
    }
}

// MARK: - SilentOrchestrator

/// Never called by these tests — they drive the store's memory API directly.
private actor SilentOrchestrator: LLMOrchestrator {
    func run(_ request: LLMRequest) async -> LLMResult {
        .noPatches(assistantMessage: "", raw: nil,
                   debug: LLMDebugBundle(status: .succeeded, attemptCount: 1, maxAttempts: 1,
                                         requestId: "silent", extractionUsed: false,
                                         repairUsed: false, timingTotalMs: 0),
                   proposedMemory: nil, suggestGenerate: nil)
    }
}

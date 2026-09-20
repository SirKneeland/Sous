import XCTest
import SousCore
@testable import SousApp

// MARK: - ImportDebugOrchestrator

/// Returns a fixed result, carrying a raw wire response so tests can assert the diagnostic
/// export reproduces exactly what the model sent back.
private actor ImportDebugOrchestrator: LLMOrchestrator {
    private let makeResult: @Sendable (LLMRequest) -> LLMResult
    private(set) var requests: [LLMRequest] = []

    init(makeResult: @escaping @Sendable (LLMRequest) -> LLMResult) {
        self.makeResult = makeResult
    }

    func run(_ request: LLMRequest) async -> LLMResult {
        requests.append(request)
        return makeResult(request)
    }
}

// MARK: - ImportDebugExportTests

@MainActor
final class ImportDebugExportTests: XCTestCase {

    // MARK: - Helpers

    private static let rawJSON = #"{"assistantMessage":"Got your Carbonara!","patchSet":{"patches":[]}}"#

    private func rawResponse(_ text: String = rawJSON) -> LLMRawResponse {
        LLMRawResponse(
            rawText: text,
            requestId: "import-test",
            attempt: 1,
            timingMs: 42,
            httpStatus: 200,
            transport: .mock,
            promptTokens: 120,
            completionTokens: 80,
            totalTokens: 200
        )
    }

    private func debugBundle(status: LLMDebugStatus = .succeeded, outcome: String = "valid") -> LLMDebugBundle {
        LLMDebugBundle(
            status: status,
            attemptCount: 1, maxAttempts: 3,
            requestId: "import-test",
            extractionUsed: false, repairUsed: false,
            timingTotalMs: 42,
            model: "gpt-5.4-mini",
            promptVersion: "v1",
            outcome: outcome,
            promptTokens: 120, completionTokens: 80, totalTokens: 200
        )
    }

    /// Orchestrator that extracts a minimal valid recipe for whatever recipe the store passes in.
    private func successOrchestrator(raw: LLMRawResponse?) -> ImportDebugOrchestrator {
        let debug = debugBundle()
        return ImportDebugOrchestrator { request in
            let recipeId = UUID(uuidString: request.recipeId) ?? UUID()
            let patchSet = PatchSet(
                baseRecipeId: recipeId,
                baseRecipeVersion: request.recipeVersion,
                patches: [
                    .setTitle("Spaghetti Carbonara"),
                    .addIngredient(groupId: nil, afterId: nil, text: "200g spaghetti"),
                    .addStep(parentId: nil, afterId: nil, text: "Boil pasta", preassignedId: nil),
                ]
            )
            return .valid(patchSet: patchSet, assistantMessage: "Got your Carbonara!",
                          raw: raw, debug: debug, proposedMemory: nil)
        }
    }

    private func drainMain() async {
        for _ in 0..<10 { await Task.yield() }
    }

    private func markdown(_ store: AppStore) -> String {
        DebugDiagnosticExporter(store: store).buildMarkdown()
    }

    // MARK: - Record Capture

    func test_textImport_recordsPastedTextAndRawResponse() async throws {
        let store = AppStore(testOrchestrator: successOrchestrator(raw: rawResponse()))
        store.startNewSession()

        store.sendImportRequest(text: "Carbonara\n200g spaghetti\nBoil pasta")
        await drainMain()

        let record = try XCTUnwrap(store.lastImportDebugRecord)
        XCTAssertEqual(record.source, .pastedText)
        XCTAssertEqual(record.inputText, "Carbonara\n200g spaghetti\nBoil pasta",
                       "The pasted text must be captured verbatim")
        XCTAssertEqual(record.rawResponse, Self.rawJSON,
                       "The model's literal response must be captured")
        XCTAssertEqual(record.outcome, .succeeded)
        XCTAssertNil(record.imageDescription, "Text imports have no source photo")
        XCTAssertNotNil(record.request, "The dispatched request must be captured")
    }

    func test_import_recordsRealImportRequest_notAReconstruction() async throws {
        let store = AppStore(testOrchestrator: successOrchestrator(raw: rawResponse()))
        store.startNewSession()

        store.sendImportRequest(text: "some recipe text")
        await drainMain()

        let request = try XCTUnwrap(store.lastDebugLLMRequest)
        XCTAssertEqual(request.isImportExtraction, true,
                       "The exporter must print the import prompt, not a rebuilt chat prompt")
        XCTAssertEqual(request.userMessage, "some recipe text")
    }

    func test_importFailure_recordsOutcomeAndInput() async throws {
        let debug = debugBundle(status: .failed, outcome: "failure")
        let raw = rawResponse("not json at all")
        let orchestrator = ImportDebugOrchestrator { _ in
            .failure(fallbackPatchSet: nil, assistantMessage: "Something went wrong.",
                     raw: raw, debug: debug, error: .schemaInvalid)
        }
        let store = AppStore(testOrchestrator: orchestrator)
        store.startNewSession()

        store.sendImportRequest(text: "unparseable recipe")
        await drainMain()

        let record = try XCTUnwrap(store.lastImportDebugRecord)
        XCTAssertEqual(record.inputText, "unparseable recipe",
                       "A failed import must still capture what went in")
        XCTAssertEqual(record.rawResponse, "not json at all")
        if case .failed = record.outcome {} else {
            XCTFail("Expected a failed outcome, got \(record.outcome)")
        }
        XCTAssertFalse(store.hasCanvas, "Pre-condition: a failed import leaves no canvas")
    }

    func test_noPatchesImport_recordsFailure() async throws {
        let debug = debugBundle(outcome: "noPatches")
        let raw = rawResponse(#"{"assistantMessage":"What recipe did you mean?"}"#)
        let orchestrator = ImportDebugOrchestrator { _ in
            .noPatches(assistantMessage: "What recipe did you mean?", raw: raw,
                       debug: debug, proposedMemory: nil, suggestGenerate: nil)
        }
        let store = AppStore(testOrchestrator: orchestrator)
        store.startNewSession()

        store.sendImportRequest(text: "grocery list, not a recipe")
        await drainMain()

        let record = try XCTUnwrap(store.lastImportDebugRecord)
        XCTAssertEqual(record.inputText, "grocery list, not a recipe")
        XCTAssertEqual(record.rawResponse, #"{"assistantMessage":"What recipe did you mean?"}"#)
        if case .failed = record.outcome {} else {
            XCTFail("Expected a failed outcome for a no-patches import")
        }
    }

    // MARK: - Export Rendering

    func test_export_includesImportSection() async {
        let store = AppStore(testOrchestrator: successOrchestrator(raw: rawResponse()))
        store.startNewSession()

        store.sendImportRequest(text: "Carbonara\n200g spaghetti")
        await drainMain()

        let md = markdown(store)
        XCTAssertTrue(md.contains("## 7. Last Import Attempt"), "Section 7 must be present")
        XCTAssertTrue(md.contains("**Source:** Pasted text"))
        XCTAssertTrue(md.contains("Input — Pasted Text"))
        XCTAssertTrue(md.contains("Carbonara\n200g spaghetti"), "The input text must appear in the export")
        XCTAssertTrue(md.contains(Self.rawJSON), "The raw model response must appear in the export")
        XCTAssertTrue(md.contains("Import Prompt — System Message"),
                      "The prompt actually sent for the import must appear")
        XCTAssertTrue(md.contains("**Outcome:** Succeeded"))
    }

    func test_export_failedImport_includesInputAndResponse() async {
        let debug = debugBundle(status: .failed, outcome: "failure")
        let raw = rawResponse("garbled model output")
        let orchestrator = ImportDebugOrchestrator { _ in
            .failure(fallbackPatchSet: nil, assistantMessage: "Something went wrong.",
                     raw: raw, debug: debug, error: .schemaInvalid)
        }
        let store = AppStore(testOrchestrator: orchestrator)
        store.startNewSession()

        store.sendImportRequest(text: "recipe that fails")
        await drainMain()

        let md = markdown(store)
        XCTAssertTrue(md.contains("recipe that fails"),
                      "A failed import's input must be recoverable from the export")
        XCTAssertTrue(md.contains("garbled model output"),
                      "A failed import's raw response must be recoverable from the export")
        XCTAssertTrue(md.contains("**Outcome:** Failed"))
    }

    func test_export_withNoImport_saysSo() async {
        let store = AppStore(testOrchestrator: successOrchestrator(raw: nil))
        store.startNewSession()

        let md = markdown(store)
        XCTAssertTrue(md.contains("## 7. Last Import Attempt"))
        XCTAssertTrue(md.contains("(no recipe import attempted in this app run)"))
    }

    func test_export_truncatesOversizedInput() async {
        let cap = DebugDiagnosticExporter.maxCapturedCharacters
        let longText = String(repeating: "a", count: cap + 500) + "TAIL_MARKER"
        let store = AppStore(testOrchestrator: successOrchestrator(raw: rawResponse()))
        store.startNewSession()

        store.sendImportRequest(text: longText)
        await drainMain()

        let md = markdown(store)
        XCTAssertTrue(md.contains("[truncated"), "Oversized input must be marked as truncated")
        XCTAssertFalse(md.contains("TAIL_MARKER"),
                       "Content past the cap must not be written into the export")
    }
}

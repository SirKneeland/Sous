import XCTest
import SousCore
@testable import SousApp

// MARK: - LLMDebugExportTests

final class LLMDebugExportTests: XCTestCase {

    // MARK: - Helpers

    private static let allowedKeys: Set<String> = [
        "requestId", "timestamp", "model", "promptVersion",
        "attemptsUsed", "usedRepair", "usedExtraction",
        "outcome", "failureCategory", "terminationReason",
        "timingTotalMs", "timingNetworkMs",
        "promptTokens", "completionTokens", "totalTokens",
        "appVersion", "buildNumber"
    ]

    private func makeBundle(
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil
    ) -> LLMDebugBundle {
        LLMDebugBundle(
            status: .succeeded,
            attemptCount: 2,
            maxAttempts: 3,
            requestId: "test-req-id",
            extractionUsed: true,
            repairUsed: false,
            timingTotalMs: 1234,
            timingNetworkMs: 900,
            model: "gpt-5.4-mini",
            promptVersion: "v1",
            outcome: "valid",
            failureCategory: nil,
            terminationReason: "success",
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens
        )
    }

    private func encodedKeys(from export: LLMDebugExport) throws -> Set<String> {
        let data = try JSONEncoder().encode(export)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(json.keys)
    }

    // MARK: - Tests

    func test_exportKeysAreSubsetOfAllowedKeys() throws {
        // Nil optionals are omitted by JSONEncoder, so we only assert no unexpected keys appear.
        let export = LLMDebugExport.make(from: makeBundle(
            promptTokens: 100, completionTokens: 50, totalTokens: 150
        ))
        let keys = try encodedKeys(from: export)
        let unexpected = keys.subtracting(Self.allowedKeys)
        XCTAssertTrue(unexpected.isEmpty,
                      "Export contained unexpected keys: \(unexpected)")
    }

    func test_fullyPopulatedExportContainsAll17Keys() throws {
        // Directly construct with every optional field non-nil to guarantee all 17 keys encode.
        let export = LLMDebugExport(
            requestId: "req-full",
            timestamp: "2026-03-06T00:00:00Z",
            model: "gpt-5.4-mini",
            promptVersion: "v1",
            attemptsUsed: 3,
            usedRepair: true,
            usedExtraction: true,
            outcome: "failure",
            failureCategory: "network",
            terminationReason: "budget_exhausted",
            timingTotalMs: 2000,
            timingNetworkMs: 1500,
            promptTokens: 100,
            completionTokens: 50,
            totalTokens: 150,
            appVersion: "1.0",
            buildNumber: "42"
        )
        let keys = try encodedKeys(from: export)
        XCTAssertEqual(keys, Self.allowedKeys,
                       "Fully-populated export must encode exactly the 17 allowed keys")
    }

    func test_exportDoesNotContainForbiddenFields() throws {
        let export = LLMDebugExport.make(from: makeBundle())
        let keys = try encodedKeys(from: export)

        let forbidden: Set<String> = [
            "prompt", "userMessage", "systemPrompt", "recipe", "recipeText",
            "ingredients", "steps", "notes", "assistantMessage",
            "rawText", "rawResponse", "apiKey", "key"
        ]
        let intersection = keys.intersection(forbidden)
        XCTAssertTrue(intersection.isEmpty,
                      "Export must not contain forbidden fields: \(intersection)")
    }

    func test_encodingSucceedsWhenTokenFieldsAreNil() throws {
        let export = LLMDebugExport.make(from: makeBundle())
        let data = try JSONEncoder().encode(export)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        // Nil optionals are omitted from JSON by default — keys must not be present.
        XCTAssertNil(json["promptTokens"])
        XCTAssertNil(json["completionTokens"])
        XCTAssertNil(json["totalTokens"])
    }

    func test_encodingSucceedsWhenTokenFieldsArePresent() throws {
        let export = LLMDebugExport.make(from: makeBundle(
            promptTokens: 200, completionTokens: 100, totalTokens: 300
        ))
        let data = try JSONEncoder().encode(export)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["promptTokens"] as? Int, 200)
        XCTAssertEqual(json["completionTokens"] as? Int, 100)
        XCTAssertEqual(json["totalTokens"] as? Int, 300)
    }

    func test_jsonStringReturnsFallbackOnUnexpectedFailure() {
        // jsonString() must never throw — empty export state returns "{}"
        // We verify the happy path here (empty bundle → valid JSON string).
        let export = LLMDebugExport.make(from: makeBundle())
        let str = export.jsonString()
        XCTAssertFalse(str.isEmpty)
        XCTAssertNotEqual(str, "{}")  // a valid bundle should produce real JSON

        // Verify the string is valid JSON
        let data = Data(str.utf8)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func test_exportFieldValuesMatchBundle() throws {
        let bundle = makeBundle(promptTokens: 42, completionTokens: 21, totalTokens: 63)
        let export = LLMDebugExport.make(from: bundle)

        XCTAssertEqual(export.requestId, "test-req-id")
        XCTAssertEqual(export.model, "gpt-5.4-mini")
        XCTAssertEqual(export.promptVersion, "v1")
        XCTAssertEqual(export.attemptsUsed, 2)
        XCTAssertEqual(export.usedRepair, false)
        XCTAssertEqual(export.usedExtraction, true)
        XCTAssertEqual(export.outcome, "valid")
        XCTAssertNil(export.failureCategory)
        XCTAssertEqual(export.terminationReason, "success")
        XCTAssertEqual(export.timingTotalMs, 1234)
        XCTAssertEqual(export.timingNetworkMs, 900)
        XCTAssertEqual(export.promptTokens, 42)
        XCTAssertEqual(export.completionTokens, 21)
        XCTAssertEqual(export.totalTokens, 63)
    }
}

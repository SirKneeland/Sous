import XCTest
import SousCore
@testable import SousApp

final class VoiceTests: XCTestCase {

    // MARK: - Helpers

    private func decode(_ jsonString: String) throws -> RealtimeServerEvent {
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        return try JSONDecoder().decode(RealtimeServerEvent.self, from: data)
    }

    // MARK: - Group 1: RealtimeServerEvent decoding

    func test_sessionCreated_decodesCorrectly() throws {
        let result = try decode(#"{ "type": "session.created" }"#)
        guard case .sessionCreated = result else {
            XCTFail("Expected .sessionCreated, got \(result)")
            return
        }
    }

    func test_speechStarted_decodesCorrectly() throws {
        let result = try decode(#"{ "type": "input_audio_buffer.speech_started" }"#)
        guard case .speechStarted = result else {
            XCTFail("Expected .speechStarted, got \(result)")
            return
        }
    }

    func test_responseAudioDelta_decodesWithPayload() throws {
        let result = try decode(#"{ "type": "response.audio.delta", "delta": "SGVsbG8=" }"#)
        guard case .responseAudioDelta(let payload) = result else {
            XCTFail("Expected .responseAudioDelta, got \(result)")
            return
        }
        XCTAssertEqual(payload.delta, "SGVsbG8=")
    }

    func test_functionCallArgumentsDelta_decodesWithPayload() throws {
        let json = #"{ "type": "response.function_call_arguments.delta", "call_id": "call_abc", "delta": "{\"patch" }"#
        let result = try decode(json)
        guard case .functionCallArgumentsDelta(let payload) = result else {
            XCTFail("Expected .functionCallArgumentsDelta, got \(result)")
            return
        }
        XCTAssertEqual(payload.callId, "call_abc")
        XCTAssertEqual(payload.delta, "{\"patch")
    }

    func test_functionCallArgumentsDone_decodesWithPayload() throws {
        let json = #"{ "type": "response.function_call_arguments.done", "call_id": "call_abc", "name": "propose_patch", "arguments": "{}" }"#
        let result = try decode(json)
        guard case .functionCallArgumentsDone(let payload) = result else {
            XCTFail("Expected .functionCallArgumentsDone, got \(result)")
            return
        }
        XCTAssertEqual(payload.callId, "call_abc")
        XCTAssertEqual(payload.name, "propose_patch")
        XCTAssertEqual(payload.arguments, "{}")
    }

    // Audited RealtimeAPITypes.swift: .error decodes RealtimeErrorPayload directly from
    // the root decoder (no nested "error" key). The root JSON must carry "type" and "message".
    func test_error_decodesWithPayload() throws {
        let json = #"{ "type": "error", "message": "bad input" }"#
        let result = try decode(json)
        guard case .error(let payload) = result else {
            XCTFail("Expected .error, got \(result)")
            return
        }
        XCTAssertEqual(payload.message, "bad input")
    }

    func test_unknownEventType_decodesAsUnknown() throws {
        let result = try decode(#"{ "type": "some.future.event" }"#)
        guard case .unknown(let typeString) = result else {
            XCTFail("Expected .unknown, got \(result)")
            return
        }
        XCTAssertEqual(typeString, "some.future.event")
    }

    func test_malformedJSON_throwsDecodingError() throws {
        let badData = try XCTUnwrap("not json at all".data(using: .utf8))
        XCTAssertThrowsError(try JSONDecoder().decode(RealtimeServerEvent.self, from: badData))
    }

    // MARK: - Group 2: Function call argument accumulation
    //
    // handleServerEvent(_:) and functionCallAccumulator are both private on
    // VoiceModeCoordinator. @testable import only unlocks internal access, not
    // private. There is no public/internal surface through which synthetic events
    // can be driven without a live WebSocket. Tests in this group are skipped.

    func test_deltaAccumulation_appendsInOrder() throws {
        throw XCTSkip("handleServerEvent is private — not accessible from test target without production changes")
    }

    func test_deltaAccumulation_separatesCallIds() throws {
        throw XCTSkip("handleServerEvent is private — not accessible from test target without production changes")
    }

    func test_accumulatorClearedAfterDone() throws {
        throw XCTSkip("handleServerEvent is private — not accessible from test target without production changes")
    }

    // MARK: - Group 3: PatchSet round-trip

    func test_proposePatch_validArguments_decodesPatchSet() throws {
        let patchSetId = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        let baseRecipeId = UUID(uuidString: "87654321-4321-4321-4321-210987654321")!

        // Build a minimal valid PatchSet and encode it — simulating the flat
        // function arguments the model now emits directly (no patchJson wrapper).
        let patchSet = PatchSet(
            patchSetId: patchSetId,
            baseRecipeId: baseRecipeId,
            baseRecipeVersion: 1,
            status: .pending,
            patches: [.setTitle("Test Recipe")]
        )
        let argsData = try JSONEncoder().encode(patchSet)

        // Single-stage decode directly from arguments data
        let decoded = try JSONDecoder().decode(PatchSet.self, from: argsData)

        XCTAssertEqual(decoded.patchSetId, patchSetId)
        XCTAssertEqual(decoded.baseRecipeId, baseRecipeId)
        XCTAssertFalse(decoded.patches.isEmpty)
    }

    func test_proposePatch_invalidArguments_throwsDecodingError() throws {
        // Arguments that are not a valid PatchSet must throw
        let badArgs = try XCTUnwrap(#"{"not":"a patchset"}"#.data(using: .utf8))
        XCTAssertThrowsError(try JSONDecoder().decode(PatchSet.self, from: badArgs))
    }

    // MARK: - Group 4: ConversationItem null encoding

    func test_conversationItem_nilFieldsOmittedFromJSON() throws {
        let item = ConversationItem(
            type: "function_call_output",
            role: nil,
            content: nil,
            callId: "call_123",
            output: "{\"result\":\"ok\"}"
        )

        let message = try encodeWebSocketMessage(item)
        guard case .string(let jsonString) = message else {
            XCTFail("Expected .string message")
            return
        }

        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let dict = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        )

        XCTAssertNil(dict["role"], "role should be absent when nil")
        XCTAssertNil(dict["content"], "content should be absent when nil")
        XCTAssertEqual(dict["call_id"] as? String, "call_123")
        XCTAssertNotNil(dict["output"], "output should be present")
    }
}


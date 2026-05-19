import Foundation

// MARK: - Server Events (Decodable)

enum RealtimeServerEvent: Decodable {
    case sessionCreated
    case speechStarted
    case speechStopped
    case responseCreated
    case responseAudioDelta(ResponseAudioDeltaPayload)
    case responseAudioDone
    case responseAudioTranscriptDelta(ResponseAudioTranscriptDeltaPayload)
    case responseAudioTranscriptDone
    case functionCallArgumentsDelta(FunctionCallArgumentsDeltaPayload)
    case functionCallArgumentsDone(FunctionCallArgumentsDonePayload)
    case responseDone
    case error(RealtimeErrorPayload)
    case sessionUpdated
    case inputAudioBufferCommitted
    case conversationItemCreated
    case responseOutputItemAdded
    case responseOutputItemDone
    case responseContentPartAdded
    case responseContentPartDone
    case rateLimitsUpdated
    case inputAudioTranscriptionCompleted(InputAudioTranscriptionCompletedPayload)
    case unknown(String)

    private enum TypeKey: String, CodingKey { case type, error }
    private enum ErrorPayloadCodingKeys: String, CodingKey { case type, message }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "session.created":
            self = .sessionCreated
        case "input_audio_buffer.speech_started":
            self = .speechStarted
        case "input_audio_buffer.speech_stopped":
            self = .speechStopped
        case "response.created":
            self = .responseCreated
        case "response.audio.delta", "response.output_audio.delta":
            self = .responseAudioDelta(try ResponseAudioDeltaPayload(from: decoder))
        case "response.audio.done", "response.output_audio.done":
            self = .responseAudioDone
        case "response.audio_transcript.delta", "response.output_audio_transcript.delta":
            self = .responseAudioTranscriptDelta(try ResponseAudioTranscriptDeltaPayload(from: decoder))
        case "response.audio_transcript.done", "response.output_audio_transcript.done":
            self = .responseAudioTranscriptDone
        case "response.function_call_arguments.delta":
            self = .functionCallArgumentsDelta(try FunctionCallArgumentsDeltaPayload(from: decoder))
        case "response.function_call_arguments.done":
            self = .functionCallArgumentsDone(try FunctionCallArgumentsDonePayload(from: decoder))
        case "response.done":
            self = .responseDone
        case "error":
            let errorContainer = try container.nestedContainer(keyedBy: ErrorPayloadCodingKeys.self, forKey: .error)
            let errorType = try errorContainer.decode(String.self, forKey: .type)
            let errorMessage = try errorContainer.decode(String.self, forKey: .message)
            self = .error(RealtimeErrorPayload(type: errorType, message: errorMessage))
        case "session.updated":
            self = .sessionUpdated
        case "input_audio_buffer.committed":
            self = .inputAudioBufferCommitted
        case "conversation.item.created":
            self = .conversationItemCreated
        case "response.output_item.added":
            self = .responseOutputItemAdded
        case "response.output_item.done":
            self = .responseOutputItemDone
        case "response.content_part.added":
            self = .responseContentPartAdded
        case "response.content_part.done":
            self = .responseContentPartDone
        case "rate_limits.updated":
            self = .rateLimitsUpdated
        case "conversation.item.input_audio_transcription.completed":
            self = .inputAudioTranscriptionCompleted(try InputAudioTranscriptionCompletedPayload(from: decoder))
        default:
            self = .unknown(type)
        }
    }
}

// MARK: - Server Payload Structs

struct ResponseAudioDeltaPayload: Decodable {
    let delta: String
}

struct ResponseAudioTranscriptDeltaPayload: Decodable {
    let delta: String
}

struct FunctionCallArgumentsDeltaPayload: Decodable {
    let callId: String
    let delta: String

    private enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case delta
    }
}

struct FunctionCallArgumentsDonePayload: Decodable {
    let callId: String
    let name: String
    let arguments: String

    private enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case name
        case arguments
    }
}

struct InputAudioTranscriptionCompletedPayload: Decodable {
    let transcript: String
}

struct RealtimeErrorPayload: Decodable {
    let type: String
    let message: String
}

// MARK: - Client Events (Encodable)

struct InputAudioBufferAppendEvent: Encodable {
    let type = "input_audio_buffer.append"
    let audio: String
}

struct ResponseCreateEvent: Encodable {
    let type = "response.create"
}

struct ConversationItemCreateEvent: Encodable {
    let type = "conversation.item.create"
    let item: ConversationItem
}

// MARK: - Conversation Item Types

struct ConversationItem: Encodable {
    let type: String
    let role: String?
    let content: [ConversationItemContent]?
    let callId: String?
    let output: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(callId, forKey: .callId)
        try container.encodeIfPresent(output, forKey: .output)
    }

    private enum CodingKeys: String, CodingKey {
        case type, role, content, callId, output
    }
}

struct ConversationItemContent: Encodable {
    let type: String
    let text: String
}

// MARK: - Session Configuration

struct SessionUpdateEvent: Encodable {
    let type = "session.update"
    let session: SessionConfig
}

struct SessionConfig: Encodable {
    let type: String
    let instructions: String
    let tools: [RealtimeTool]
    let toolChoice: String
    let audio: SessionAudioConfig
}

struct SessionAudioConfig: Encodable {
    let input: SessionAudioInputConfig
    let output: SessionAudioOutputConfig
}

struct AudioFormat: Encodable {
    let type: String
    let rate: Int
}

struct InputAudioTranscription: Encodable {
    let model: String
}

struct SessionAudioInputConfig: Encodable {
    let format: AudioFormat
    let turnDetection: TurnDetection
    let transcription: InputAudioTranscription?
}

struct SessionAudioOutputConfig: Encodable {
    let format: AudioFormat
    let voice: String
}

struct TurnDetection: Encodable {
    let type: String
    let silenceDurationMs: Int
    let threshold: Double
    let prefixPaddingMs: Int
}

// MARK: - Tool Schema Types

struct RealtimeTool: Encodable {
    let type: String
    let name: String
    let description: String
    let parameters: RealtimeToolParameters
}

struct RealtimeToolParameters: Encodable {
    let type: String
    let properties: [String: RealtimeToolProperty]
    let required: [String]
}

struct RealtimeToolProperty: Encodable {
    let type: String
    let description: String?
}

// MARK: - WebSocket Message Encoding

func encodeWebSocketMessage<T: Encodable>(_ event: T) throws -> URLSessionWebSocketTask.Message {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let data = try encoder.encode(event)
    let string = String(data: data, encoding: .utf8) ?? ""
    return .string(string)
}

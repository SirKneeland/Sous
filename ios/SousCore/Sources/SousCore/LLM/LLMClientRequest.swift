import Foundation

// MARK: - LLMMessage

/// Transport-level message. No recipe semantics or prompt logic.
public struct LLMMessage: Equatable, Sendable {
    public enum Role: String, Equatable, Sendable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - LLMResponseFormat

/// Instructs the transport how to format the model's response.
public enum LLMResponseFormat: Equatable, Sendable {
    case text
    case jsonObject                   // OpenAI: { "type": "json_object" }
    case jsonSchema(name: String)     // placeholder; schema wiring comes later
}

// MARK: - LLMClientRequest

/// Pure transport payload passed to LLMClient.
/// No recipe knowledge, no prompt construction — that lives in LLMOrchestrator.
public struct LLMClientRequest: Sendable {
    /// Caller-supplied correlation ID. If nil, the client generates one.
    public let requestId: String?
    /// Model identifier forwarded verbatim to the API (e.g. "gpt-5.4-mini").
    /// Set by the caller (orchestrator or bootstrap); the client never hard-codes a default.
    public let model: String
    public let messages: [LLMMessage]
    public let responseFormat: LLMResponseFormat
    public let timeout: TimeInterval
    /// When non-nil the client attaches this image to the last user message as
    /// base64-encoded content (OpenAI vision format).  Text-only calls leave this nil.
    public let image: PreparedImage?

    public init(
        requestId: String? = nil,
        model: String,
        messages: [LLMMessage],
        responseFormat: LLMResponseFormat,
        timeout: TimeInterval,
        image: PreparedImage? = nil
    ) {
        self.requestId = requestId
        self.model = model
        self.messages = messages
        self.responseFormat = responseFormat
        self.timeout = timeout
        self.image = image
    }
}

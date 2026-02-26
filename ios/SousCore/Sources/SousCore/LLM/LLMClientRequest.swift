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
    public let messages: [LLMMessage]
    public let responseFormat: LLMResponseFormat
    public let timeout: TimeInterval

    public init(
        requestId: String? = nil,
        messages: [LLMMessage],
        responseFormat: LLMResponseFormat,
        timeout: TimeInterval
    ) {
        self.requestId = requestId
        self.messages = messages
        self.responseFormat = responseFormat
        self.timeout = timeout
    }
}

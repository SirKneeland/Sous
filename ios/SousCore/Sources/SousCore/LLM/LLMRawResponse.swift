import Foundation

// MARK: - LLMRawResponse

/// Raw wire response from whatever transport was used.
/// Captured before any decoding or validation so it can be attached to LLMDebugBundle.
public struct LLMRawResponse: Equatable, Sendable {

    /// Identifies the underlying transport that produced this response.
    public enum Transport: String, Equatable, Sendable {
        case openAI
        case mock
    }

    public let rawText: String
    public let requestId: String
    public let attempt: Int
    public let timingMs: Int
    public let httpStatus: Int?
    public let transport: Transport

    public init(
        rawText: String,
        requestId: String,
        attempt: Int,
        timingMs: Int,
        httpStatus: Int? = nil,
        transport: Transport
    ) {
        self.rawText = rawText
        self.requestId = requestId
        self.attempt = attempt
        self.timingMs = timingMs
        self.httpStatus = httpStatus
        self.transport = transport
    }
}

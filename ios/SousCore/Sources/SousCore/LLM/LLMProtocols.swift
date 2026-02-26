import Foundation

// MARK: - LLMClient

/// Network boundary. Accepts a pre-built request payload and returns raw wire response.
/// Implementations may talk to OpenAI, a mock, or any other transport.
public protocol LLMClient {
    func send(_ request: LLMClientRequest) async throws -> LLMRawResponse
}

// MARK: - LLMOrchestrator

/// Prompt / retry / repair boundary.
/// Handles prompt construction, retry loops, JSON repair, and validation.
/// Always returns exactly one LLMResult — at most one PatchSet by construction.
public protocol LLMOrchestrator {
    func run(_ request: LLMRequest) async -> LLMResult
}

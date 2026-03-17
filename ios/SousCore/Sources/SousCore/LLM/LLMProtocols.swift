import Foundation

// MARK: - LLMClient

/// Network boundary. Accepts a pre-built request payload and returns raw wire response.
/// Implementations may talk to OpenAI, a mock, or any other transport.
public protocol LLMClient {
    func send(_ request: LLMClientRequest) async throws -> LLMRawResponse
}

// MARK: - StreamingLLMClient

/// Extension of LLMClient that can stream raw content delta tokens.
/// OpenAIClient conforms to this; test mocks do not need to.
public protocol StreamingLLMClient: LLMClient {
    /// Returns an AsyncThrowingStream that yields raw token strings as they arrive
    /// from the model. Each yielded value is a new fragment of the model's output.
    func stream(_ request: LLMClientRequest) -> AsyncThrowingStream<String, Error>
}

// MARK: - LLMOrchestrator

/// Prompt / retry / repair boundary.
/// Handles prompt construction, retry loops, JSON repair, and validation.
/// Always returns exactly one LLMResult — at most one PatchSet by construction.
public protocol LLMOrchestrator {
    func run(_ request: LLMRequest) async -> LLMResult
    func run(_ request: MultimodalLLMRequest) async -> LLMResult
    func run(_ request: LLMRequest, onStreamToken: (@Sendable (String) -> Void)?) async -> LLMResult
}

public extension LLMOrchestrator {
    /// Default: strip the image and delegate to the text-only path.
    /// Concrete orchestrators (e.g. OpenAILLMOrchestrator) override this with a real
    /// vision-capable implementation.  Test mocks get this for free without changes.
    func run(_ request: MultimodalLLMRequest) async -> LLMResult {
        return await run(request.base)
    }

    /// Default: ignore streaming callback and delegate to the non-streaming path.
    /// Test mocks and any LLMOrchestrator that only implements run(_:) get this for free.
    func run(_ request: LLMRequest, onStreamToken: (@Sendable (String) -> Void)?) async -> LLMResult {
        return await run(request)
    }
}

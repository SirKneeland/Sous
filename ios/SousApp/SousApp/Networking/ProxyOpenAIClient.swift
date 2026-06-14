import Foundation
import SousCore

// MARK: - ProxyOpenAIClient

/// Concrete `StreamingLLMClient` that routes OpenAI chat-completions calls through
/// the Sous backend proxy (`POST /api/v1/proxy/chat`) instead of hitting OpenAI
/// directly. Used for every NON-BYOK user; BYOK users keep using `OpenAIClient`.
///
/// Transport-only, exactly like `OpenAIClient`:
///   - Builds the same OpenAI request body (the backend forwards it verbatim).
///   - Attaches the Sous session token as the Bearer credential (NOT an OpenAI key
///     — the server holds the OpenAI key; this client never sees it).
///   - Sets `X-Sous-Is-New-Recipe` so the backend can enforce the recipe cap, and
///     `X-Sous-Recipe-Id` for per-recipe abuse accounting.
///   - Parses the response identically — the proxy relays OpenAI's response shape
///     unchanged, so the orchestrator cannot tell the difference.
///
/// Constructed per-call in `AppStore` (so `isNewRecipe`/`recipeId` are baked in),
/// which is why it is a lightweight `Sendable` struct.
struct ProxyOpenAIClient: LLMClient {

    private let endpoint: URL
    /// Sous session token (Bearer). Read on the main actor at construction time.
    private let sessionToken: String
    private let isNewRecipe: Bool
    private let recipeId: String?
    private let session: any URLSessionProtocol
    /// Used only for streaming (`bytes(for:)` is not on `URLSessionProtocol`).
    private let streamSession: URLSession

    init(sessionToken: String,
         isNewRecipe: Bool,
         recipeId: String? = nil,
         endpoint: URL = SousBackendConfig.proxyChatURL,
         session: any URLSessionProtocol = URLSession.shared,
         streamSession: URLSession = .shared) {
        self.sessionToken = sessionToken
        self.isNewRecipe = isNewRecipe
        self.recipeId = recipeId
        self.endpoint = endpoint
        self.session = session
        self.streamSession = streamSession
    }

    // MARK: Header construction (shared by send + stream)

    private func makeRequest(timeout: TimeInterval) -> URLRequest {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(isNewRecipe ? "true" : "false", forHTTPHeaderField: "X-Sous-Is-New-Recipe")
        if let recipeId { req.setValue(recipeId, forHTTPHeaderField: "X-Sous-Recipe-Id") }
        req.timeoutInterval = timeout
        return req
    }

    // MARK: - LLMClient

    func send(_ request: LLMClientRequest) async throws -> LLMRawResponse {
        let resolvedId = request.requestId ?? UUID().uuidString
        guard !sessionToken.isEmpty else { throw LLMError.auth }

        var urlRequest = makeRequest(timeout: request.timeout)
        var body: [String: Any] = [
            "model": request.model,
            "messages": Self.buildMessagePayload(from: request),
        ]
        switch request.responseFormat {
        case .text:
            break
        case .jsonObject, .jsonSchema:
            body["response_format"] = ["type": "json_object"]
        }
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw LLMError.network
        }
        urlRequest.httpBody = httpBody

        let start = Date()
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:  throw LLMError.timeout
            case .cancelled: throw LLMError.cancelled
            default:         throw LLMError.network
            }
        }

        let ms = Int(Date().timeIntervalSince(start) * 1000)
        guard let httpResp = urlResponse as? HTTPURLResponse else { throw LLMError.network }
        let status = httpResp.statusCode
        guard status == 200 else { throw Self.mapHTTPError(status: status, headers: httpResp) }

        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first   = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw LLMError.decodeInvalidJSON
        }

        let usage = json["usage"] as? [String: Any]
        return LLMRawResponse(
            rawText: content,
            requestId: resolvedId,
            attempt: 1,
            timingMs: ms,
            httpStatus: status,
            transport: .openAI,
            promptTokens: usage?["prompt_tokens"] as? Int,
            completionTokens: usage?["completion_tokens"] as? Int,
            totalTokens: usage?["total_tokens"] as? Int
        )
    }

    // MARK: - Message serialization (mirrors OpenAIClient)

    private static func buildMessagePayload(from request: LLMClientRequest) -> [[String: Any]] {
        guard let image = request.image else {
            return request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        }
        let base64 = image.data.base64EncodedString()
        let dataURL = "data:\(image.mimeType);base64,\(base64)"
        return request.messages.enumerated().map { index, msg in
            guard index == request.messages.count - 1 else {
                return ["role": msg.role.rawValue, "content": msg.content]
            }
            let contentItems: [[String: Any]] = [
                ["type": "text", "text": msg.content],
                ["type": "image_url", "image_url": ["url": dataURL]],
            ]
            return ["role": msg.role.rawValue, "content": contentItems]
        }
    }

    private static func mapHTTPError(status: Int, headers: HTTPURLResponse) -> LLMError {
        switch status {
        case 429:
            let retryAfter = headers.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            return .rateLimited(retryAfterSec: retryAfter)
        case 401, 403:  return .auth
        case 400..<500: return .badRequest   // includes 402 cap_reached / 400 off_topic
        default:        return .server
        }
    }
}

// MARK: - StreamingLLMClient

extension ProxyOpenAIClient: StreamingLLMClient {

    /// Streams content delta tokens from the proxy. The backend adds
    /// `stream_options.include_usage` server-side; the trailing usage chunk has no
    /// `delta.content` and is harmlessly ignored here (same as the OpenAI path).
    func stream(_ request: LLMClientRequest) -> AsyncThrowingStream<String, Error> {
        let capturedToken = sessionToken
        let capturedSession = streamSession
        let capturedRequest = request
        let baseRequest = makeRequest(timeout: request.timeout)

        return AsyncThrowingStream { continuation in
            let task = Task {
                guard !capturedToken.isEmpty else {
                    continuation.finish(throwing: LLMError.auth)
                    return
                }

                var urlRequest = baseRequest
                var body: [String: Any] = [
                    "model": capturedRequest.model,
                    "messages": Self.buildStreamMessagePayload(from: capturedRequest),
                    "stream": true,
                ]
                switch capturedRequest.responseFormat {
                case .text:
                    break
                case .jsonObject, .jsonSchema:
                    body["response_format"] = ["type": "json_object"]
                }
                guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
                    continuation.finish(throwing: LLMError.network)
                    return
                }
                urlRequest.httpBody = httpBody

                do {
                    let (asyncBytes, response) = try await capturedSession.bytes(for: urlRequest)
                    guard let httpResp = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LLMError.network)
                        return
                    }
                    guard httpResp.statusCode == 200 else {
                        continuation.finish(throwing: Self.mapHTTPError(status: httpResp.statusCode, headers: httpResp))
                        return
                    }
                    for try await line in asyncBytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: LLMError.cancelled)
                            return
                        }
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let jsonData = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let first = choices.first,
                              let delta = first["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch let urlError as URLError {
                    switch urlError.code {
                    case .timedOut:  continuation.finish(throwing: LLMError.timeout)
                    case .cancelled: continuation.finish(throwing: LLMError.cancelled)
                    default:         continuation.finish(throwing: LLMError.network)
                    }
                } catch {
                    continuation.finish(throwing: LLMError.network)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Streaming omits images (matches `OpenAIClient` M18 text-only streaming scope).
    private static func buildStreamMessagePayload(from request: LLMClientRequest) -> [[String: Any]] {
        request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
    }
}

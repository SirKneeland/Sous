import Foundation
import SousCore

// MARK: - URLSessionProtocol

/// Abstraction over URLSession enabling unit tests to inject a mock without live network calls.
/// SousApp owns this protocol; URLSession is conformed retroactively within our module.
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - OpenAIClient

/// Concrete LLMClient backed by the OpenAI chat completions API.
///
/// Responsibilities (transport only):
///   - Accept a pre-built LLMClientRequest (messages + response_format + model)
///   - Enforce timeout via URLRequest.timeoutInterval
///   - Return LLMRawResponse (rawText = choices[0].message.content, metadata)
///
/// Non-responsibilities:
///   - No prompt construction
///   - No retry logic
///   - No recipe or patch semantics
///   - Does not inspect rawText for JSON validity (that is the orchestrator's job)
struct OpenAIClient: LLMClient {

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// Injected API key. Pass `nil` to trigger `.missingAPIKey` without any network call.
    /// Callers read from `ProcessInfo.processInfo.environment["OPENAI_API_KEY"]` at bootstrap.
    private let apiKey: String?
    private let session: any URLSessionProtocol
    /// Used only for streaming (bytes(for:) is not on URLSessionProtocol).
    private let streamSession: URLSession

    init(apiKey: String?,
         session: any URLSessionProtocol = URLSession.shared,
         streamSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
        self.streamSession = streamSession
    }

    // MARK: - LLMClient

    func send(_ request: LLMClientRequest) async throws -> LLMRawResponse {
        let resolvedId = request.requestId ?? UUID().uuidString

        // Guard: bail before touching the network if API key is absent.
        guard let key = apiKey, !key.isEmpty else {
            throw LLMError.missingAPIKey
        }

        // Build URLRequest.
        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = request.timeout

        // Assemble body — model comes from caller, never hard-coded here.
        var body: [String: Any] = [
            "model": request.model,
            "messages": buildMessagePayload(from: request)
        ]

        switch request.responseFormat {
        case .text:
            break   // omit response_format key; API defaults to plain text
        case .jsonObject:
            body["response_format"] = ["type": "json_object"]
        case .jsonSchema:
            // TODO: wire full json_schema(name:) once schema definition is available.
            // For now, fall back to json_object so the caller still gets structured output.
            body["response_format"] = ["type": "json_object"]
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw LLMError.network
        }
        urlRequest.httpBody = httpBody

        // Execute.
        let start = Date()
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            let ms = elapsed(since: start)
            debugLog("req=\(resolvedId) urlError=\(urlError.code.rawValue) timing=\(ms)ms")
            switch urlError.code {
            case .timedOut:  throw LLMError.timeout
            case .cancelled: throw LLMError.cancelled
            default:         throw LLMError.network
            }
        }

        let ms = elapsed(since: start)
        guard let httpResp = urlResponse as? HTTPURLResponse else {
            debugLog("req=\(resolvedId) status=nil timing=\(ms)ms -> error:network")
            throw LLMError.network
        }
        let status = httpResp.statusCode

        // Non-200 → classified error.
        guard status == 200 else {
            let err = mapHTTPError(status: status, headers: httpResp, body: data)
            debugLog("req=\(resolvedId) status=\(status) timing=\(ms)ms -> error:\(errorBucket(err))\(errorReason(status: status, body: data))")
            throw err
        }

        // Parse OpenAI envelope to extract rawText.
        // rawText is returned verbatim — client does not validate its JSON content.
        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first   = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            debugLog("req=\(resolvedId) status=\(status) timing=\(ms)ms -> error:decodeInvalidJSON")
            throw LLMError.decodeInvalidJSON
        }

        debugLog("req=\(resolvedId) status=\(status) timing=\(ms)ms")

        let usage = json["usage"] as? [String: Any]
        let promptTokens    = usage?["prompt_tokens"]     as? Int
        let completionTokens = usage?["completion_tokens"] as? Int
        let totalTokens     = usage?["total_tokens"]      as? Int

        return LLMRawResponse(
            rawText: content,
            requestId: resolvedId,
            attempt: 1,
            timingMs: ms,
            httpStatus: status,
            transport: .openAI,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens
        )
    }

    // MARK: - Message serialization

    /// Builds the messages array for the OpenAI API body.
    ///
    /// Text-only: each message is serialized as `{"role": "...", "content": "string"}`.
    ///
    /// Multimodal: the last user message is replaced with an array content block:
    /// `[{"type":"text","text":"..."},{"type":"image_url","image_url":{"url":"data:...;base64,..."}}]`
    /// All preceding messages keep string content (system messages cannot carry images).
    private func buildMessagePayload(from request: LLMClientRequest) -> [[String: Any]] {
        guard let image = request.image else {
            return request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        }

        let base64 = image.data.base64EncodedString()
        let dataURL = "data:\(image.mimeType);base64,\(base64)"

        return request.messages.enumerated().map { index, msg in
            // Attach image only to the last message (always the user turn in our layout).
            guard index == request.messages.count - 1 else {
                return ["role": msg.role.rawValue, "content": msg.content]
            }
            let contentItems: [[String: Any]] = [
                ["type": "text", "text": msg.content],
                ["type": "image_url", "image_url": ["url": dataURL]]
            ]
            return ["role": msg.role.rawValue, "content": contentItems]
        }
    }

    // MARK: - Private helpers

    private func elapsed(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    private func mapHTTPError(status: Int, headers: HTTPURLResponse, body: Data) -> LLMError {
        switch status {
        case 429:
            let retryAfter = headers.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            return .rateLimited(retryAfterSec: retryAfter)
        case 401, 403:
            return .auth
        case 400..<500:
            return .badRequest
        default: // 500–599 and unexpected
            return .server
        }
    }

    private func errorBucket(_ error: LLMError) -> String {
        switch error {
        case .rateLimited: return "rateLimited"
        case .auth:        return "auth"
        case .badRequest:  return "badRequest"
        case .server:      return "server"
        default:           return "network"
        }
    }

    /// Extracts a short, safe reason string from the OpenAI error envelope.
    /// Only runs in DEBUG. Never logs prompts, recipe text, or keys.
    private func errorReason(status: Int, body: Data) -> String {
#if DEBUG
        guard !body.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let errObj = json["error"] as? [String: Any]
        else { return "" }
        let type_  = errObj["type"]    as? String ?? ""
        let code   = errObj["code"]    as? String ?? ""
        let rawMsg = errObj["message"] as? String ?? ""
        let msg    = rawMsg.count > 120 ? String(rawMsg.prefix(120)) + "…" : rawMsg
        let parts  = [type_, code, msg].filter { !$0.isEmpty }
        return parts.isEmpty ? "" : " (\(parts.joined(separator: " | ")))"
#else
        return ""
#endif
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[OpenAIClient] \(message)")
#endif
    }
}

// MARK: - StreamingLLMClient (M18)

extension OpenAIClient: StreamingLLMClient {

    /// Calls the OpenAI streaming completions API and yields raw content delta tokens
    /// as they arrive via Server-Sent Events. The stream finishes when `[DONE]` is
    /// received or when the Task is cancelled.
    func stream(_ request: LLMClientRequest) -> AsyncThrowingStream<String, Error> {
        let capturedKey = apiKey
        let capturedSession = streamSession
        let capturedRequest = request

        return AsyncThrowingStream { continuation in
            let task = Task {
                guard let key = capturedKey, !key.isEmpty else {
                    continuation.finish(throwing: LLMError.missingAPIKey)
                    return
                }

                var urlRequest = URLRequest(url: Self.endpoint)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.timeoutInterval = capturedRequest.timeout

                var body: [String: Any] = [
                    "model": capturedRequest.model,
                    "messages": Self.buildStreamMessagePayload(from: capturedRequest),
                    "stream": true
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

                    let status = httpResp.statusCode
                    guard status == 200 else {
                        let err = Self.mapStreamHTTPError(status: status)
                        continuation.finish(throwing: err)
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

    // MARK: - Static helpers for streaming path

    /// Builds the messages array for the streaming request body.
    /// Streaming does not support multimodal (per M18 scope), so images are omitted.
    private static func buildStreamMessagePayload(from request: LLMClientRequest) -> [[String: Any]] {
        request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
    }

    private static func mapStreamHTTPError(status: Int) -> LLMError {
        switch status {
        case 429:       return .rateLimited(retryAfterSec: nil)
        case 401, 403:  return .auth
        case 400..<500: return .badRequest
        default:        return .server
        }
    }
}

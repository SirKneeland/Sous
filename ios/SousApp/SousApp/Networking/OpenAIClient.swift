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

    init(apiKey: String?, session: any URLSessionProtocol = URLSession.shared) {
        self.apiKey = apiKey
        self.session = session
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
            "messages": request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
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

import XCTest
@testable import SousApp
import SousCore

// MARK: - MockURLSession

/// Test double for URLSessionProtocol. Records call count; never hits the network.
private final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    private(set) var callCount = 0
    private let result: Result<(Data, URLResponse), Error>

    init(result: Result<(Data, URLResponse), Error>) {
        self.result = result
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        return try result.get()
    }
}

// MARK: - Helpers

private func makeHTTPResponse(status: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://api.openai.com/v1/chat/completions")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers
    )!
}

/// Valid OpenAI chat completions envelope wrapping the given content string.
private func makeEnvelope(content: String) -> Data {
    let json: [String: Any] = [
        "choices": [
            ["message": ["content": content, "role": "assistant"]]
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: json)
}

private func makeRequest(model: String = "gpt-4o-mini", requestId: String = "test-req-1") -> LLMClientRequest {
    LLMClientRequest(
        requestId: requestId,
        model: model,
        messages: [LLMMessage(role: .user, content: "Hello")],
        responseFormat: .jsonObject,
        timeout: 30
    )
}

// MARK: - OpenAIClientTests

final class OpenAIClientTests: XCTestCase {

    // MARK: API key guards (no network)

    func testMissingAPIKey_throwsMissingAPIKey_andNoNetworkCall() async throws {
        let mock = MockURLSession(result: .failure(URLError(.badServerResponse)))
        let client = OpenAIClient(apiKey: nil, session: mock)

        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.missingAPIKey")
        } catch LLMError.missingAPIKey {
            XCTAssertEqual(mock.callCount, 0, "Session must not be called when API key is absent")
        }
    }

    func testEmptyAPIKey_throwsMissingAPIKey_andNoNetworkCall() async throws {
        let mock = MockURLSession(result: .failure(URLError(.badServerResponse)))
        let client = OpenAIClient(apiKey: "", session: mock)

        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.missingAPIKey")
        } catch LLMError.missingAPIKey {
            XCTAssertEqual(mock.callCount, 0, "Session must not be called when API key is empty")
        }
    }

    // MARK: HTTP error status → classified LLMError

    func testHTTP429_throwsRateLimited() async throws {
        let mock = MockURLSession(result: .success((Data(), makeHTTPResponse(status: 429))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)
        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.rateLimited")
        } catch LLMError.rateLimited {
            // Pass
        }
    }

    func testHTTP429_withRetryAfterHeader_parsesSeconds() async throws {
        let resp = makeHTTPResponse(status: 429, headers: ["Retry-After": "30"])
        let mock = MockURLSession(result: .success((Data(), resp)))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)
        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.rateLimited")
        } catch LLMError.rateLimited(let sec) {
            XCTAssertEqual(sec, 30)
        }
    }

    func testHTTP401_throwsAuth() async throws {
        let mock = MockURLSession(result: .success((Data(), makeHTTPResponse(status: 401))))
        let client = OpenAIClient(apiKey: "sk-bad-key", session: mock)
        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.auth")
        } catch LLMError.auth {
            // Pass
        }
    }

    func testHTTP403_throwsAuth() async throws {
        let mock = MockURLSession(result: .success((Data(), makeHTTPResponse(status: 403))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)
        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.auth")
        } catch LLMError.auth {
            // Pass
        }
    }

    func testHTTP400_throwsBadRequest() async throws {
        let mock = MockURLSession(result: .success((Data(), makeHTTPResponse(status: 400))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)
        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.badRequest")
        } catch LLMError.badRequest {
            // Pass
        }
    }

    func testHTTP500_throwsServer() async throws {
        let mock = MockURLSession(result: .success((Data(), makeHTTPResponse(status: 500))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)
        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.server")
        } catch LLMError.server {
            // Pass
        }
    }

    // MARK: URLError → mapped LLMError buckets

    func testURLErrorTimedOut_throwsTimeout() async throws {
        let mock = MockURLSession(result: .failure(URLError(.timedOut)))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)

        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.timeout")
        } catch LLMError.timeout {
            // Pass
        }
    }

    func testURLErrorCancelled_throwsCancelled() async throws {
        let mock = MockURLSession(result: .failure(URLError(.cancelled)))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)

        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.cancelled")
        } catch LLMError.cancelled {
            // Pass
        }
    }

    func testURLErrorNetworkConnectionLost_throwsNetwork() async throws {
        let mock = MockURLSession(result: .failure(URLError(.networkConnectionLost)))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)

        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.network")
        } catch LLMError.network {
            // Pass
        }
    }

    // MARK: HTTP 200 envelope parsing

    func testHTTP200_malformedEnvelopeJSON_throwsDecodeInvalidJSON() async throws {
        let badData = "not json at all".data(using: .utf8)!
        let mock = MockURLSession(result: .success((badData, makeHTTPResponse(status: 200))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)

        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.decodeInvalidJSON")
        } catch LLMError.decodeInvalidJSON {
            // Pass
        }
    }

    func testHTTP200_missingChoices_throwsDecodeInvalidJSON() async throws {
        let noChoices = try! JSONSerialization.data(withJSONObject: ["id": "chatcmpl-xyz"])
        let mock = MockURLSession(result: .success((noChoices, makeHTTPResponse(status: 200))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)

        do {
            _ = try await client.send(makeRequest())
            XCTFail("Expected LLMError.decodeInvalidJSON")
        } catch LLMError.decodeInvalidJSON {
            // Pass
        }
    }

    /// rawText may be non-JSON — client returns it verbatim; orchestrator decides validity.
    func testHTTP200_validEnvelopeWithNonJSONContent_returnsRawText() async throws {
        let content = "This is plain text, not JSON at all."
        let mock = MockURLSession(result: .success((makeEnvelope(content: content), makeHTTPResponse(status: 200))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)

        let response = try await client.send(makeRequest())

        XCTAssertEqual(response.rawText, content)
        XCTAssertEqual(response.requestId, "test-req-1")
        XCTAssertEqual(response.httpStatus, 200)
        XCTAssertEqual(response.transport, .openAI)
        XCTAssertEqual(response.attempt, 1)
        XCTAssertGreaterThanOrEqual(response.timingMs, 0)
    }

    func testHTTP200_validEnvelopeWithJSONContent_returnsRawTextVerbatim() async throws {
        let content = #"{"patches":[],"baseRecipeId":"abc","baseRecipeVersion":1}"#
        let mock = MockURLSession(result: .success((makeEnvelope(content: content), makeHTTPResponse(status: 200))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)

        let response = try await client.send(makeRequest())

        XCTAssertEqual(response.rawText, content)
        XCTAssertEqual(response.transport, .openAI)
        XCTAssertEqual(response.httpStatus, 200)
    }

    // MARK: requestId passthrough

    func testCallerSuppliedRequestId_isPreservedInResponse() async throws {
        let content = "ok"
        let mock = MockURLSession(result: .success((makeEnvelope(content: content), makeHTTPResponse(status: 200))))
        let client = OpenAIClient(apiKey: "sk-test", session: mock)

        let response = try await client.send(makeRequest(requestId: "caller-supplied-id"))

        XCTAssertEqual(response.requestId, "caller-supplied-id")
    }
}

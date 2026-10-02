import XCTest
@testable import SousApp
import SousCore

// MARK: - Capturing session

/// Captures the outbound URLRequest so tests can inspect headers + URL.
private final class CapturingSession: URLSessionProtocol, @unchecked Sendable {
    private(set) var captured: URLRequest?
    private let result: Result<(Data, URLResponse), Error>

    init(result: Result<(Data, URLResponse), Error>) { self.result = result }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        captured = request
        return try result.get()
    }
}

private func okEnvelope() -> (Data, URLResponse) {
    let json: [String: Any] = [
        "choices": [["message": ["content": "{\"assistant_message\":\"hi\"}", "role": "assistant"]]],
        "usage": ["prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15],
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    let resp = HTTPURLResponse(
        url: SousBackendConfig.proxyChatURL, statusCode: 200, httpVersion: nil, headerFields: nil
    )!
    return (data, resp)
}

private func request() -> LLMClientRequest {
    LLMClientRequest(
        requestId: "req-1",
        model: "gpt-5.4-mini",
        messages: [LLMMessage(role: .user, content: "How do I bake bread?")],
        responseFormat: .jsonObject,
        timeout: 30
    )
}

final class ProxyOpenAIClientTests: XCTestCase {

    func testSendTargetsProxyURLWithSessionTokenAndHeaders() async throws {
        let session = CapturingSession(result: .success(okEnvelope()))
        let client = ProxyOpenAIClient(
            sessionToken: "session-abc",
            isNewRecipe: true,
            recipeId: "recipe-42",
            session: session
        )

        _ = try await client.send(request())

        let req = try XCTUnwrap(session.captured)
        // Routes to the Sous proxy, NOT api.openai.com.
        XCTAssertEqual(req.url, SousBackendConfig.proxyChatURL)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer session-abc")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Sous-Is-New-Recipe"), "true")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Sous-Recipe-Id"), "recipe-42")
    }

    func testSendSetsNewRecipeHeaderFalseWhenNotNewRecipe() async throws {
        let session = CapturingSession(result: .success(okEnvelope()))
        let client = ProxyOpenAIClient(sessionToken: "tok", isNewRecipe: false, session: session)

        _ = try await client.send(request())

        let req = try XCTUnwrap(session.captured)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Sous-Is-New-Recipe"), "false")
        // No recipe id supplied → header omitted.
        XCTAssertNil(req.value(forHTTPHeaderField: "X-Sous-Recipe-Id"))
    }

    func testSendParsesRelayedOpenAIEnvelope() async throws {
        let session = CapturingSession(result: .success(okEnvelope()))
        let client = ProxyOpenAIClient(sessionToken: "tok", isNewRecipe: false, session: session)

        let raw = try await client.send(request())
        XCTAssertEqual(raw.rawText, "{\"assistant_message\":\"hi\"}")
        XCTAssertEqual(raw.promptTokens, 10)
        XCTAssertEqual(raw.completionTokens, 5)
    }

    func testEmptyTokenThrowsAuthBeforeNetwork() async {
        let session = CapturingSession(result: .success(okEnvelope()))
        let client = ProxyOpenAIClient(sessionToken: "", isNewRecipe: false, session: session)
        do {
            _ = try await client.send(request())
            XCTFail("expected auth error")
        } catch {
            XCTAssertEqual(error as? LLMError, .auth)
            XCTAssertNil(session.captured, "must not touch the network without a token")
        }
    }

    // MARK: - Milestone 30: product-meaningful 4xx codes

    /// Builds a non-200 proxy response with the given status and JSON body.
    private func errorResponse(status: Int, body: [String: Any]) -> (Data, URLResponse) {
        let data = try! JSONSerialization.data(withJSONObject: body)
        let resp = HTTPURLResponse(
            url: SousBackendConfig.proxyChatURL, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (data, resp)
    }

    private func sendExpectingError(status: Int, body: [String: Any]) async -> LLMError? {
        let session = CapturingSession(result: .success(errorResponse(status: status, body: body)))
        let client = ProxyOpenAIClient(sessionToken: "tok", isNewRecipe: false, session: session)
        do {
            _ = try await client.send(request())
            return nil
        } catch let error as LLMError {
            return error
        } catch {
            return nil
        }
    }

    func testCapReachedIsNotCollapsedIntoBadRequest() async {
        let error = await sendExpectingError(status: 402, body: ["error": "cap_reached"])
        XCTAssertEqual(error, .capReached,
                       "A 402 must stay distinguishable so the UI never offers a retry into the same wall")
    }

    func testOffTopicCarriesTheBackendCopy() async {
        let error = await sendExpectingError(
            status: 400,
            body: ["error": "off_topic", "message": "Let's keep it in the kitchen."]
        )
        XCTAssertEqual(error, .offTopic(message: "Let's keep it in the kitchen."))
    }

    func testOtherBadRequestsStayBadRequest() async {
        let error = await sendExpectingError(status: 400, body: ["error": "malformed"])
        XCTAssertEqual(error, .badRequest)
    }
}

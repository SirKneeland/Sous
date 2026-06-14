import XCTest
@testable import SousApp

@MainActor
final class SousAPIClientTests: XCTestCase {

    private let baseURL = URL(string: "https://test.local/api/v1")!

    private func makeClient(
        token: String? = "tok",
        transport: FakeTransport
    ) -> (SousAPIClient, InMemorySessionProvider) {
        let session = InMemorySessionProvider(token: token)
        let client = SousAPIClient(baseURL: baseURL, session: session, transport: transport)
        return (client, session)
    }

    private func body(_ request: URLRequest) -> [String: Any] {
        guard let data = request.httpBody,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    // MARK: signInWithApple

    func test_signInWithApple_postsUnauthenticatedWithBody() async throws {
        let transport = FakeTransport()
        transport.responder = { _ in
            let json = """
            {"token":"t","userId":"u","entitlement":{"status":"trialing","reason":null,"hasAccess":true},"profile":null,"config":null}
            """
            return (200, Data(json.utf8))
        }
        let (client, _) = makeClient(transport: transport)

        let response = try await client.signInWithApple(identityToken: "apple-id-token", referralCode: "SOUS-XYZ")

        XCTAssertEqual(response.token, "t")
        let req = transport.lastRequest!
        XCTAssertEqual(req.url?.absoluteString, "https://test.local/api/v1/auth/apple")
        XCTAssertEqual(req.httpMethod, "POST")
        // Unauthenticated: no bearer header.
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
        let b = body(req)
        XCTAssertEqual(b["identityToken"] as? String, "apple-id-token")
        XCTAssertEqual(b["referralCode"] as? String, "SOUS-XYZ")
    }

    // MARK: authenticated header

    func test_authenticatedRequest_attachesBearerToken() async throws {
        let transport = FakeTransport()
        transport.responder = { _ in (200, Data("{\"ok\":true}".utf8)) }
        let (client, _) = makeClient(token: "secret-token", transport: transport)

        try await client.signOut()

        let req = transport.lastRequest!
        XCTAssertEqual(req.url?.absoluteString, "https://test.local/api/v1/auth/signout")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
    }

    func test_authenticatedRequest_withoutToken_throwsNotAuthenticated() async {
        let transport = FakeTransport()
        let (client, _) = makeClient(token: nil, transport: transport)

        do {
            try await client.signOut()
            XCTFail("expected notAuthenticated")
        } catch {
            XCTAssertEqual(error as? SousAPIError, .notAuthenticated)
        }
    }

    // MARK: 401 handling

    func test_401_clearsSessionAndFiresOnUnauthorized() async {
        let transport = FakeTransport()
        transport.responder = { _ in (401, Data("{\"error\":\"unauthorized\"}".utf8)) }
        let (client, session) = makeClient(token: "tok", transport: transport)
        var unauthorizedFired = false
        client.onUnauthorized = { unauthorizedFired = true }

        do {
            _ = try await client.fetchSubscriptionStatus()
            XCTFail("expected unauthorized")
        } catch {
            XCTAssertEqual(error as? SousAPIError, .unauthorized)
        }
        XCTAssertNil(session.load(), "token should be cleared on 401")
        XCTAssertTrue(unauthorizedFired)
    }

    // MARK: deleteAccount

    func test_deleteAccount_usesDeleteMethod() async throws {
        let transport = FakeTransport()
        transport.responder = { _ in (200, Data("{\"ok\":true}".utf8)) }
        let (client, _) = makeClient(transport: transport)

        try await client.deleteAccount()

        let req = transport.lastRequest!
        XCTAssertEqual(req.httpMethod, "DELETE")
        XCTAssertEqual(req.url?.absoluteString, "https://test.local/api/v1/auth/account")
    }

    // MARK: preferences sync

    func test_syncPreferences_putsServerOwnedFields() async throws {
        let transport = FakeTransport()
        transport.responder = { _ in (200, Data("{}".utf8)) }
        let (client, _) = makeClient(transport: transport)
        var prefs = UserPreferences()
        prefs.hardAvoids = ["cilantro"]
        prefs.servingSize = 4
        prefs.equipment = ["wok"]
        prefs.customInstructions = "no microwave"
        prefs.personalityMode = "unhinged"

        try await client.syncPreferences(prefs)

        let req = transport.lastRequest!
        XCTAssertEqual(req.httpMethod, "PUT")
        XCTAssertEqual(req.url?.absoluteString, "https://test.local/api/v1/sync/preferences")
        let b = body(req)
        XCTAssertEqual(b["hardAvoids"] as? [String], ["cilantro"])
        XCTAssertEqual(b["servingSize"] as? Int, 4)
        XCTAssertEqual(b["equipment"] as? [String], ["wok"])
        XCTAssertEqual(b["customInstructions"] as? String, "no microwave")
        XCTAssertEqual(b["personalityMode"] as? String, "unhinged")
    }

    func test_fetchPreferences_decodesEnvelopeAndPreservesLocalOnlyDefaults() async throws {
        let transport = FakeTransport()
        transport.responder = { _ in
            let json = """
            {"preferences":{"hardAvoids":["nuts"],"servingSize":2,"equipment":[],"customInstructions":null,"personalityMode":"playful"}}
            """
            return (200, Data(json.utf8))
        }
        let (client, _) = makeClient(transport: transport)

        let prefs = try await client.fetchPreferences()

        XCTAssertEqual(prefs.hardAvoids, ["nuts"])
        XCTAssertEqual(prefs.servingSize, 2)
        XCTAssertEqual(prefs.personalityMode, "playful")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")
    }

    // MARK: memories sync

    func test_syncMemories_putsMemoryList() async throws {
        let transport = FakeTransport()
        transport.responder = { _ in (200, Data("{}".utf8)) }
        let (client, _) = makeClient(transport: transport)
        let memories = [
            MemoryItem(text: "hates cilantro"),
            MemoryItem(text: "cooking for two kids"),
        ]

        try await client.syncMemories(memories)

        let req = transport.lastRequest!
        XCTAssertEqual(req.httpMethod, "PUT")
        XCTAssertEqual(req.url?.absoluteString, "https://test.local/api/v1/sync/memories")
        let b = body(req)
        let list = b["memories"] as? [[String: Any]]
        XCTAssertEqual(list?.count, 2)
        XCTAssertEqual(list?.first?["text"] as? String, "hates cilantro")
        XCTAssertNotNil(list?.first?["id"] as? String)
    }

    func test_fetchMemories_decodesAndPreservesIds() async throws {
        let id = UUID()
        let transport = FakeTransport()
        transport.responder = { _ in
            let json = """
            {"memories":[{"id":"\(id.uuidString)","text":"prefers metric","createdAt":"2026-01-01T00:00:00.000Z"}]}
            """
            return (200, Data(json.utf8))
        }
        let (client, _) = makeClient(transport: transport)

        let memories = try await client.fetchMemories()

        XCTAssertEqual(memories.count, 1)
        XCTAssertEqual(memories.first?.id, id)
        XCTAssertEqual(memories.first?.text, "prefers metric")
    }

    // MARK: profile

    func test_updateDisplayName_putsProfileBody() async throws {
        let transport = FakeTransport()
        transport.responder = { _ in (200, Data("{\"displayName\":\"Chef John\"}".utf8)) }
        let (client, _) = makeClient(transport: transport)

        try await client.updateDisplayName("Chef John")

        let req = transport.lastRequest!
        XCTAssertEqual(req.httpMethod, "PUT")
        XCTAssertEqual(req.url?.absoluteString, "https://test.local/api/v1/sync/profile")
        XCTAssertEqual(body(req)["displayName"] as? String, "Chef John")
    }

    // MARK: non-2xx

    func test_non2xx_throwsHttpError() async {
        let transport = FakeTransport()
        transport.responder = { _ in (500, Data("{}".utf8)) }
        let (client, _) = makeClient(transport: transport)

        do {
            _ = try await client.fetchSubscriptionStatus()
            XCTFail("expected http error")
        } catch {
            XCTAssertEqual(error as? SousAPIError, .http(status: 500))
        }
    }
}

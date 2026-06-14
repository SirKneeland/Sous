import XCTest
import Security
@testable import SousApp

@MainActor
final class SousSessionProviderTests: XCTestCase {

    private func makeProvider() -> (MockKeychainClient, KeychainSousSessionProvider) {
        let mock = MockKeychainClient()
        return (mock, KeychainSousSessionProvider(client: mock))
    }

    func testLoadReturnsNilWhenUnset() async {
        let (_, provider) = makeProvider()
        XCTAssertNil(provider.load())
    }

    func testSaveAndLoadRoundtrip() async {
        let (_, provider) = makeProvider()
        provider.save(token: "session-abc-123")
        XCTAssertEqual(provider.load(), "session-abc-123")
    }

    func testClearRemovesToken() async {
        let (_, provider) = makeProvider()
        provider.save(token: "session-abc-123")
        provider.clear()
        XCTAssertNil(provider.load())
    }

    func testSaveOverwritesPreviousToken() async {
        let (_, provider) = makeProvider()
        provider.save(token: "first")
        provider.save(token: "second")
        XCTAssertEqual(provider.load(), "second")
    }

    func testSaveEmptyTokenIsIgnored() async {
        let (_, provider) = makeProvider()
        provider.save(token: "")
        XCTAssertNil(provider.load())
    }

    func testUsesDistinctKeychainAccountFromOpenAIKey() async {
        let (mock, provider) = makeProvider()
        provider.save(token: "session-token")
        guard let q = mock.lastAddQuery else { XCTFail("add not called"); return }
        XCTAssertEqual(q[kSecAttrService] as? String, "com.donutindustries.sous")
        // Must differ from the OpenAI key account so the two credentials never collide.
        XCTAssertEqual(q[kSecAttrAccount] as? String, "sous_session_token")
    }
}

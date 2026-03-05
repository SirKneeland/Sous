import XCTest
import Security
@testable import SousApp

// MARK: - MockKeychainClient

/// In-memory KeychainClient for unit tests.
/// Uses NSDictionary for key extraction to get CFString value-equality (not identity).
/// Returns errSecParam and records the query if kSecAttrService or kSecAttrAccount is missing.
final class MockKeychainClient: KeychainClient {

    // Recorded queries for assertion in tests.
    private(set) var lastAddQuery:    [CFString: Any]? = nil
    private(set) var lastFetchQuery:  [CFString: Any]? = nil
    private(set) var lastDeleteQuery: [CFString: Any]? = nil

    /// In-memory store keyed by "service|account".
    private var store: [String: Data] = [:]

    /// Extracts service and account from query using NSDictionary (value-equality lookup).
    /// Returns nil if either key is absent — callers must handle errSecParam.
    private func storeKey(from query: [CFString: Any]) -> String? {
        let d = NSDictionary(dictionary: query as [AnyHashable: Any])
        guard let service = d[kSecAttrService] as? String,
              let account = d[kSecAttrAccount] as? String
        else { return nil }
        return "\(service)|\(account)"
    }

    func add(_ query: [CFString: Any]) -> OSStatus {
        lastAddQuery = query
        guard let k = storeKey(from: query) else { return errSecParam }
        guard let data = NSDictionary(dictionary: query as [AnyHashable: Any])[kSecValueData] as? Data
        else { return errSecParam }
        if store[k] != nil { return errSecDuplicateItem }
        store[k] = data
        return errSecSuccess
    }

    func fetch(_ query: [CFString: Any]) -> (OSStatus, AnyObject?) {
        lastFetchQuery = query
        guard let k = storeKey(from: query) else { return (errSecParam, nil) }
        guard let data = store[k] else { return (errSecItemNotFound, nil) }
        return (errSecSuccess, data as AnyObject)
    }

    func delete(_ query: [CFString: Any]) -> OSStatus {
        lastDeleteQuery = query
        guard let k = storeKey(from: query) else { return errSecParam }
        return store.removeValue(forKey: k) != nil ? errSecSuccess : errSecItemNotFound
    }
}

// MARK: - OpenAIKeyProviderTests

@MainActor
final class OpenAIKeyProviderTests: XCTestCase {

    private func makeMockAndProvider() -> (MockKeychainClient, KeychainOpenAIKeyProvider) {
        let mock = MockKeychainClient()
        return (mock, KeychainOpenAIKeyProvider(client: mock))
    }

    // MARK: Behavioral tests

    func testCurrentKeyReturnsNilWhenUnset() async {
        let (_, provider) = makeMockAndProvider()
        XCTAssertNil(provider.currentKey())
    }

    func testSetAndGetRoundtrip() async {
        let (_, provider) = makeMockAndProvider()
        provider.setKey("sk-test-abc123")
        XCTAssertEqual(provider.currentKey(), "sk-test-abc123")
    }

    func testClearRemovesKey() async {
        let (_, provider) = makeMockAndProvider()
        provider.setKey("sk-test-abc123")
        provider.clearKey()
        XCTAssertNil(provider.currentKey())
    }

    func testSetKeyOverwritesPreviousValue() async {
        let (_, provider) = makeMockAndProvider()
        provider.setKey("sk-first")
        provider.setKey("sk-second")
        XCTAssertEqual(provider.currentKey(), "sk-second")
    }

    func testClearWhenAlreadyAbsentDoesNotCrash() async {
        let (_, provider) = makeMockAndProvider()
        provider.clearKey()
        XCTAssertNil(provider.currentKey())
    }

    func testSetEmptyKeyIsIgnored() async {
        let (_, provider) = makeMockAndProvider()
        provider.setKey("")
        XCTAssertNil(provider.currentKey())
    }

    // MARK: Query construction tests

    func testSetKeyUsesCorrectServiceAndAccount() async {
        let (mock, provider) = makeMockAndProvider()
        provider.setKey("sk-query-check")

        guard let q = mock.lastAddQuery else { XCTFail("add was not called"); return }
        XCTAssertEqual(q[kSecAttrService] as? String, "com.donutindustries.sous")
        XCTAssertEqual(q[kSecAttrAccount] as? String, "openai_api_key")
    }

    func testFetchQueryUsesCorrectServiceAndAccount() async {
        let (mock, provider) = makeMockAndProvider()
        _ = provider.currentKey()

        guard let q = mock.lastFetchQuery else { XCTFail("fetch was not called"); return }
        XCTAssertEqual(q[kSecAttrService] as? String, "com.donutindustries.sous")
        XCTAssertEqual(q[kSecAttrAccount] as? String, "openai_api_key")
    }

    func testClearKeyUsesCorrectServiceAndAccount() async {
        let (mock, provider) = makeMockAndProvider()
        provider.clearKey()

        guard let q = mock.lastDeleteQuery else { XCTFail("delete was not called"); return }
        XCTAssertEqual(q[kSecAttrService] as? String, "com.donutindustries.sous")
        XCTAssertEqual(q[kSecAttrAccount] as? String, "openai_api_key")
    }
}

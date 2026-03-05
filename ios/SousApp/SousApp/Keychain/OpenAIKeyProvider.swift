import Foundation
import Security

// MARK: - KeychainClient

/// Abstraction over SecItem* functions using Swift-native query dictionaries,
/// enabling unit tests to inject an in-memory fake without CFDictionary bridging.
protocol KeychainClient {
    func add(_ query: [CFString: Any]) -> OSStatus
    func fetch(_ query: [CFString: Any]) -> (OSStatus, AnyObject?)
    func delete(_ query: [CFString: Any]) -> OSStatus
}

// MARK: - SystemKeychainClient

/// Production implementation that bridges to the real Security framework.
struct SystemKeychainClient: KeychainClient {
    func add(_ query: [CFString: Any]) -> OSStatus {
        SecItemAdd(query as CFDictionary, nil)
    }

    func fetch(_ query: [CFString: Any]) -> (OSStatus, AnyObject?) {
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result)
    }

    func delete(_ query: [CFString: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - OpenAIKeyProviding

protocol OpenAIKeyProviding {
    func currentKey() -> String?
    func setKey(_ key: String)
    func clearKey()
}

// MARK: - KeychainOpenAIKeyProvider

/// Stores the OpenAI API key in Keychain using kSecClassGenericPassword.
/// All operations are best-effort: failures are silently swallowed, never logged.
/// The key value is never printed or included in any log output.
final class KeychainOpenAIKeyProvider: OpenAIKeyProviding {

    private static let service = "com.donutindustries.sous"
    private static let account = "openai_api_key"

    private let client: any KeychainClient

    init(client: any KeychainClient = SystemKeychainClient()) {
        self.client = client
    }

    func currentKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        let (status, result) = client.fetch(query)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    func setKey(_ key: String) {
        guard !key.isEmpty, let data = key.data(using: .utf8) else { return }

        // Delete any existing entry first (no-op if absent), then add fresh.
        // All calls go through the injected client for full testability.
        let deleteQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
        ]
        _ = client.delete(deleteQuery)

        let addQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecValueData:   data,
        ]
        _ = client.add(addQuery)
    }

    func clearKey() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
        ]
        _ = client.delete(query)
    }
}

import Foundation
import Security

// MARK: - SousSessionProviding

/// Stores the Sous backend session token. Separate from the OpenAI key so the two
/// credentials never collide and can be cleared independently.
protocol SousSessionProviding {
    func load() -> String?
    func save(token: String)
    func clear()
}

// MARK: - KeychainSousSessionProvider

/// Keychain-backed session token store, mirroring `KeychainOpenAIKeyProvider`.
/// All operations are best-effort; failures are silently swallowed and the token
/// value is never printed or logged.
final class KeychainSousSessionProvider: SousSessionProviding {

    private static let service = "com.donutindustries.sous"
    private static let account = "sous_session_token"

    private let client: any KeychainClient

    init(client: any KeychainClient = SystemKeychainClient()) {
        self.client = client
    }

    func load() -> String? {
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
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty
        else { return nil }
        return token
    }

    func save(token: String) {
        guard !token.isEmpty, let data = token.data(using: .utf8) else { return }

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

    func clear() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
        ]
        _ = client.delete(query)
    }
}

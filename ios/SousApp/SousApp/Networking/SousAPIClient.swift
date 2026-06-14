import Foundation

// MARK: - Backend configuration

/// Resolves the Sous backend base URL. The real deployed URL is supplied via the
/// app's Info.plist key `SousBackendBaseURL` (set per build configuration); the
/// fallback is the production Railway host. Never hardcode the URL at call sites —
/// always read it from here.
enum SousBackendConfig {
    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "SousBackendBaseURL") as? String,
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        // TODO(operator): confirm/replace with the live Railway URL via Info.plist.
        return URL(string: "https://sous-production.up.railway.app")!
    }

    /// All API routes are prefixed `/api/v1`.
    static var apiBaseURL: URL { baseURL.appendingPathComponent("api/v1") }

    /// The OpenAI chat-completions proxy endpoint. Non-BYOK users' LLM calls go
    /// here instead of directly to OpenAI (see `ProxyOpenAIClient`).
    static var proxyChatURL: URL { apiBaseURL.appendingPathComponent("proxy/chat") }
}

// MARK: - HTTP transport (injectable for tests)

/// The minimal surface of URLSession the client uses. Tests inject a fake to
/// capture the constructed request and return canned responses.
protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPTransport {}

// MARK: - Errors

enum SousAPIError: Error, Equatable {
    /// 401 — the session token was rejected. The client has already cleared it.
    case unauthorized
    /// Non-2xx (other than 401).
    case http(status: Int)
    /// Transport produced a non-HTTP response.
    case invalidResponse
    /// Response body could not be decoded.
    case decoding
    /// No session token is stored, so an authenticated call cannot be made.
    case notAuthenticated
}

// MARK: - Backend protocols

/// Auth + status surface used by `AuthState`.
protocol SousAuthBackend: AnyObject {
    func signInWithApple(identityToken: String, referralCode: String?) async throws -> AuthResponse
    func signOut() async throws
    func deleteAccount() async throws
    func fetchConfig() async throws -> AppConfig
    func fetchSubscriptionStatus() async throws -> SubscriptionStatus
}

/// Preferences/memories/profile sync surface used by `AppStore`.
protocol SousSyncBackend: AnyObject {
    func syncPreferences(_ prefs: UserPreferences) async throws
    func fetchPreferences() async throws -> UserPreferences
    func syncMemories(_ memories: [MemoryItem]) async throws
    func fetchMemories() async throws -> [MemoryItem]
    func updateDisplayName(_ displayName: String?) async throws
    /// Current billing-period usage for the Account screen.
    func fetchUsageSummary() async throws -> UsageSummary
    /// Record a new recipe for users who bypass the proxy (BYOK telemetry).
    func recordRecipeUsage() async throws
}

/// The full backend surface. `SousAPIClient` is the single concrete implementation.
typealias SousBackend = SousAuthBackend & SousSyncBackend

// MARK: - SousAPIClient

/// All communication with the Sous backend. Distinct from `OpenAIClient`, which
/// makes direct OpenAI calls for BYOK users. Attaches the Sous session token to
/// every authenticated request and clears the session on a 401.
@MainActor
final class SousAPIClient: SousBackend {

    /// Shared instance used by the live app. Tests construct their own.
    static let shared = SousAPIClient()

    private let baseURL: URL
    private let session: any SousSessionProviding
    private let transport: any HTTPTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Invoked once when any authenticated call is rejected with 401, after the
    /// stored token has been cleared. `AuthState` wires this to sign the user out.
    var onUnauthorized: (() -> Void)?

    init(
        baseURL: URL = SousBackendConfig.apiBaseURL,
        session: any SousSessionProviding = KeychainSousSessionProvider(),
        transport: any HTTPTransport = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.transport = transport
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: Auth

    func signInWithApple(identityToken: String, referralCode: String?) async throws -> AuthResponse {
        let body = AppleSignInBody(identityToken: identityToken, referralCode: referralCode)
        // Unauthenticated: no token yet.
        let data = try await send(path: "auth/apple", method: "POST", body: body, authenticated: false)
        return try decode(AuthResponse.self, from: data)
    }

    func signOut() async throws {
        _ = try await send(path: "auth/signout", method: "POST", body: Optional<Empty>.none, authenticated: true)
    }

    func deleteAccount() async throws {
        _ = try await send(path: "auth/account", method: "DELETE", body: Optional<Empty>.none, authenticated: true)
    }

    func fetchConfig() async throws -> AppConfig {
        let data = try await send(path: "config", method: "GET", body: Optional<Empty>.none, authenticated: true)
        return try decode(ConfigEnvelope.self, from: data).config
    }

    func fetchSubscriptionStatus() async throws -> SubscriptionStatus {
        let data = try await send(path: "subscription/status", method: "GET", body: Optional<Empty>.none, authenticated: true)
        return try decode(SubscriptionStatus.self, from: data)
    }

    // MARK: Sync — preferences

    func syncPreferences(_ prefs: UserPreferences) async throws {
        let dto = PreferencesDTO(
            hardAvoids: prefs.hardAvoids,
            servingSize: prefs.servingSize,
            equipment: prefs.equipment,
            customInstructions: prefs.customInstructions,
            personalityMode: prefs.personalityMode
        )
        _ = try await send(path: "sync/preferences", method: "PUT", body: dto, authenticated: true)
    }

    func fetchPreferences() async throws -> UserPreferences {
        let data = try await send(path: "sync/preferences", method: "GET", body: Optional<Empty>.none, authenticated: true)
        let dto = try PreferencesDTO.decode(from: data, decoder: decoder)
        // Only the server-owned fields are populated here; voice/unit-system are
        // device-local and merged separately by AppStore.
        var prefs = UserPreferences()
        prefs.hardAvoids = dto.hardAvoids
        prefs.servingSize = dto.servingSize
        prefs.equipment = dto.equipment
        prefs.customInstructions = dto.customInstructions ?? ""
        if let mode = dto.personalityMode { prefs.personalityMode = mode }
        return prefs
    }

    // MARK: Sync — memories

    func syncMemories(_ memories: [MemoryItem]) async throws {
        let dtos = memories.map {
            MemoryDTO(id: $0.id.uuidString, text: $0.text, createdAt: Self.iso8601.string(from: $0.createdAt))
        }
        _ = try await send(path: "sync/memories", method: "PUT", body: MemoriesSyncBody(memories: dtos), authenticated: true)
    }

    func fetchMemories() async throws -> [MemoryItem] {
        let data = try await send(path: "sync/memories", method: "GET", body: Optional<Empty>.none, authenticated: true)
        let dtos = try MemoryDTO.decodeList(from: data, decoder: decoder)
        return dtos.map { dto in
            let id = dto.id.flatMap(UUID.init(uuidString:)) ?? UUID()
            let created = dto.createdAt.flatMap(Self.iso8601.date(from:)) ?? Date()
            let firstPerson = MemoryPersonConverter.naiveToFirstPerson(dto.text)
            return MemoryItem(id: id, text: dto.text, firstPersonText: firstPerson, createdAt: created)
        }
    }

    // MARK: Sync — profile

    func updateDisplayName(_ displayName: String?) async throws {
        _ = try await send(path: "sync/profile", method: "PUT", body: ProfileUpdateBody(displayName: displayName), authenticated: true)
    }

    // MARK: Usage

    func fetchUsageSummary() async throws -> UsageSummary {
        let data = try await send(path: "usage/summary", method: "GET", body: Optional<Empty>.none, authenticated: true)
        return try decode(UsageSummary.self, from: data)
    }

    func recordRecipeUsage() async throws {
        _ = try await send(path: "usage/recipe", method: "POST", body: Optional<Empty>.none, authenticated: true)
    }

    // MARK: - Request plumbing

    /// Build, send, and validate a request. Returns the raw response body.
    /// On 401, clears the stored token and fires `onUnauthorized` before throwing.
    private func send<Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        authenticated: Bool
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            guard let token = session.load() else { throw SousAPIError.notAuthenticated }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else { throw SousAPIError.invalidResponse }

        if http.statusCode == 401 {
            session.clear()
            onUnauthorized?()
            throw SousAPIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SousAPIError.http(status: http.statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SousAPIError.decoding
        }
    }

    /// ISO-8601 with fractional seconds, matching the backend's timestamp format.
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - Private envelopes

/// Placeholder Encodable for bodyless requests.
private struct Empty: Encodable {}

private struct ConfigEnvelope: Decodable { let config: AppConfig }

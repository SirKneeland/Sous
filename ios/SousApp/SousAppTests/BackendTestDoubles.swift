import Foundation
@testable import SousApp

// MARK: - InMemorySessionProvider

/// Session token store backed by a plain variable, for auth/sync tests.
final class InMemorySessionProvider: SousSessionProviding, @unchecked Sendable {
    private var token: String?
    private(set) var clearCount = 0

    init(token: String? = nil) { self.token = token }

    func load() -> String? { token }
    func save(token: String) { self.token = token }
    func clear() { token = nil; clearCount += 1 }
}

// MARK: - FakeTransport

/// Records every request and returns a canned (status, body). Used to verify
/// SousAPIClient request construction and status handling without networking.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    /// Per-request responder. Defaults to 200 with `{}`.
    var responder: ((URLRequest) -> (Int, Data))?

    var lastRequest: URLRequest? { requests.last }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let (status, body) = responder?(request) ?? (200, Data("{}".utf8))
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (body, response)
    }
}

// MARK: - MockBackend

/// Full in-memory `SousBackend` for AuthState and AppStore sync tests.
final class MockBackend: SousBackend, @unchecked Sendable {
    // Auth configuration
    var signInResult: Result<AuthResponse, Error>?
    var subscriptionStatusResult: Result<SubscriptionStatus, Error>?
    var configResult: Result<AppConfig, Error>?
    var signOutError: Error?
    var deleteAccountError: Error?

    // Sync configuration
    var fetchPreferencesResult: Result<UserPreferences, Error>?
    var fetchMemoriesResult: Result<[MemoryItem], Error>?
    var usageSummaryResult: Result<UsageSummary, Error>?

    // Recorded calls
    private(set) var signInCalls: [(token: String, referral: String?)] = []
    private(set) var signOutCallCount = 0
    private(set) var deleteAccountCallCount = 0
    private(set) var syncedPreferences: [UserPreferences] = []
    private(set) var syncedMemories: [[MemoryItem]] = []
    private(set) var updatedDisplayNames: [String?] = []
    private(set) var fetchPreferencesCallCount = 0
    private(set) var fetchMemoriesCallCount = 0
    private(set) var recordRecipeUsageCallCount = 0
    private(set) var fetchUsageSummaryCallCount = 0

    // MARK: SousAuthBackend

    func signInWithApple(identityToken: String, referralCode: String?) async throws -> AuthResponse {
        signInCalls.append((identityToken, referralCode))
        return try unwrap(signInResult)
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError { throw signOutError }
    }

    func deleteAccount() async throws {
        deleteAccountCallCount += 1
        if let deleteAccountError { throw deleteAccountError }
    }

    func fetchConfig() async throws -> AppConfig {
        try unwrap(configResult)
    }

    func fetchSubscriptionStatus() async throws -> SubscriptionStatus {
        try unwrap(subscriptionStatusResult)
    }

    // MARK: SousSyncBackend

    func syncPreferences(_ prefs: UserPreferences) async throws {
        syncedPreferences.append(prefs)
    }

    func fetchPreferences() async throws -> UserPreferences {
        fetchPreferencesCallCount += 1
        return try unwrap(fetchPreferencesResult ?? .success(UserPreferences()))
    }

    func syncMemories(_ memories: [MemoryItem]) async throws {
        syncedMemories.append(memories)
    }

    func fetchMemories() async throws -> [MemoryItem] {
        fetchMemoriesCallCount += 1
        return try unwrap(fetchMemoriesResult ?? .success([]))
    }

    func updateDisplayName(_ displayName: String?) async throws {
        updatedDisplayNames.append(displayName)
    }

    func fetchUsageSummary() async throws -> UsageSummary {
        fetchUsageSummaryCallCount += 1
        return try unwrap(usageSummaryResult)
    }

    func recordRecipeUsage() async throws {
        recordRecipeUsageCallCount += 1
    }

    private func unwrap<T>(_ result: Result<T, Error>?) throws -> T {
        switch result {
        case .success(let value): return value
        case .failure(let error): throw error
        case .none: throw SousAPIError.invalidResponse
        }
    }
}

// MARK: - Builders

enum TestData {
    static func entitlement(_ status: Entitlement) -> EntitlementInfo {
        EntitlementInfo(status: status, reason: nil, hasAccess: true)
    }

    static func profile(
        userId: String = "user-1",
        email: String? = "cook@example.test",
        displayName: String? = nil,
        referralCode: String? = "SOUS-A7X2",
        isByokEligible: Bool? = false
    ) -> UserProfile {
        UserProfile(
            userId: userId, email: email, displayName: displayName,
            referralCode: referralCode, isByokEligible: isByokEligible
        )
    }

    static func authResponse(
        token: String = "session-token",
        userId: String = "user-1",
        entitlement status: Entitlement = .trialing,
        profile: UserProfile? = TestData.profile()
    ) -> AuthResponse {
        AuthResponse(
            token: token,
            userId: userId,
            entitlement: entitlement(status),
            profile: profile,
            config: nil
        )
    }

    static func usageSummary(
        recipesUsed: Int = 12,
        recipeCap: Int = 100,
        entitlement: String = "trialing",
        trialRecipesUsed: Int? = 5,
        trialRecipeCap: Int? = 14,
        trialDaysRemaining: Int? = 9
    ) -> UsageSummary {
        UsageSummary(
            recipesUsed: recipesUsed,
            recipeCap: recipeCap,
            billingPeriod: "2026-06",
            resetsInDays: 18,
            entitlement: entitlement,
            trialRecipesUsed: trialRecipesUsed,
            trialRecipeCap: trialRecipeCap,
            trialDaysRemaining: trialDaysRemaining
        )
    }

    static func subscriptionStatus(
        entitlement status: Entitlement = .trialing,
        profile: UserProfile? = TestData.profile()
    ) -> SubscriptionStatus {
        SubscriptionStatus(
            entitlement: entitlement(status),
            subscription: nil,
            profile: profile
        )
    }
}

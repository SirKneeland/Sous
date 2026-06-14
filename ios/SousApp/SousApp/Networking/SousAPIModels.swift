import Foundation

// MARK: - Entitlement

/// The five server-computed entitlement states. The client treats this as
/// read-only and never computes it locally (see BackendEngineeringPlan.md).
/// Raw values match the backend JSON exactly (note `soft_wall`).
enum Entitlement: String, Codable, Sendable, Equatable {
    case byok
    case subscriber
    case trialing
    case grace
    case softWall = "soft_wall"
}

/// The entitlement envelope returned by `/auth/apple`, `/config`, and
/// `/subscription/status`: `{ status, reason, hasAccess }`.
struct EntitlementInfo: Codable, Sendable, Equatable {
    let status: Entitlement
    let reason: String?
    let hasAccess: Bool?
}

// MARK: - User profile

/// Read-only user profile surfaced for the Account section.
struct UserProfile: Codable, Sendable, Equatable {
    let userId: String?
    let email: String?
    let displayName: String?
    let referralCode: String?
    let isByokEligible: Bool?
}

// MARK: - App config

/// Remotely-configurable values cached at launch. Keys are snake_case on the wire.
struct AppConfig: Codable, Sendable, Equatable {
    let trialDurationDays: Int?
    let trialRecipeCap: Int?
    let paidRecipeCap: Int?
    let byokCutoffEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case trialDurationDays = "trial_duration_days"
        case trialRecipeCap = "trial_recipe_cap"
        case paidRecipeCap = "paid_recipe_cap"
        case byokCutoffEnabled = "byok_cutoff_enabled"
    }
}

// MARK: - Auth response

/// Returned by `POST /auth/apple`.
struct AuthResponse: Codable, Sendable, Equatable {
    let token: String
    let userId: String
    let entitlement: EntitlementInfo
    let profile: UserProfile?
    let config: AppConfig?
}

// MARK: - Subscription status

/// The raw subscription row fields the client cares about. snake_case on the wire.
struct SubscriptionInfo: Codable, Sendable, Equatable {
    let status: String?
    let trialEndsAt: String?
    let trialRecipesUsed: Int?
    let currentPeriodEnd: String?

    enum CodingKeys: String, CodingKey {
        case status
        case trialEndsAt = "trial_ends_at"
        case trialRecipesUsed = "trial_recipes_used"
        case currentPeriodEnd = "current_period_end"
    }
}

/// Returned by `GET /subscription/status`.
struct SubscriptionStatus: Codable, Sendable, Equatable {
    let entitlement: EntitlementInfo
    let subscription: SubscriptionInfo?
    let profile: UserProfile?
}

// MARK: - Usage summary

/// Returned by `GET /usage/summary`. Drives the usage line in Settings. Keys are
/// camelCase on the wire, so the synthesized Codable conformance is sufficient.
struct UsageSummary: Codable, Sendable, Equatable {
    let recipesUsed: Int
    let recipeCap: Int
    let billingPeriod: String
    let resetsInDays: Int
    let entitlement: String
    // Trial users only.
    let trialRecipesUsed: Int?
    let trialRecipeCap: Int?
    let trialDaysRemaining: Int?
}

/// Returned by `POST /usage/recipe` (BYOK telemetry).
struct RecipeUsageResponse: Codable, Sendable, Equatable {
    let recipesUsed: Int
    let billingPeriod: String
}

// MARK: - Sync DTOs

/// Wire shape for the preferences the server owns. The voice/unit-system fields
/// in `UserPreferences` are device-local and intentionally excluded — the merge
/// in AppStore overlays only these server-owned fields.
struct PreferencesDTO: Codable, Sendable, Equatable {
    var hardAvoids: [String]
    var servingSize: Int?
    var equipment: [String]
    var customInstructions: String?
    var personalityMode: String?
}

private struct PreferencesEnvelope: Codable { let preferences: PreferencesDTO }

/// Wire shape for one memory.
struct MemoryDTO: Codable, Sendable, Equatable {
    let id: String?
    let text: String
    let createdAt: String?
}

private struct MemoriesEnvelope: Codable { let memories: [MemoryDTO] }

// MARK: - Request bodies

struct AppleSignInBody: Encodable {
    let identityToken: String
    let referralCode: String?
}

struct MemoriesSyncBody: Encodable {
    let memories: [MemoryDTO]
}

struct ProfileUpdateBody: Encodable {
    let displayName: String?
}

// MARK: - Internal decoding helpers

extension PreferencesDTO {
    /// Decode from the `{ preferences: {...} }` envelope the API returns.
    static func decode(from data: Data, decoder: JSONDecoder) throws -> PreferencesDTO {
        try decoder.decode(PreferencesEnvelope.self, from: data).preferences
    }
}

extension MemoryDTO {
    /// Decode the `{ memories: [...] }` envelope the API returns.
    static func decodeList(from data: Data, decoder: JSONDecoder) throws -> [MemoryDTO] {
        try decoder.decode(MemoriesEnvelope.self, from: data).memories
    }
}

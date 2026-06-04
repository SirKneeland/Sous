import Foundation
import SousCore

// MARK: - UserPreferences

/// Persisted user preferences applied silently to every recipe.
/// Stored as JSON in UserDefaults.
struct UserPreferences: Codable, Equatable, Sendable {
    /// Ingredients or foods to always avoid (hard constraints).
    var hardAvoids: [String] = []
    /// Default number of people to serve. Nil means not set by user.
    var servingSize: Int? = nil
    /// Kitchen tools and equipment available (e.g. cast iron, air fryer).
    var equipment: [String] = []
    /// Free-form instructions applied to every recipe.
    var customInstructions: String = ""
    /// Personality mode controlling AI communication style. Valid values: "minimal", "normal", "playful", "unhinged".
    var personalityMode: String = "normal"
    /// Accent used by the voice assistant. Defaults to the device locale's region.
    var voiceAccent: VoiceAccent = UserPreferences.defaultAccent()
    /// Voice register (Female/Male) used by the voice assistant.
    var voiceGender: VoiceGender = .feminine

    /// Picks a default voice accent from the device's current region.
    static func defaultAccent() -> VoiceAccent {
        let region = Locale.current.region?.identifier ?? ""
        switch region {
        case "US": return .american
        case "GB": return .british
        case "AU": return .australian
        default:   return .american
        }
    }

    /// Converts to the SousCore value type used in LLMRequest.
    func toLLMUserPrefs() -> LLMUserPrefs {
        LLMUserPrefs(
            hardAvoids: hardAvoids,
            servingSize: servingSize,
            equipment: equipment,
            customInstructions: customInstructions,
            personalityMode: personalityMode
        )
    }
}

// MARK: - UserPreferences backward-compatible decoding

extension UserPreferences {
    /// Custom decoder that supplies defaults for any field absent from older
    /// saved JSON, so existing preferences deserialize cleanly without migration.
    /// Declared in an extension so the synthesized memberwise/default initializers
    /// remain available.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hardAvoids = try c.decodeIfPresent([String].self, forKey: .hardAvoids) ?? []
        servingSize = try c.decodeIfPresent(Int.self, forKey: .servingSize)
        equipment = try c.decodeIfPresent([String].self, forKey: .equipment) ?? []
        customInstructions = try c.decodeIfPresent(String.self, forKey: .customInstructions) ?? ""
        personalityMode = try c.decodeIfPresent(String.self, forKey: .personalityMode) ?? "normal"
        // New in this change — absent in older saved JSON; fall back to defaults.
        voiceAccent = try c.decodeIfPresent(VoiceAccent.self, forKey: .voiceAccent) ?? UserPreferences.defaultAccent()
        voiceGender = try c.decodeIfPresent(VoiceGender.self, forKey: .voiceGender) ?? .feminine
    }
}

// MARK: - UserPreferencesPersistence

/// Reads and writes UserPreferences to UserDefaults.
/// Accepts an optional UserDefaults instance so tests can isolate against a throw-away suite.
enum UserPreferencesPersistence {

    static let userDefaultsKey = "sous_user_preferences"

    /// Loads preferences from `defaults`. Returns a zero-value `UserPreferences` if absent or corrupt.
    static func load(from defaults: UserDefaults = .standard) -> UserPreferences {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else { return UserPreferences() }
        return prefs
    }

    /// Saves preferences to `defaults`. Silently no-ops on encoding failure.
    static func save(_ prefs: UserPreferences, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: userDefaultsKey)
    }

    /// Removes the preferences entry from `defaults`.
    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsKey)
    }
}

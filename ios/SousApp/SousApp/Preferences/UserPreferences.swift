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

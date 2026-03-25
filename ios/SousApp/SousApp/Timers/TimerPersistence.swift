import Foundation

// MARK: - TimerPersistence

/// Persists active TimerSession state to UserDefaults so timers survive app backgrounding and relaunch.
enum TimerPersistence {

    private static let key = "sous_active_timers_v1"

    static func save(_ sessions: [TimerSession], to defaults: UserDefaults = .standard) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(sessions) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(from defaults: UserDefaults = .standard) -> [TimerSession] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TimerSession].self, from: data)) ?? []
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

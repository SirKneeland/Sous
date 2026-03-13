import Foundation

// MARK: - MemoryItem

/// A single user-declared memory stored across sessions.
struct MemoryItem: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var text: String
    var createdAt: Date

    init(text: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.createdAt = createdAt
    }
}

// MARK: - MemoriesPersistence

/// Reads and writes [MemoryItem] to UserDefaults.
/// Accepts an optional UserDefaults instance so tests can isolate against a throw-away suite.
enum MemoriesPersistence {

    static let userDefaultsKey = "sous_memories"

    /// Loads memories from `defaults`. Returns [] if absent or corrupt.
    static func load(from defaults: UserDefaults = .standard) -> [MemoryItem] {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let items = try? JSONDecoder().decode([MemoryItem].self, from: data)
        else { return [] }
        return items
    }

    /// Saves memories to `defaults`. Silently no-ops on encoding failure.
    static func save(_ items: [MemoryItem], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: userDefaultsKey)
    }

    /// Removes the memories entry from `defaults`.
    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsKey)
    }
}

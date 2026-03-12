import Foundation
import SousCore

/// Handles crash-safe read/write of the session snapshot to the local filesystem.
///
/// Crash-safety comes from `Data.write(options: .atomic)`, which writes to a
/// temporary file and renames it atomically.  If the process is killed mid-write
/// the previous session file is left intact.
///
/// All methods accept an optional `url` parameter so tests can supply a
/// temporary path and avoid touching the real session file.
enum SessionPersistence {

    /// The Documents directory used as the default sessions location.
    static var sessionsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Legacy single-session file (M10/M11). Used only for migration.
    static var defaultFileURL: URL {
        sessionsDirectory.appendingPathComponent("sous_session.json")
    }

    /// Returns the canonical file URL for a recipe's per-recipe session file.
    static func fileURL(for recipeId: UUID, in directory: URL? = nil) -> URL {
        (directory ?? sessionsDirectory)
            .appendingPathComponent("sous_session_\(recipeId.uuidString).json")
    }

    // MARK: - Single-file API (used by existing tests and migration)

    /// Encodes `snapshot` and writes it atomically to `url`.
    /// Throws on encoding or file-system errors.
    static func save(_ snapshot: SessionSnapshot, to url: URL? = nil) throws {
        let target = url ?? defaultFileURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: target, options: .atomic)
    }

    /// Loads and decodes a snapshot from `url`.
    /// Returns `nil` if the file is absent, unreadable, or corrupt.
    static func load(from url: URL? = nil) -> SessionSnapshot? {
        let source = url ?? defaultFileURL
        guard let data = try? Data(contentsOf: source) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SessionSnapshot.self, from: data)
    }

    /// Removes a session file.
    static func clear(at url: URL? = nil) {
        let target = url ?? defaultFileURL
        try? FileManager.default.removeItem(at: target)
    }

    // MARK: - Multi-session API

    /// Lists all valid recipe sessions in `directory`, sorted by `savedAt` descending.
    /// Only returns sessions with a committed recipe canvas and the current schema version.
    static func listAll(in directory: URL? = nil) -> [SessionSnapshot] {
        let dir = directory ?? sessionsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files
            .filter {
                $0.lastPathComponent.hasPrefix("sous_session_") && $0.pathExtension == "json"
            }
            .compactMap { url -> SessionSnapshot? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(SessionSnapshot.self, from: data)
            }
            .filter {
                $0.schemaVersion == SessionSnapshot.currentSchemaVersion
            }
            .sorted { $0.savedAt > $1.savedAt }
    }

    /// Deletes the per-recipe session file for `recipeId`.
    static func delete(recipeId: UUID, in directory: URL? = nil) {
        try? FileManager.default.removeItem(at: fileURL(for: recipeId, in: directory))
    }
}

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

    static var defaultFileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sous_session.json")
    }

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

    /// Removes the session file.  Used in tests and when starting fresh.
    static func clear(at url: URL? = nil) {
        let target = url ?? defaultFileURL
        try? FileManager.default.removeItem(at: target)
    }
}

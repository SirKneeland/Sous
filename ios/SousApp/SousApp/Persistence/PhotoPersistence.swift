import Foundation
import UIKit

/// Manages on-device storage of chat photo attachments.
///
/// Photos are stored under `<baseDirectory>/<recipeID>/<messageID>.jpg`.
/// The relative path `<recipeID>/<messageID>.jpg` is stored in `ChatMessage.photoPath`
/// and resolved back to an absolute URL at render time via `absoluteURL(for:)`.
///
/// All methods accept an optional `baseDirectory` parameter for test injection.
/// Production code passes nil, which resolves to `Documents/photos/`.
enum PhotoPersistence {

    static var defaultBaseDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos")
    }

    /// Saves JPEG data to disk and returns a relative path, or nil on any filesystem error.
    static func save(
        imageData: Data,
        messageId: UUID,
        recipeId: UUID,
        baseDirectory: URL? = nil
    ) -> String? {
        let base = baseDirectory ?? defaultBaseDirectory
        let recipeDir = base.appendingPathComponent(recipeId.uuidString)
        do {
            try FileManager.default.createDirectory(
                at: recipeDir, withIntermediateDirectories: true
            )
            let filename = "\(messageId.uuidString).jpg"
            try imageData.write(to: recipeDir.appendingPathComponent(filename), options: .atomic)
            return "\(recipeId.uuidString)/\(filename)"
        } catch {
            return nil
        }
    }

    /// Resolves a relative path (as stored in `ChatMessage.photoPath`) to an absolute URL.
    static func absoluteURL(for relativePath: String, baseDirectory: URL? = nil) -> URL {
        (baseDirectory ?? defaultBaseDirectory).appendingPathComponent(relativePath)
    }

    /// Deletes all photos stored for a recipe session. Called when the session is deleted.
    static func deletePhotoDirectory(for recipeId: UUID, baseDirectory: URL? = nil) {
        let dir = (baseDirectory ?? defaultBaseDirectory).appendingPathComponent(recipeId.uuidString)
        try? FileManager.default.removeItem(at: dir)
    }
}

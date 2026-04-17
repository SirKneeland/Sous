import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: MessageRole
    let text: String
    let timestamp: Date
    /// Relative path to an on-device JPEG, e.g. "<recipeID>/<messageID>.jpg".
    /// Nil for messages with no photo attachment.
    let photoPath: String?

    init(role: MessageRole, text: String, timestamp: Date = .now, photoPath: String? = nil) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.photoPath = photoPath
    }

    /// Full memberwise init for cases where a stable ID is required before message creation.
    init(id: UUID, role: MessageRole, text: String, timestamp: Date = .now, photoPath: String? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.photoPath = photoPath
    }
}

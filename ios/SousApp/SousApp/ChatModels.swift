import Foundation

enum MessageRole: String {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let text: String
    let timestamp: Date

    init(role: MessageRole, text: String, timestamp: Date = .now) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

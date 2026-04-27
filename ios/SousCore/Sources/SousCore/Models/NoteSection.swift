import Foundation

public struct NoteSection: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var header: String?
    public var items: [String]

    public init(id: UUID = UUID(), header: String? = nil, items: [String] = []) {
        self.id = id
        self.header = header
        self.items = items
    }
}

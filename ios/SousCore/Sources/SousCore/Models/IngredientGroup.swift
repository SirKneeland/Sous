import Foundation

public struct IngredientGroup: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var header: String?
    public var items: [Ingredient]

    public init(id: UUID = UUID(), header: String? = nil, items: [Ingredient] = []) {
        self.id = id
        self.header = header
        self.items = items
    }
}

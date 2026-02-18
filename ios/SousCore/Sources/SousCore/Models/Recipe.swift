import Foundation

public struct Recipe: Equatable, Sendable {
    public let id: UUID
    public var version: Int
    public var title: String
    public var ingredients: [Ingredient]
    public var steps: [Step]
    public var notes: [String]

    public init(
        id: UUID = UUID(),
        version: Int = 1,
        title: String,
        ingredients: [Ingredient] = [],
        steps: [Step] = [],
        notes: [String] = []
    ) {
        self.id = id
        self.version = version
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.notes = notes
    }
}

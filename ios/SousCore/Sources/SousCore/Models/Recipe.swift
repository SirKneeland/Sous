import Foundation

public struct Recipe: Equatable, Sendable, Codable {
    public let id: UUID
    public var version: Int
    public var title: String
    public var ingredients: [Ingredient]
    public var steps: [Step]
    public var notes: [String]
    /// Prep steps extracted by the mise en place feature. Nil until the user triggers it.
    /// Rendered between INGREDIENTS and PROCEDURE. Does not affect "all steps done" logic.
    public var miseEnPlace: [Step]?

    public init(
        id: UUID = UUID(),
        version: Int = 1,
        title: String,
        ingredients: [Ingredient] = [],
        steps: [Step] = [],
        notes: [String] = [],
        miseEnPlace: [Step]? = nil
    ) {
        self.id = id
        self.version = version
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.notes = notes
        self.miseEnPlace = miseEnPlace
    }
}

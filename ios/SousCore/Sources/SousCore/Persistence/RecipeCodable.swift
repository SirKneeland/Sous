import Foundation

// MARK: - StepStatus + Codable
//
// StepStatus is an enum without raw values, so Codable synthesis is not available.
// We encode as a plain string ("todo" / "done").

extension StepStatus: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .todo: try container.encode("todo")
        case .done: try container.encode("done")
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "todo": self = .todo
        case "done": self = .done
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown StepStatus value"
            )
        }
    }
}

// Ingredient and Step are declared Codable in their respective model files so
// the compiler can synthesise encode(to:) and init(from:) automatically.
//
// Recipe uses a manual Codable extension below to support backward compatibility
// when loading sessions saved with the old flat [Step] miseEnPlace format.

// MARK: - Recipe + Codable

extension Recipe: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, version, title, ingredients, steps, notes, miseEnPlace
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(version, forKey: .version)
        try c.encode(title, forKey: .title)
        try c.encode(ingredients, forKey: .ingredients)
        try c.encode(steps, forKey: .steps)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(miseEnPlace, forKey: .miseEnPlace)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id          = try c.decode(UUID.self,         forKey: .id)
        self.version     = try c.decode(Int.self,          forKey: .version)
        self.title       = try c.decode(String.self,       forKey: .title)
        self.ingredients = try c.decode([Ingredient].self, forKey: .ingredients)
        self.steps       = try c.decode([Step].self,       forKey: .steps)
        self.notes       = try c.decode([String].self,     forKey: .notes)

        // Prefer the new [MiseEnPlaceEntry] format. If the key holds data in the
        // old [Step] format (sessions saved before this change), convert each old
        // step to a solo entry so nothing is lost. If the key is absent, leave nil.
        if let entries = try? c.decodeIfPresent([MiseEnPlaceEntry].self, forKey: .miseEnPlace) {
            self.miseEnPlace = entries
        } else if let oldSteps = try? c.decodeIfPresent([Step].self, forKey: .miseEnPlace) {
            self.miseEnPlace = oldSteps.map { step in
                MiseEnPlaceEntry(
                    id: step.id,
                    content: .solo(instruction: step.text, isDone: step.status == .done)
                )
            }
        } else {
            self.miseEnPlace = nil
        }
    }
}

import Foundation

// MARK: - MiseEnPlaceComponent

/// A single ingredient or prep item inside a grouped mise en place vessel.
public struct MiseEnPlaceComponent: Equatable, Sendable, Codable {
    public let id: UUID
    public let text: String
    public var isDone: Bool

    public init(id: UUID = UUID(), text: String, isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}

// MARK: - MiseEnPlaceEntry

/// One entry in the mise en place section.
///
/// - `group`: Multiple ingredients combined into a named vessel (e.g. "Spice Bowl").
///   Each component is individually checkable; the entry is done when all components are done.
/// - `solo`: A standalone prep instruction with no vessel grouping.
public struct MiseEnPlaceEntry: Equatable, Sendable {
    public let id: UUID
    public let content: Content

    public enum Content: Equatable, Sendable {
        case group(vesselName: String, components: [MiseEnPlaceComponent])
        case solo(instruction: String, isDone: Bool)
    }

    /// True when all components are done (group) or the step itself is done (solo).
    public var isDone: Bool {
        switch content {
        case .group(_, let components): return components.allSatisfy { $0.isDone }
        case .solo(_, let isDone):      return isDone
        }
    }

    public init(id: UUID = UUID(), content: Content) {
        self.id = id
        self.content = content
    }
}

// MARK: - MiseEnPlaceEntry + Codable

extension MiseEnPlaceEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, vesselName, components, instruction, isDone
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        switch content {
        case .group(let vesselName, let components):
            try c.encode("group", forKey: .type)
            try c.encode(vesselName, forKey: .vesselName)
            try c.encode(components, forKey: .components)
        case .solo(let instruction, let isDone):
            try c.encode("solo", forKey: .type)
            try c.encode(instruction, forKey: .instruction)
            try c.encode(isDone, forKey: .isDone)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        let type = try c.decode(String.self, forKey: .type)
        let content: Content
        switch type {
        case "group":
            let vesselName = try c.decode(String.self, forKey: .vesselName)
            let components = try c.decode([MiseEnPlaceComponent].self, forKey: .components)
            content = .group(vesselName: vesselName, components: components)
        case "solo":
            let instruction = try c.decode(String.self, forKey: .instruction)
            let isDone = try c.decode(Bool.self, forKey: .isDone)
            content = .solo(instruction: instruction, isDone: isDone)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "Unknown MiseEnPlaceEntry type: \(type)"
            )
        }
        self.init(id: id, content: content)
    }
}

import Foundation

// MARK: - PatchSetStatus + Codable

extension PatchSetStatus: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .pending:  try container.encode("pending")
        case .accepted: try container.encode("accepted")
        case .rejected: try container.encode("rejected")
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "pending":  self = .pending
        case "accepted": self = .accepted
        case "rejected": self = .rejected
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown PatchSetStatus value"
            )
        }
    }
}

// MARK: - Patch + Codable
//
// Patch is an enum with associated values, so synthesis is not available.
// We use a discriminated object with a "type" key.

extension Patch: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, text, id, afterId, afterStepId
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .addIngredient(let text, let afterId):
            try c.encode("addIngredient", forKey: .type)
            try c.encode(text, forKey: .text)
            try c.encodeIfPresent(afterId, forKey: .afterId)
        case .updateIngredient(let id, let text):
            try c.encode("updateIngredient", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(text, forKey: .text)
        case .removeIngredient(let id):
            try c.encode("removeIngredient", forKey: .type)
            try c.encode(id, forKey: .id)
        case .addStep(let text, let afterStepId):
            try c.encode("addStep", forKey: .type)
            try c.encode(text, forKey: .text)
            try c.encodeIfPresent(afterStepId, forKey: .afterStepId)
        case .updateStep(let id, let text):
            try c.encode("updateStep", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(text, forKey: .text)
        case .removeStep(let id):
            try c.encode("removeStep", forKey: .type)
            try c.encode(id, forKey: .id)
        case .addNote(let text):
            try c.encode("addNote", forKey: .type)
            try c.encode(text, forKey: .text)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "addIngredient":
            self = .addIngredient(
                text: try c.decode(String.self, forKey: .text),
                afterId: try c.decodeIfPresent(UUID.self, forKey: .afterId)
            )
        case "updateIngredient":
            self = .updateIngredient(
                id: try c.decode(UUID.self, forKey: .id),
                text: try c.decode(String.self, forKey: .text)
            )
        case "removeIngredient":
            self = .removeIngredient(id: try c.decode(UUID.self, forKey: .id))
        case "addStep":
            self = .addStep(
                text: try c.decode(String.self, forKey: .text),
                afterStepId: try c.decodeIfPresent(UUID.self, forKey: .afterStepId)
            )
        case "updateStep":
            self = .updateStep(
                id: try c.decode(UUID.self, forKey: .id),
                text: try c.decode(String.self, forKey: .text)
            )
        case "removeStep":
            self = .removeStep(id: try c.decode(UUID.self, forKey: .id))
        case "addNote":
            self = .addNote(text: try c.decode(String.self, forKey: .text))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "Unknown Patch type: \(type)"
            )
        }
    }
}

// PatchSet is declared Codable in PatchSet.swift so the compiler can synthesise
// encode(to:) and init(from:) automatically. All stored property types are Codable:
// UUID, Int, PatchSetStatus (above), [Patch] (above), String?, and Recipe (RecipeCodable.swift).

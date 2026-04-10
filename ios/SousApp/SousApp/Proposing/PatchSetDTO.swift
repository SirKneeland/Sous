import Foundation
import SousCore

// MARK: - PatchSetDTO

struct PatchSetDTO: Decodable {
    let baseRecipeId: UUID
    let baseRecipeVersion: Int
    let patches: [PatchDTO]

    func toDomain() -> PatchSet {
        PatchSet(
            baseRecipeId: baseRecipeId,
            baseRecipeVersion: baseRecipeVersion,
            patches: patches.map { $0.toDomain() }
        )
    }
}

// MARK: - PatchDTO

enum PatchDTO: Decodable {
    case addIngredient(text: String, afterId: UUID?)
    case updateIngredient(id: UUID, text: String)
    case removeIngredient(id: UUID)
    case addStep(text: String, afterStepId: UUID?)
    case updateStep(id: UUID, text: String)
    case removeStep(id: UUID)
    case addNote(text: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, id, afterId, afterStepId
    }

    init(from decoder: Decoder) throws {
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
                debugDescription: "Unknown patch type: \(type)"
            )
        }
    }

    func toDomain() -> Patch {
        switch self {
        case .addIngredient(let text, let afterId):
            return .addIngredient(text: text, afterId: afterId)
        case .updateIngredient(let id, let text):
            return .updateIngredient(id: id, text: text)
        case .removeIngredient(let id):
            return .removeIngredient(id: id)
        case .addStep(let text, let afterStepId):
            return .addStep(text: text, afterStepId: afterStepId, preassignedId: nil)
        case .updateStep(let id, let text):
            return .updateStep(id: id, text: text)
        case .removeStep(let id):
            return .removeStep(id: id)
        case .addNote(let text):
            return .addNote(text: text)
        }
    }
}

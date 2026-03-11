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

// Ingredient, Step, and Recipe are declared Codable in their respective model
// files so the compiler can synthesise encode(to:) and init(from:) automatically.

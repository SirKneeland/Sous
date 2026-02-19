import Foundation

public enum Patch: Equatable, Sendable {
    case addIngredient(text: String, afterId: UUID?)
    case updateIngredient(id: UUID, text: String)
    case removeIngredient(id: UUID)
    case addStep(text: String, afterStepId: UUID?)
    case updateStep(id: UUID, text: String)
    case removeStep(id: UUID)
    case addNote(text: String)
}

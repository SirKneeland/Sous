import Foundation

public enum Patch: Equatable, Sendable {
    // Title
    case setTitle(String)

    // Ingredients
    case addIngredient(groupId: UUID?, afterId: UUID?, text: String)
    case updateIngredient(id: UUID, text: String)
    case removeIngredient(id: UUID)
    case addIngredientGroup(afterGroupId: UUID?, header: String?, preassignedId: UUID?)
    case updateIngredientGroup(id: UUID, header: String?)
    case removeIngredientGroup(id: UUID)

    // Steps — flat ID-based operations, tree-searched at any depth
    case addStep(parentId: UUID?, afterId: UUID?, text: String, preassignedId: UUID?)
    case updateStep(id: UUID, text: String)
    case removeStep(id: UUID)
    case setStepNotes(stepId: UUID, notes: [String])

    // Recipe-level note sections
    case addNoteSection(afterId: UUID?, header: String?, items: [String])
    case updateNoteSection(id: UUID, header: String?, items: [String])
    case removeNoteSection(id: UUID)
}

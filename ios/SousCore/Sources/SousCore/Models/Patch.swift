import Foundation

public enum Patch: Equatable, Sendable {
    case addIngredient(text: String, afterId: UUID?)
    case updateIngredient(id: UUID, text: String)
    case removeIngredient(id: UUID)
    case addStep(text: String, afterStepId: UUID?)
    case updateStep(id: UUID, text: String)
    case removeStep(id: UUID)
    case addNote(text: String)
    /// Sets the recipe title. Used when creating a recipe from scratch (blank state).
    case setTitle(String)
    /// Appends or inserts a new sub-step under an existing parent step.
    case addSubStep(parentStepId: UUID, text: String, afterSubStepId: UUID?)
    /// Updates the text of an existing sub-step.
    case updateSubStep(parentStepId: UUID, subStepId: UUID, text: String)
    /// Removes an existing sub-step from its parent.
    case removeSubStep(parentStepId: UUID, subStepId: UUID)
    /// Marks a sub-step as done.
    case completeSubStep(parentStepId: UUID, subStepId: UUID)
}

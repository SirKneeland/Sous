import Foundation

public enum PatchSetStatus: Equatable, Sendable {
    case pending
    case accepted
    case rejected
}

public struct PatchSet: Equatable, Sendable, Codable {
    public let patchSetId: UUID
    public let baseRecipeId: UUID
    public let baseRecipeVersion: Int
    public var status: PatchSetStatus
    public var patches: [Patch]
    public var summary: String?
    public var baseRecipeSnapshot: Recipe?
    /// New servings value the model reported alongside this patch (e.g. when rescaling).
    /// Nil means "leave the recipe's existing servings untouched" when applied.
    public var servings: Int?

    public init(
        patchSetId: UUID = UUID(),
        baseRecipeId: UUID,
        baseRecipeVersion: Int,
        status: PatchSetStatus = .pending,
        patches: [Patch],
        summary: String? = nil,
        baseRecipeSnapshot: Recipe? = nil,
        servings: Int? = nil
    ) {
        self.patchSetId = patchSetId
        self.baseRecipeId = baseRecipeId
        self.baseRecipeVersion = baseRecipeVersion
        self.status = status
        self.patches = patches
        self.summary = summary
        self.baseRecipeSnapshot = baseRecipeSnapshot
        self.servings = servings
    }
}

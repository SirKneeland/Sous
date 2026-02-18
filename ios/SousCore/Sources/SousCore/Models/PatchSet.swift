import Foundation

public enum PatchSetStatus: Equatable, Sendable {
    case pending
    case accepted
    case rejected
}

public struct PatchSet: Equatable, Sendable {
    public let patchSetId: UUID
    public let baseRecipeId: UUID
    public let baseRecipeVersion: Int
    public var status: PatchSetStatus
    public var patches: [Patch]
    public var summary: String?
    public var baseRecipeSnapshot: Recipe?

    public init(
        patchSetId: UUID = UUID(),
        baseRecipeId: UUID,
        baseRecipeVersion: Int,
        status: PatchSetStatus = .pending,
        patches: [Patch],
        summary: String? = nil,
        baseRecipeSnapshot: Recipe? = nil
    ) {
        self.patchSetId = patchSetId
        self.baseRecipeId = baseRecipeId
        self.baseRecipeVersion = baseRecipeVersion
        self.status = status
        self.patches = patches
        self.summary = summary
        self.baseRecipeSnapshot = baseRecipeSnapshot
    }
}

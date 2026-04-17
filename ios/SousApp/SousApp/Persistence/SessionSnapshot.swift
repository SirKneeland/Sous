import Foundation
import SousCore

/// The full state saved to disk after key user interactions.
///
/// - `schemaVersion` is checked on load so future schema changes can be
///   detected and handled (currently: fall back to seed if version mismatches).
/// - `pendingPatchSet` is non-nil only when the user had an un-reviewed AI
///   suggestion at the time of save.  On restore it re-enters `.patchProposed`.
/// - `chatMessages` holds the last 20 user/assistant messages from the session.
/// - `nextLLMContext` preserves the last accept/reject decision so the model
///   receives it on the very next call after relaunch.
/// - `ingredientsExpanded` / `stepsCompletedExpanded` / `miseEnPlaceExpanded`
///   persist the canvas collapsed-section state across relaunch and recipe
///   switches (v3 added the first two; v4 added miseEnPlaceExpanded).
struct SessionSnapshot: Codable, Sendable {
    static let currentSchemaVersion = 4

    let schemaVersion: Int
    /// Whether a recipe canvas exists in the session (false = blank/exploration state).
    let hasCanvas: Bool
    let recipe: Recipe
    let pendingPatchSet: PatchSet?
    let chatMessages: [ChatMessage]
    let nextLLMContext: NextLLMContext?
    let savedAt: Date
    /// Whether the Ingredients section is expanded on the recipe canvas.
    let ingredientsExpanded: Bool
    /// Whether the completed-steps section is expanded. When false, done steps
    /// are hidden while TODO steps remain visible.
    let stepsCompletedExpanded: Bool
    /// Whether the mise en place section is expanded. Defaults to false (collapsed).
    let miseEnPlaceExpanded: Bool

    /// Memberwise initializer with new-recipe defaults for the v3/v4 fields.
    init(
        schemaVersion: Int,
        hasCanvas: Bool,
        recipe: Recipe,
        pendingPatchSet: PatchSet?,
        chatMessages: [ChatMessage],
        nextLLMContext: NextLLMContext?,
        savedAt: Date,
        ingredientsExpanded: Bool = true,
        stepsCompletedExpanded: Bool = false,
        miseEnPlaceExpanded: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.hasCanvas = hasCanvas
        self.recipe = recipe
        self.pendingPatchSet = pendingPatchSet
        self.chatMessages = chatMessages
        self.nextLLMContext = nextLLMContext
        self.savedAt = savedAt
        self.ingredientsExpanded = ingredientsExpanded
        self.stepsCompletedExpanded = stepsCompletedExpanded
        self.miseEnPlaceExpanded = miseEnPlaceExpanded
    }

    /// Custom decoder that migrates v2 sessions to v3 by supplying new-recipe
    /// defaults for the two fields that didn't exist in v2.
    /// Sessions older than v2 are rejected with a decoding error.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard rawVersion >= 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: container,
                debugDescription: "Schema version \(rawVersion) is too old to migrate"
            )
        }
        // Always normalize to the current version so the listAll filter works.
        schemaVersion = SessionSnapshot.currentSchemaVersion
        hasCanvas = try container.decode(Bool.self, forKey: .hasCanvas)
        recipe = try container.decode(Recipe.self, forKey: .recipe)
        pendingPatchSet = try container.decodeIfPresent(PatchSet.self, forKey: .pendingPatchSet)
        chatMessages = try container.decode([ChatMessage].self, forKey: .chatMessages)
        nextLLMContext = try container.decodeIfPresent(NextLLMContext.self, forKey: .nextLLMContext)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        // v3 fields — absent in v2 JSON; apply new-recipe defaults when missing.
        ingredientsExpanded = try container.decodeIfPresent(Bool.self, forKey: .ingredientsExpanded) ?? true
        stepsCompletedExpanded = try container.decodeIfPresent(Bool.self, forKey: .stepsCompletedExpanded) ?? false
        // v4 field — absent in v3 JSON; default to collapsed.
        miseEnPlaceExpanded = try container.decodeIfPresent(Bool.self, forKey: .miseEnPlaceExpanded) ?? false
    }
}

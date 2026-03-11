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
struct SessionSnapshot: Codable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let recipe: Recipe
    let pendingPatchSet: PatchSet?
    let chatMessages: [ChatMessage]
    let nextLLMContext: NextLLMContext?
    let savedAt: Date
}

import Foundation

// MARK: - LLMUserPrefs

/// Value-type snapshot of the user preferences the LLM prompt needs.
/// The adapter that reads Foundation.UserDefaults → LLMUserPrefs lives at call-site in SousApp.
public struct LLMUserPrefs: Equatable, Sendable {
    /// Hard dietary constraints. The LLM must never propose patches that introduce these.
    public let hardAvoids: [String]
    /// Default number of people to serve. Nil means not set.
    public let servingSize: Int?
    /// Kitchen tools and equipment available to the user.
    public let equipment: [String]
    /// Free-form instructions applied to every recipe.
    public let customInstructions: String
    /// User-declared memories to include as context (e.g. "I avoid cilantro").
    public let memories: [String]
    /// Personality mode controlling AI communication style. Valid values: "minimal", "normal", "playful".
    public let personalityMode: String

    public init(
        hardAvoids: [String],
        servingSize: Int? = nil,
        equipment: [String] = [],
        customInstructions: String = "",
        memories: [String] = [],
        personalityMode: String = "normal"
    ) {
        self.hardAvoids = hardAvoids
        self.servingSize = servingSize
        self.equipment = equipment
        self.customInstructions = customInstructions
        self.memories = memories
        self.personalityMode = personalityMode
    }
}

// MARK: - PatchDecision

/// Records the user's explicit decision on a PatchSet, carried forward as LLM context.
public struct PatchDecision: Equatable, Sendable, Codable {
    public enum Decision: String, Equatable, Sendable, Codable {
        case accepted
        case rejected
    }

    public let patchSetId: String
    public let decision: Decision
    public let decidedAtMs: Int

    public init(patchSetId: String, decision: Decision, decidedAtMs: Int) {
        self.patchSetId = patchSetId
        self.decision = decision
        self.decidedAtMs = decidedAtMs
    }
}

// MARK: - NextLLMContext

/// One-shot context attached to the next LLM request, then cleared.
/// Prevents the model from re-proposing a rejected plan.
public struct NextLLMContext: Equatable, Sendable, Codable {
    public let lastPatchDecision: PatchDecision?

    public init(lastPatchDecision: PatchDecision?) {
        self.lastPatchDecision = lastPatchDecision
    }
}

// MARK: - LLMRequest

/// Immutable inputs passed to LLMClient / LLMOrchestrator.
/// Plain Sendable — all stored properties are value types. Recipe is Sendable.
public struct LLMRequest: Sendable {
    /// Explicit recipe ID, even though Recipe carries it, to make the boundary unambiguous.
    public let recipeId: String
    public let recipeVersion: Int
    /// True when a recipe canvas already exists in the session.
    public let hasCanvas: Bool
    public let userMessage: String
    /// Full recipe snapshot for prompt construction. Treated as read-only by the LLM layer.
    public let recipeSnapshotForPrompt: Recipe
    public let userPrefs: LLMUserPrefs
    /// Included exactly once with this request, then cleared by the caller.
    public let nextLLMContext: NextLLMContext?
    /// Prior user/assistant turns from the session transcript, oldest first.
    /// Injected between the recipe context and the current user message so the model
    /// has multi-turn memory. Empty for the first message in a session.
    public let conversationHistory: [LLMMessage]

    public init(
        recipeId: String,
        recipeVersion: Int,
        hasCanvas: Bool,
        userMessage: String,
        recipeSnapshotForPrompt: Recipe,
        userPrefs: LLMUserPrefs,
        nextLLMContext: NextLLMContext? = nil,
        conversationHistory: [LLMMessage] = []
    ) {
        self.recipeId = recipeId
        self.recipeVersion = recipeVersion
        self.hasCanvas = hasCanvas
        self.userMessage = userMessage
        self.recipeSnapshotForPrompt = recipeSnapshotForPrompt
        self.userPrefs = userPrefs
        self.nextLLMContext = nextLLMContext
        self.conversationHistory = conversationHistory
    }
}

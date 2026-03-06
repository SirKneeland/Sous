import Foundation

// MARK: - LLMDebugStatus

public enum LLMDebugStatus: String, Equatable, Sendable {
    case idle
    case calling
    case repairing
    case retrying
    case succeeded
    case failed
}

// MARK: - LLMDebugBundle

/// Diagnostic bundle attached to every LLMResult for surfacing debug info in chat.
/// Not shown to the user in production; drives the debug status indicator in DEBUG builds.
public struct LLMDebugBundle: Equatable, Sendable {
    public let status: LLMDebugStatus
    public let attemptCount: Int
    public let maxAttempts: Int
    public let requestId: String
    public let extractionUsed: Bool
    public let repairUsed: Bool
    public let timingTotalMs: Int
    public let timingNetworkMs: Int?
    public let timingDecodeMs: Int?
    public let timingValidateMs: Int?
    /// Coarse error category matching LLMError buckets; nil on success.
    public let lastErrorCategory: LLMError?
    /// Unknown JSON keys seen during decode, if any.
    public let unknownKeysSeen: [String]?
    /// Model identifier used for the LLM call (e.g. "gpt-4o-mini").
    public let model: String
    /// Prompt schema version constant (e.g. "v1"). Stable across builds for eval comparison.
    public let promptVersion: String
    /// Coarse result outcome: "valid" | "noPatches" | "failure".
    public let outcome: String
    /// Stable failure bucket string; nil on success. See LLMError mapping in orchestrator.
    public let failureCategory: String?
    /// Reason the attempt loop terminated. E.g. "success", "fatal_validation", "expired_validation",
    /// "budget_exhausted", "repeat_failure", "repair_identical". Nil when not yet set.
    public let terminationReason: String?
    /// Token counts from the OpenAI usage field. Nil if absent in the response.
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?

    public init(
        status: LLMDebugStatus,
        attemptCount: Int,
        maxAttempts: Int,
        requestId: String,
        extractionUsed: Bool,
        repairUsed: Bool,
        timingTotalMs: Int,
        timingNetworkMs: Int? = nil,
        timingDecodeMs: Int? = nil,
        timingValidateMs: Int? = nil,
        lastErrorCategory: LLMError? = nil,
        unknownKeysSeen: [String]? = nil,
        model: String = "unknown",
        promptVersion: String = "unknown",
        outcome: String = "unknown",
        failureCategory: String? = nil,
        terminationReason: String? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil
    ) {
        self.status = status
        self.attemptCount = attemptCount
        self.maxAttempts = maxAttempts
        self.requestId = requestId
        self.extractionUsed = extractionUsed
        self.repairUsed = repairUsed
        self.timingTotalMs = timingTotalMs
        self.timingNetworkMs = timingNetworkMs
        self.timingDecodeMs = timingDecodeMs
        self.timingValidateMs = timingValidateMs
        self.lastErrorCategory = lastErrorCategory
        self.unknownKeysSeen = unknownKeysSeen
        self.model = model
        self.promptVersion = promptVersion
        self.outcome = outcome
        self.failureCategory = failureCategory
        self.terminationReason = terminationReason
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

// MARK: - LLMError

public enum LLMError: Error, Equatable, Sendable {
    /// No API key found in the environment.
    case missingAPIKey
    /// Network-level failure (no response received).
    case network
    /// Request exceeded the timeout threshold.
    case timeout
    /// Request was cancelled by the caller.
    case cancelled
    /// Response body was not JSON at all.
    case decodeNonJSON
    /// Response was JSON but did not match the expected schema shape.
    case decodeInvalidJSON
    /// Schema shape matched but required fields were missing or wrong type.
    case schemaInvalid
    /// PatchSet failed validation but the error is repairable (retry allowed).
    case validationRecoverable
    /// PatchSet targets a stale recipe version; must be discarded and regenerated.
    case validationExpired
    /// PatchSet failed validation fatally (e.g. attempted to mutate a done step).
    case validationFatal
    /// The patchSet.baseRecipeId does not match the current recipe ID; reject immediately.
    case recipeIdMismatchFatal
    /// HTTP 429 — rate limited or quota exceeded. retryAfterSec parsed from Retry-After header.
    case rateLimited(retryAfterSec: Int?)
    /// HTTP 401 or 403 — authentication / authorisation failure. Not retryable.
    case auth
    /// HTTP 4xx (other than 401/403/429) — malformed request.
    case badRequest
    /// HTTP 5xx — server-side error.
    case server
}

// MARK: - LLMResult

/// Structured result returned by LLMOrchestrator.
/// By construction, at most one PatchSet is ever present across all cases,
/// enforcing the "only one pending PatchSet" invariant at the type level.
public enum LLMResult: Sendable {
    /// The LLM returned a valid, validated PatchSet ready for user review.
    case valid(
        patchSet: PatchSet,
        assistantMessage: String,
        raw: LLMRawResponse?,
        debug: LLMDebugBundle
    )

    /// The LLM responded conversationally with no patch proposal.
    case noPatches(
        assistantMessage: String,
        raw: LLMRawResponse?,
        debug: LLMDebugBundle
    )

    /// All attempts failed. A fallback PatchSet may be present for DEBUG surfacing only;
    /// callers must not enter patch review with a failure result.
    case failure(
        fallbackPatchSet: PatchSet?,
        assistantMessage: String,
        raw: LLMRawResponse?,
        debug: LLMDebugBundle,
        error: LLMError
    )
}

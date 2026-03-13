import Foundation

// MARK: - AttemptContext

/// Mutable state threaded via inout through the attempt loop.
/// Created fresh in run() and never escapes it — no sharing across tasks.
private struct AttemptContext {
    /// Total number of client.send() invocations this run.
    var totalCalls: Int = 0
    var repairUsed: Bool = false
    /// Failure signature of the most recent failure: "\(category):\(primaryReason)".
    /// Used to detect exact-signature repeats before dispatching repair.
    var lastFailureSignature: String? = nil
}

// MARK: - OpenAILLMOrchestrator

/// Concrete LLMOrchestrator for OpenAI-compatible transports.
/// Owns prompt construction, decode, validation, and a single repair pass.
/// Never mutates Recipe State.
public struct OpenAILLMOrchestrator: LLMOrchestrator {

    public let client: LLMClient
    public let model: String
    public let timeout: TimeInterval

    private static let promptVersion = "v3"
    private static let maxCalls = 3

    public init(client: LLMClient, model: String, timeout: TimeInterval = 30) {
        self.client = client
        self.model = model
        self.timeout = timeout
    }

    // MARK: - LLMOrchestrator

    /// Maximum compressed image size accepted before any network call.
    /// Base64 encoding adds ~33%, keeping the total payload well under OpenAI's limit.
    private static let maxImageBytes = 10 * 1024 * 1024  // 10 MB compressed

    /// Multimodal path: attaches the prepared image to the last user message and uses
    /// the vision-capable model.  Repair calls (on JSON errors) are text-only — the image
    /// is not re-sent during repair, only the error context.
    public func run(_ request: MultimodalLLMRequest) async -> LLMResult {
        if request.image.preparedByteCount > Self.maxImageBytes {
            let id = UUID().uuidString
            return .failure(
                fallbackPatchSet: nil,
                assistantMessage: "The photo is too large to send. Please try a different photo.",
                raw: nil,
                debug: makeDebug(.failed, outcome: "failure", attempts: 0,
                                 id: id, elapsed: 0,
                                 error: .badRequest, terminationReason: "payload_too_large"),
                error: .badRequest
            )
        }

        let requestId = UUID().uuidString
        let startMs = nowMs()
        var context = AttemptContext()
        var raw: LLMRawResponse?
        var networkMs: Int = 0

        while true {
            context.totalCalls += 1
            let netStart = nowMs()
            do {
                raw = try await client.send(LLMClientRequest(
                    requestId: requestId,
                    model: model,
                    messages: buildMessages(for: request.base),
                    responseFormat: .jsonObject,
                    timeout: timeout,
                    image: request.image
                ))
                networkMs = nowMs() - netStart
                break
            } catch {
                networkMs = nowMs() - netStart
                let llmErr = error as? LLMError ?? .network

                if case .auth = llmErr {
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: assistantMessage(for: .auth),
                        raw: nil,
                        debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                        id: requestId, elapsed: nowMs() - startMs,
                                        networkMs: networkMs, error: .auth,
                                        terminationReason: "fatal_auth"),
                        error: .auth
                    )
                }

                let sig: String
                if case .rateLimited = llmErr { sig = "rateLimited:" }
                else { sig = "network:" }

                if sig == context.lastFailureSignature {
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: assistantMessage(for: llmErr),
                        raw: nil,
                        debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                        id: requestId, elapsed: nowMs() - startMs,
                                        networkMs: networkMs, error: llmErr,
                                        terminationReason: "repeat_failure"),
                        error: llmErr
                    )
                }
                context.lastFailureSignature = sig
                if context.totalCalls < Self.maxCalls {
                    if case .rateLimited(let retryAfter) = llmErr {
                        await rateLimitedBackoff(retryAfterSec: retryAfter)
                    } else {
                        await backoff(attempt: context.totalCalls)
                    }
                    continue
                }
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: assistantMessage(for: llmErr),
                    raw: nil,
                    debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                    id: requestId, elapsed: nowMs() - startMs,
                                    networkMs: networkMs, error: llmErr,
                                    terminationReason: "budget_exhausted"),
                    error: llmErr
                )
            }
        }

        // Repair (on decode/validation error) is text-only — image is not re-sent.
        return await decodeAndValidate(
            raw: raw!, request: request.base,
            requestId: requestId, startMs: startMs, isRepair: false,
            networkMs: networkMs, context: &context
        )
    }

    public func run(_ request: LLMRequest) async -> LLMResult {
        let requestId = UUID().uuidString
        let startMs = nowMs()
        var context = AttemptContext()

        // Primary call with at most one network retry (within maxCalls budget).
        var raw: LLMRawResponse?
        var networkMs: Int = 0
        while true {
            context.totalCalls += 1
            let netStart = nowMs()
            do {
                raw = try await client.send(LLMClientRequest(
                    requestId: requestId,
                    model: model,
                    messages: buildMessages(for: request),
                    responseFormat: .jsonObject,
                    timeout: timeout
                ))
                networkMs = nowMs() - netStart
                break
            } catch {
                networkMs = nowMs() - netStart
                let llmErr = error as? LLMError ?? .network

                // Auth errors are fatal — never retry.
                if case .auth = llmErr {
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: assistantMessage(for: .auth),
                        raw: nil,
                        debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                        id: requestId, elapsed: nowMs() - startMs,
                                        networkMs: networkMs, error: .auth,
                                        terminationReason: "fatal_auth"),
                        error: .auth
                    )
                }

                let sig: String
                if case .rateLimited = llmErr { sig = "rateLimited:" }
                else { sig = "network:" }

                if sig == context.lastFailureSignature {
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: assistantMessage(for: llmErr),
                        raw: nil,
                        debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                        id: requestId, elapsed: nowMs() - startMs,
                                        networkMs: networkMs, error: llmErr,
                                        terminationReason: "repeat_failure"),
                        error: llmErr
                    )
                }
                context.lastFailureSignature = sig
                if context.totalCalls < Self.maxCalls {
                    if case .rateLimited(let retryAfter) = llmErr {
                        await rateLimitedBackoff(retryAfterSec: retryAfter)
                    } else {
                        await backoff(attempt: context.totalCalls)
                    }
                    continue
                }
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: assistantMessage(for: llmErr),
                    raw: nil,
                    debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                    id: requestId, elapsed: nowMs() - startMs,
                                    networkMs: networkMs, error: llmErr,
                                    terminationReason: "budget_exhausted"),
                    error: llmErr
                )
            }
        }

        return await decodeAndValidate(
            raw: raw!, request: request,
            requestId: requestId, startMs: startMs, isRepair: false,
            networkMs: networkMs, context: &context
        )
    }

    // MARK: - Backoff

    private func backoff(attempt: Int) async {
        let base = 0.5
        let cap = 2.0
        let jitter = Double.random(in: 0...0.3)
        let delaySeconds = min(base * pow(2.0, Double(attempt - 1)) + jitter, cap)
        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
    }

    private func rateLimitedBackoff(retryAfterSec: Int?) async {
        let cap = 2.0
        let seconds = min(Double(retryAfterSec ?? 1), cap)
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func assistantMessage(for error: LLMError) -> String {
        switch error {
        case .missingAPIKey:                             return "OpenAI API key missing. Add it in Debug settings."
        case .auth:                                      return "OpenAI key invalid or unauthorized."
        case .rateLimited:                               return "OpenAI quota/rate limit hit. Try again shortly."
        case .server:                                    return "OpenAI service error. Try again."
        case .badRequest:                                return "Request failed. Please try a different phrasing."
        case .network, .timeout, .cancelled:             return "Network issue. Check connection and try again."
        case .decodeNonJSON, .decodeInvalidJSON,
             .schemaInvalid, .validationRecoverable,
             .validationExpired, .validationFatal,
             .recipeIdMismatchFatal:                     return "Something went wrong. Please try again."
        }
    }

    // MARK: - Decode + Validate

    private func decodeAndValidate(
        raw: LLMRawResponse,
        request: LLMRequest,
        requestId: String,
        startMs: Int,
        isRepair: Bool,
        networkMs: Int?,
        context: inout AttemptContext
    ) async -> LLMResult {

        let attempts = context.totalCalls
        let decodeResult = PatchSetDecoder().decode(raw.rawText)

        switch decodeResult {
        case .failure(let df):
            let sig = signatureForDecode(df)
            let llmErr = mapDecode(df)
            if sig == context.lastFailureSignature {
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: "I had trouble formatting my response. Please try rephrasing.",
                    raw: raw,
                    debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                    elapsed: nowMs() - startMs, networkMs: networkMs,
                                    repairUsed: context.repairUsed, error: llmErr,
                                    terminationReason: "repeat_failure", raw: raw),
                    error: llmErr
                )
            }
            if context.repairUsed || context.totalCalls >= Self.maxCalls {
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: "I had trouble formatting my response. Please try rephrasing.",
                    raw: raw,
                    debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                    elapsed: nowMs() - startMs, networkMs: networkMs,
                                    repairUsed: context.repairUsed, error: llmErr,
                                    terminationReason: "budget_exhausted", raw: raw),
                    error: llmErr
                )
            }
            context.lastFailureSignature = sig
            let decodeErrors = [ErrorDescriptor(code: sig, message: describeDecodeFailure(df))]
            return await repair(
                request: request, previousJSON: raw.rawText, errors: decodeErrors,
                requestId: requestId, startMs: startMs, context: &context
            )

        case .success(let dto, let extractionUsed, let unknownKeys):
            guard let psDTO = dto.patchSet else {
                return .noPatches(
                    assistantMessage: dto.assistantMessage,
                    raw: raw,
                    debug: makeDebug(.succeeded, outcome: "noPatches", attempts: attempts, id: requestId,
                                    elapsed: nowMs() - startMs, networkMs: networkMs,
                                    extractionUsed: extractionUsed, repairUsed: context.repairUsed,
                                    unknownKeys: unknownKeys, terminationReason: "success", raw: raw)
                )
            }

            // recipeId check — fatal, no repair
            guard psDTO.baseRecipeId == request.recipeId else {
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: "This response doesn't match the current recipe. Please try again.",
                    raw: raw,
                    debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                    elapsed: nowMs() - startMs, networkMs: networkMs,
                                    repairUsed: context.repairUsed, error: .recipeIdMismatchFatal,
                                    terminationReason: "fatal_validation", raw: raw),
                    error: .recipeIdMismatchFatal
                )
            }

            // version check — expired, no repair
            guard psDTO.baseRecipeVersion == request.recipeVersion else {
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: "The recipe changed while I was thinking — please resend your message.",
                    raw: raw,
                    debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                    elapsed: nowMs() - startMs, networkMs: networkMs,
                                    repairUsed: context.repairUsed, error: .validationExpired,
                                    terminationReason: "expired_validation", raw: raw),
                    error: .validationExpired
                )
            }

            // DTO → Patch (UUID parse failures are recoverable)
            let patches: [Patch]
            do {
                patches = try psDTO.patches.map { try toPatch($0) }
            } catch {
                let sig = "validationRecoverable:INVALID_ID"
                if sig == context.lastFailureSignature {
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: "I referenced an ID that doesn't exist. Try rephrasing.",
                        raw: raw,
                        debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                        elapsed: nowMs() - startMs, networkMs: networkMs,
                                        repairUsed: context.repairUsed, error: .validationRecoverable,
                                        terminationReason: "repeat_failure", raw: raw),
                        error: .validationRecoverable
                    )
                }
                if context.repairUsed || context.totalCalls >= Self.maxCalls {
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: "I referenced an ID that doesn't exist. Try rephrasing.",
                        raw: raw,
                        debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                        elapsed: nowMs() - startMs, networkMs: networkMs,
                                        repairUsed: context.repairUsed, error: .validationRecoverable,
                                        terminationReason: "budget_exhausted", raw: raw),
                        error: .validationRecoverable
                    )
                }
                context.lastFailureSignature = sig
                let errDescs = [ErrorDescriptor(code: "INVALID_ID", message: "Could not parse one or more patch operation IDs")]
                return await repair(request: request, previousJSON: raw.rawText, errors: errDescs,
                                    requestId: requestId, startMs: startMs, context: &context)
            }

            let baseRecipeId = UUID(uuidString: psDTO.baseRecipeId) ?? UUID()
            let patchSetId = UUID(uuidString: psDTO.patchSetId) ?? UUID()
            let patchSet = PatchSet(
                patchSetId: patchSetId,
                baseRecipeId: baseRecipeId,
                baseRecipeVersion: psDTO.baseRecipeVersion,
                patches: patches,
                summary: psDTO.summary.map { [$0.title, $0.bullets?.joined(separator: "; ")].compactMap { $0 }.joined(separator: " — ") }
            )

            switch PatchValidator.validate(patchSet: patchSet, recipe: request.recipeSnapshotForPrompt) {
            case .valid:
                return .valid(
                    patchSet: patchSet,
                    assistantMessage: dto.assistantMessage,
                    raw: raw,
                    debug: makeDebug(.succeeded, outcome: "valid", attempts: attempts, id: requestId,
                                    elapsed: nowMs() - startMs, networkMs: networkMs,
                                    extractionUsed: extractionUsed, repairUsed: context.repairUsed,
                                    unknownKeys: unknownKeys, terminationReason: "success", raw: raw)
                )
            case .invalid(let validationErrors):
                let classified = classify(validationErrors)
                switch classified {
                case .validationFatal:
                    return .failure(
                        fallbackPatchSet: patchSet,
                        assistantMessage: "I can't modify steps you've already completed. Let me know how you'd like to proceed.",
                        raw: raw,
                        debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                        elapsed: nowMs() - startMs, networkMs: networkMs,
                                        repairUsed: context.repairUsed, error: .validationFatal,
                                        terminationReason: "fatal_validation", raw: raw),
                        error: .validationFatal
                    )
                case .validationExpired:
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: "The recipe changed while I was thinking — please resend your message.",
                        raw: raw,
                        debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                        elapsed: nowMs() - startMs, networkMs: networkMs,
                                        repairUsed: context.repairUsed, error: .validationExpired,
                                        terminationReason: "expired_validation", raw: raw),
                        error: .validationExpired
                    )
                default: // recoverable
                    let primaryReason = validationErrors.first.map { $0.code.rawValue } ?? "unknown"
                    let sig = "validationRecoverable:\(primaryReason)"
                    if sig == context.lastFailureSignature {
                        return .failure(
                            fallbackPatchSet: nil,
                            assistantMessage: "Something went wrong with my suggested changes. Try rephrasing your request.",
                            raw: raw,
                            debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                            elapsed: nowMs() - startMs, networkMs: networkMs,
                                            repairUsed: context.repairUsed, error: .validationRecoverable,
                                            terminationReason: "repeat_failure", raw: raw),
                            error: .validationRecoverable
                        )
                    }
                    if context.repairUsed || context.totalCalls >= Self.maxCalls {
                        return .failure(
                            fallbackPatchSet: nil,
                            assistantMessage: "Something went wrong with my suggested changes. Try rephrasing your request.",
                            raw: raw,
                            debug: makeDebug(.failed, outcome: "failure", attempts: attempts, id: requestId,
                                            elapsed: nowMs() - startMs, networkMs: networkMs,
                                            repairUsed: context.repairUsed, error: .validationRecoverable,
                                            terminationReason: "budget_exhausted", raw: raw),
                            error: .validationRecoverable
                        )
                    }
                    context.lastFailureSignature = sig
                    let errDescs = validationErrors.map {
                        ErrorDescriptor(code: $0.code.rawValue, message: String(describing: $0))
                    }
                    return await repair(request: request, previousJSON: raw.rawText, errors: errDescs,
                                        requestId: requestId, startMs: startMs, context: &context)
                }
            }
        }
    }

    // MARK: - Repair (one pass)

    private func repair(
        request: LLMRequest,
        previousJSON: String,
        errors: [ErrorDescriptor],
        requestId: String,
        startMs: Int,
        context: inout AttemptContext
    ) async -> LLMResult {
        context.repairUsed = true
        context.totalCalls += 1
        let repairRaw: LLMRawResponse
        let repairNetworkMs: Int
        do {
            let netStart = nowMs()
            repairRaw = try await client.send(LLMClientRequest(
                requestId: requestId + "-r",
                model: model,
                messages: buildRepairMessages(for: request, previousJSON: previousJSON, errors: errors),
                responseFormat: .jsonObject,
                timeout: timeout
            ))
            repairNetworkMs = nowMs() - netStart
        } catch {
            let llmErr = error as? LLMError ?? .network
            return .failure(
                fallbackPatchSet: nil,
                assistantMessage: assistantMessage(for: llmErr),
                raw: nil,
                debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                 id: requestId, elapsed: nowMs() - startMs,
                                 repairUsed: true, error: llmErr,
                                 terminationReason: "repair_network_error"),
                error: llmErr
            )
        }

        // Identical rawText — stop immediately, do not re-decode
        if repairRaw.rawText == previousJSON {
            return .failure(
                fallbackPatchSet: nil,
                assistantMessage: "Something went wrong with my suggested changes. Try rephrasing your request.",
                raw: repairRaw,
                debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                 id: requestId, elapsed: nowMs() - startMs,
                                 networkMs: repairNetworkMs, repairUsed: true,
                                 terminationReason: "repair_identical", raw: repairRaw),
                error: .validationRecoverable
            )
        }

        return await decodeAndValidate(
            raw: repairRaw, request: request,
            requestId: requestId, startMs: startMs, isRepair: true,
            networkMs: repairNetworkMs, context: &context
        )
    }

    // MARK: - Prompt Builders

    private func buildMessages(for request: LLMRequest) -> [LLMMessage] {
        var messages = [
            LLMMessage(role: .system, content: systemPrompt(hasCanvas: request.hasCanvas)),
            LLMMessage(role: .system, content: recipeContextMessage(for: request)),
        ]
        messages += request.conversationHistory
        messages.append(LLMMessage(role: .user, content: request.userMessage))
        return messages
    }

    private func buildRepairMessages(
        for request: LLMRequest,
        previousJSON: String,
        errors: [ErrorDescriptor]
    ) -> [LLMMessage] {
        let doneIds = request.recipeSnapshotForPrompt.steps
            .filter { $0.status == .done }
            .map { $0.id.uuidString }
            .joined(separator: ", ")

        let errLines = errors.isEmpty
            ? "(schema or decode error — re-emit valid JSON)"
            : errors.map { "• [\($0.code)] \($0.message)" }.joined(separator: "\n")

        let content = """
        Output JSON only. No markdown. No commentary.

        Fix the errors below and re-emit the JSON.

        Required:
        - baseRecipeId: "\(request.recipeId)"
        - baseRecipeVersion: \(request.recipeVersion)
        - Immutable done step IDs (never edit or remove): [\(doneIds)]

        Errors:
        \(errLines)

        Previous JSON:
        \(previousJSON)
        """
        // Include the conversation history so the repair model has full context
        // for what the user was asking (critical for multi-turn clarification replies).
        var messages = [
            LLMMessage(role: .system, content: systemPrompt(hasCanvas: request.hasCanvas)),
            LLMMessage(role: .system, content: recipeContextMessage(for: request)),
        ]
        messages += request.conversationHistory
        messages.append(LLMMessage(role: .user, content: content))
        return messages
    }

    // MARK: - Prompt Text

    private func systemPrompt(hasCanvas: Bool) -> String {
        if hasCanvas {
            return """
            You are Sous, a cooking companion who loves food and has strong opinions about it. A recipe is on the canvas and the user is working with it.

            Your voice: warm, direct, and helpful in the moment. When something goes sideways mid-cook, you don't fret — you figure out the best path forward and say so clearly. You make calls rather than listing every option with equal weight. Match the user's energy: calm and practical when they're stressed, curious and engaged when they're exploring.

            RULES — never violate:
            1. Never reprint the full recipe. The canvas is the source of truth.
            2. Output JSON only. No markdown. No code fences. No prose outside JSON.
            3. Never propose changes to any step with status "done".
            4. Handle vague, incomplete, or casual input gracefully. Don't ask the user to rephrase — read the intent, make a reasonable interpretation, and act on it. Only ask a question when you genuinely cannot proceed without one specific piece of information, and make that question feel natural, not like a form.
            5. Emit patchSet when the user's message implies a recipe change — including when they are answering a clarifying question you previously asked. If intent is still genuinely unclear after all context, ask one short natural question and emit patchSet: null.
            6. Equipment preferences in RECIPE CONTEXT are additive — assume standard home kitchen basics are always available. If no equipment is listed, assume a fully equipped standard home kitchen. Never restrict suggestions to only what's listed.

            Output shape — no changes:
            {"assistant_message":"...","patchSet":null}

            Output shape — with changes (patchSetId must be a new UUID you generate):
            {"assistant_message":"...","patchSet":{"patchSetId":"<new-uuid>","baseRecipeId":"<copy id from RECIPE CONTEXT>","baseRecipeVersion":<copy version from RECIPE CONTEXT>,"patches":[<operations>]}}

            Patch operations (exact "type" values; after_id / after_step_id are JSON null to append at end, or a UUID string to insert after that specific item):
            {"type":"set_title","title":"..."}
            {"type":"add_ingredient","text":"...","after_id":null}
            {"type":"update_ingredient","id":"<uuid>","text":"..."}
            {"type":"remove_ingredient","id":"<uuid>"}
            {"type":"add_step","text":"...","after_step_id":null}
            {"type":"update_step","id":"<uuid>","text":"..."}
            {"type":"remove_step","id":"<uuid>"}
            {"type":"add_note","text":"..."}
            """
        } else {
            return """
            You are Sous, a cooking companion who loves food and has strong opinions about it. No recipe canvas exists yet — you're helping the user figure out what to cook.

            Your voice: warm, direct, and a little opinionated. Make real recommendations rather than presenting every option with equal weight. If you think something is the right call, say so. Speak like a knowledgeable friend, not like a search results page or a form.

            RULES — never violate:
            1. Output JSON only. No markdown. No code fences. No prose outside JSON.
            2. Help the user land on something to cook. Ask at most 1–2 short questions if you genuinely need them, then offer 2–4 concrete options with brief "why this fits" notes. Have a lean — don't hedge everything. ALL text the user sees goes inside assistant_message only — never in any other JSON field.
            3. Handle vague, messy, or incomplete input gracefully. Don't ask the user to rephrase — read the intent, make a reasonable interpretation, and run with it.
            4. Do not generate a recipe until the user explicitly commits to a specific choice. Commit signals: "make that", "yes", "let's do it", "option 2", or selecting a number from a list you offered. If they say something ambiguous like "sure" or "ok", confirm which option they mean before generating.
            5. When the user commits: generate a full recipe using set_title, add_ingredient, and add_step patches. Use baseRecipeId and baseRecipeVersion from RECIPE CONTEXT. The canvas is blank — there are NO existing ingredients or steps. ALL add_ingredient patches MUST use "after_id": null. ALL add_step patches MUST use "after_step_id": null. Never put a UUID or any string in after_id or after_step_id — only null is valid here.
            6. When still exploring: emit patchSet: null.
            7. Equipment preferences in RECIPE CONTEXT are additive — assume standard home kitchen basics are always available. If no equipment is listed, assume a fully equipped standard home kitchen. Never restrict suggestions to only what's listed.

            Output shape — exploring:
            {"assistant_message":"...","patchSet":null}

            Output shape — creating recipe (patchSetId must be a new UUID you generate):
            {"assistant_message":"...","patchSet":{"patchSetId":"<new-uuid>","baseRecipeId":"<from RECIPE CONTEXT>","baseRecipeVersion":<from RECIPE CONTEXT>,"patches":[{"type":"set_title","title":"..."},{"type":"add_ingredient","text":"...","after_id":null},{"type":"add_step","text":"...","after_step_id":null}]}}

            Patch operations for recipe creation (blank canvas — always null for after_id and after_step_id):
            {"type":"set_title","title":"..."}
            {"type":"add_ingredient","text":"...","after_id":null}
            {"type":"add_step","text":"...","after_step_id":null}
            {"type":"add_note","text":"..."}
            """
        }
    }

    private func recipeContextMessage(for request: LLMRequest) -> String {
        let r = request.recipeSnapshotForPrompt
        let ingredients = r.ingredients
            .map { #"{"id":"\#($0.id.uuidString)","text":"\#($0.text)"}"# }
            .joined(separator: ",")
        let steps = r.steps
            .map { #"{"id":"\#($0.id.uuidString)","text":"\#($0.text)","status":"\#($0.status == .done ? "done" : "todo")"}"# }
            .joined(separator: ",")
        let doneIds = r.steps.filter { $0.status == .done }.map { $0.id.uuidString }.joined(separator: ", ")
        let prefs = request.userPrefs
        let avoids = prefs.hardAvoids.isEmpty ? "none" : prefs.hardAvoids.joined(separator: ", ")

        var lines = [
            "--- RECIPE CONTEXT ---",
            #"id: \#(request.recipeId)  version: \#(request.recipeVersion)  title: "\#(r.title)""#,
            "ingredients: [\(ingredients)]",
            "steps: [\(steps)]",
            "done step IDs (immutable): [\(doneIds)]",
            "hardAvoids: \(avoids)"
        ]

        if let serving = prefs.servingSize {
            lines.append("defaultServings: \(serving) people")
        }
        if !prefs.equipment.isEmpty {
            lines.append("equipment: \(prefs.equipment.joined(separator: ", ")) (additive context — assume standard home kitchen basics too; don't restrict suggestions to only what's listed)")
        }
        if !prefs.customInstructions.isEmpty {
            lines.append("customInstructions: \(prefs.customInstructions)")
        }

        if let decision = request.nextLLMContext?.lastPatchDecision {
            lines.append("last patch decision: id=\(decision.patchSetId) decision=\(decision.decision.rawValue)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - DTO → Patch

    private enum ConversionError: Error { case invalidUUID }

    private func toPatch(_ dto: LLMPatchOpDTO) throws -> Patch {
        func uuid(_ s: String) throws -> UUID {
            guard let u = UUID(uuidString: s) else { throw ConversionError.invalidUUID }
            return u
        }
        switch dto {
        case .addIngredient(let text, let afterIdStr):
            return .addIngredient(text: text, afterId: try afterIdStr.map { try uuid($0) })
        case .updateIngredient(let idStr, let text):
            return .updateIngredient(id: try uuid(idStr), text: text)
        case .removeIngredient(let idStr):
            return .removeIngredient(id: try uuid(idStr))
        case .addStep(let text, let afterStepIdStr):
            return .addStep(text: text, afterStepId: try afterStepIdStr.map { try uuid($0) })
        case .updateStep(let idStr, let text):
            return .updateStep(id: try uuid(idStr), text: text)
        case .removeStep(let idStr):
            return .removeStep(id: try uuid(idStr))
        case .addNote(let text):
            return .addNote(text: text)
        case .setTitle(let title):
            return .setTitle(title)
        }
    }

    // MARK: - Error Classification

    private func classify(_ errors: [PatchValidationError]) -> LLMError {
        for e in errors {
            switch e {
            case .stepDoneImmutable, .internalConflict: return .validationFatal
            default: break
            }
        }
        for e in errors {
            if case .versionMismatch = e { return .validationExpired }
        }
        return .validationRecoverable
    }

    private func describeDecodeFailure(_ df: DecodeFailure) -> String {
        switch df {
        case .decodeNonJSON:
            return "Response was not valid JSON — re-emit as valid JSON"
        case .decodeInvalidJSON:
            return "Response JSON had wrong field types — check all field types match the schema"
        case .schemaInvalid(let reason):
            switch reason {
            case .missingAssistantMessage:
                return "Missing required field: assistant_message (must be a string)"
            case .patchSetIdMissing:
                return "Missing required field: patchSet.patchSetId (generate a new UUID string)"
            case .baseRecipeIdMissing:
                return "Missing required field: patchSet.baseRecipeId (copy id from RECIPE CONTEXT)"
            case .baseRecipeVersionMissing:
                return "Missing required field: patchSet.baseRecipeVersion (copy version integer from RECIPE CONTEXT)"
            case .patchesMissing:
                return "Missing required field: patchSet.patches (must be a non-empty array)"
            case .patchesEmpty:
                return "patchSet.patches array is empty — include at least one patch operation"
            case .patchElementNotObject:
                return "A patches element is not a JSON object"
            case .patchOpMissingType:
                return "A patch operation is missing the required 'type' field"
            case .patchOpTypeNotString:
                return "A patch operation's 'type' field must be a string"
            case .patchOpUnknownType:
                return "A patch operation has an unrecognized 'type' value — use only documented types"
            case .patchOpMissingField:
                return "A patch operation is missing a required field for its type"
            }
        }
    }

    private func mapDecode(_ df: DecodeFailure) -> LLMError {
        switch df {
        case .decodeNonJSON: return .decodeNonJSON
        case .decodeInvalidJSON: return .decodeInvalidJSON
        case .schemaInvalid: return .schemaInvalid
        }
    }

    private func signatureForDecode(_ df: DecodeFailure) -> String {
        switch df {
        case .decodeNonJSON:    return "decode:nonJSON"
        case .decodeInvalidJSON: return "decode:invalidJSON"
        case .schemaInvalid:    return "decode:schemaInvalid"
        }
    }

    // MARK: - Debug Helpers

    private struct ErrorDescriptor {
        let code: String
        let message: String
    }

    private func nowMs() -> Int { Int(Date().timeIntervalSinceReferenceDate * 1000) }

    private func makeDebug(
        _ status: LLMDebugStatus,
        outcome: String,
        attempts: Int,
        id: String,
        elapsed: Int,
        networkMs: Int? = nil,
        extractionUsed: Bool = false,
        repairUsed: Bool = false,
        error: LLMError? = nil,
        unknownKeys: [String] = [],
        terminationReason: String = "unknown",
        raw: LLMRawResponse? = nil
    ) -> LLMDebugBundle {
        LLMDebugBundle(
            status: status,
            attemptCount: attempts,
            maxAttempts: Self.maxCalls,
            requestId: id,
            extractionUsed: extractionUsed,
            repairUsed: repairUsed,
            timingTotalMs: elapsed,
            timingNetworkMs: networkMs,
            lastErrorCategory: error,
            unknownKeysSeen: unknownKeys.isEmpty ? nil : unknownKeys,
            model: self.model,
            promptVersion: Self.promptVersion,
            outcome: outcome,
            failureCategory: failureCategoryString(error),
            terminationReason: terminationReason,
            promptTokens: raw?.promptTokens,
            completionTokens: raw?.completionTokens,
            totalTokens: raw?.totalTokens
        )
    }

    private func failureCategoryString(_ error: LLMError?) -> String? {
        guard let error else { return nil }
        switch error {
        case .missingAPIKey:                             return "missingAPIKey"
        case .network, .timeout, .cancelled:             return "network"
        case .rateLimited:                               return "rateLimited"
        case .auth:                                      return "auth"
        case .badRequest:                                return "badRequest"
        case .server:                                    return "server"
        case .decodeNonJSON, .decodeInvalidJSON:         return "decode"
        case .schemaInvalid:                             return "schema"
        case .validationFatal, .recipeIdMismatchFatal:   return "validationFatal"
        case .validationExpired:                         return "validationExpired"
        case .validationRecoverable:                     return "validationRecoverable"
        }
    }
}

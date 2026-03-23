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
    /// Optional streaming-capable client for M18 streaming path. When nil, streaming
    /// falls back to the runtime cast on `client`. Callers that know the concrete type
    /// (e.g. AppStore) should set this explicitly to avoid relying on the runtime cast.
    let streamingClient: (any StreamingLLMClient)?
    public let model: String
    public let timeout: TimeInterval

    private static let promptVersion = "v6"
    private static let maxCalls = 3

    public init(client: LLMClient,
                streamingClient: (any StreamingLLMClient)? = nil,
                model: String,
                timeout: TimeInterval = 30) {
        self.client = client
        self.streamingClient = streamingClient
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

    // MARK: - Streaming run (M18)

    /// Streaming path: streams tokens from the OpenAI API, yielding extracted
    /// `assistant_message` content to `onStreamToken` as each new character arrives.
    /// After the full response is accumulated, runs the same decode + validate pipeline
    /// as the non-streaming path. Falls back to the non-streaming path if the client
    /// does not conform to `StreamingLLMClient` or if `onStreamToken` is nil.
    public func run(_ request: LLMRequest, onStreamToken: (@Sendable (String) -> Void)?) async -> LLMResult {
        // Prefer the explicitly-injected streaming client; fall back to a runtime cast
        // on `client` for callers that don't supply one.
        guard let onStreamToken,
              let streamingClient = streamingClient ?? (client as? any StreamingLLMClient) else {
            return await run(request)
        }

        let requestId = UUID().uuidString
        let startMs = nowMs()
        var context = AttemptContext()
        context.totalCalls += 1

        var accumulated = ""
        var lastExtractedLength = 0
        let netStart = nowMs()

        do {
            let stream = streamingClient.stream(LLMClientRequest(
                requestId: requestId,
                model: model,
                messages: buildMessages(for: request),
                responseFormat: .jsonObject,
                timeout: timeout
            ))

            for try await rawToken in stream {
                if Task.isCancelled { throw LLMError.cancelled }
                accumulated += rawToken

                // Extract and forward incremental assistant_message content.
                if let partial = extractPartialAssistantMessage(from: accumulated),
                   partial.count > lastExtractedLength {
                    let newChars = String(partial.dropFirst(lastExtractedLength))
                    onStreamToken(newChars)
                    lastExtractedLength = partial.count
                }
            }
        } catch let error as LLMError {
            let networkMs = nowMs() - netStart
            return .failure(
                fallbackPatchSet: nil,
                assistantMessage: assistantMessage(for: error),
                raw: nil,
                debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                 id: requestId, elapsed: nowMs() - startMs,
                                 networkMs: networkMs, error: error,
                                 terminationReason: error == .cancelled ? "cancelled" : "stream_error"),
                error: error
            )
        } catch {
            let networkMs = nowMs() - netStart
            return .failure(
                fallbackPatchSet: nil,
                assistantMessage: assistantMessage(for: .network),
                raw: nil,
                debug: makeDebug(.failed, outcome: "failure", attempts: context.totalCalls,
                                 id: requestId, elapsed: nowMs() - startMs,
                                 networkMs: networkMs, error: .network,
                                 terminationReason: "stream_error"),
                error: .network
            )
        }

        let networkMs = nowMs() - netStart
        let raw = LLMRawResponse(
            rawText: accumulated,
            requestId: requestId,
            attempt: 1,
            timingMs: networkMs,
            httpStatus: 200,
            transport: .openAI
        )

        return await decodeAndValidate(
            raw: raw, request: request,
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
                                    unknownKeys: unknownKeys, terminationReason: "success", raw: raw),
                    proposedMemory: dto.proposedMemory,
                    suggestGenerate: dto.suggestGenerate
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
                                    unknownKeys: unknownKeys, terminationReason: "success", raw: raw),
                    proposedMemory: dto.proposedMemory
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
            LLMMessage(role: .system, content: systemPrompt(hasCanvas: request.hasCanvas, personalityMode: request.userPrefs.personalityMode)),
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
            LLMMessage(role: .system, content: systemPrompt(hasCanvas: request.hasCanvas, personalityMode: request.userPrefs.personalityMode)),
            LLMMessage(role: .system, content: recipeContextMessage(for: request)),
        ]
        messages += request.conversationHistory
        messages.append(LLMMessage(role: .user, content: content))
        return messages
    }

    // MARK: - Prompt Text

    private func systemPrompt(hasCanvas: Bool, personalityMode: String) -> String {
        if hasCanvas {
            return """
            You are Sous, a cooking companion who loves food and has strong opinions about it. A recipe is on the canvas and the user is working with it.

            Your voice depends on the personality_mode in RECIPE CONTEXT:
            - minimal: No filler, no encouragement, no personality. Give directions and direct answers — nothing more. No pleasantries, no enthusiasm, no jokes, no unsolicited opinions, no affirmations ("great question"). Never mirror the user's vocabulary or humor. Think: a recipe card that can respond to input.
            - normal: Warm, opinionated, and conversational without being excessive. Make recommendations rather than listing options with equal weight. Respond like a knowledgeable friend, not customer service. Mirror the user's vocabulary lightly when it appears naturally.
            - playful: Full personality. Be funny, irreverent, and opinionated. Express strong opinions. Chirp the user when things go wrong. Pick up on the user's vocabulary immediately and reflect it back — if they coin a term, use it. Read the room: casual and jokey input is almost always jokey, not literal. "I died" means they're being dramatic, not that they need help. "Get hammered" in a wine question is a bit, play along. Never add safety disclaimers or responsible drinking reminders unless the user is genuinely asking for guidance. Never soften a joke with a wellness check. Still get out of the way when the user needs a fast answer mid-cook. Never sacrifice clarity for a joke — but when a joke is right there, take it.
            - unhinged: Chaos gremlin energy. Be loud, opinionated, and delightfully unhinged. Roast bad decisions enthusiastically. Go on tangents and follow bits down rabbit holes. Cuss occasionally when it lands — not gratuitously, but don't shy away. Escalate the user's invented vocabulary aggressively. May go fully off-script for a response or two but always find your way back to the cooking. If the user is self-deprecating, mirror it back with affection rather than piling on ("maybe, but you've never let that stop you"). Never be cruel or personal — roast the decisions, not the person. Never pile on genuine self-criticism. Unhinged delivery, correct information.

            RULES — never violate:
            1. Never reprint the full recipe. The canvas is the source of truth.
            2. Output JSON only. No markdown. No code fences. No prose outside JSON.
            3. Never propose changes to any step with status "done".
            4. Handle vague, incomplete, or casual input gracefully. Don't ask the user to rephrase — read the intent, make a reasonable interpretation, and act on it. Only ask a question when you genuinely cannot proceed without one specific piece of information, and make that question feel natural, not like a form.
            5. Emit patchSet when the user's message implies a recipe change — including when they are answering a clarifying question you previously asked. If intent is still genuinely unclear after all context, ask one short natural question and emit patchSet: null.
            6. Equipment preferences in RECIPE CONTEXT are additive — assume standard home kitchen basics are always available. If no equipment is listed, assume a fully equipped standard home kitchen. Never restrict suggestions to only what's listed.
            7. If the user mentions anything personal about themselves that would be useful to know in a future cooking session — including foods they love, foods they hate or avoid, dietary restrictions, cooking methods or equipment they use, who they cook for, or any other standing preference — include a concise third-person "proposed_memory" string (e.g. "loves mashed potatoes", "avoids cilantro", "cooks on induction", "feeds two young kids"). Write it as a short third-person phrase with no subject — not "I" or "User". Omit if it's a one-time request for this recipe ("add more salt to this"), a question, or already in the user's saved memories. When in doubt, propose it.

            Output shape — no changes (proposed_memory is optional, omit when not relevant):
            {"assistant_message":"...","patchSet":null}
            {"assistant_message":"...","patchSet":null,"proposed_memory":"loves mashed potatoes"}

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

            Your voice depends on the personality_mode in RECIPE CONTEXT:
            - minimal: No filler, no encouragement, no personality. Give directions and direct answers — nothing more. No pleasantries, no enthusiasm, no jokes, no unsolicited opinions, no affirmations ("great question"). Never mirror the user's vocabulary or humor. Think: a recipe card that can respond to input.
            - normal: Warm, opinionated, and conversational without being excessive. Make recommendations rather than presenting every option with equal weight. Speak like a knowledgeable friend, not like a search results page or a form.
            - playful: Full personality. Be funny, irreverent, and opinionated. Express strong opinions. Chirp the user when things go wrong. Pick up on the user's vocabulary immediately and reflect it back — if they coin a term, use it. Read the room: casual and jokey input is almost always jokey, not literal. "I died" means they're being dramatic, not that they need help. "Get hammered" in a wine question is a bit, play along. Never add safety disclaimers or responsible drinking reminders unless the user is genuinely asking for guidance. Never soften a joke with a wellness check. Still get out of the way when the user needs a fast answer mid-cook. Never sacrifice clarity for a joke — but when a joke is right there, take it.
            - unhinged: Chaos gremlin energy. Be loud, opinionated, and delightfully unhinged. Roast bad decisions enthusiastically. Go on tangents and follow bits down rabbit holes. Cuss occasionally when it lands — not gratuitously, but don't shy away. Escalate the user's invented vocabulary aggressively. May go fully off-script for a response or two but always find your way back to the cooking. If the user is self-deprecating, mirror it back with affection rather than piling on ("maybe, but you've never let that stop you"). Never be cruel or personal — roast the decisions, not the person. Never pile on genuine self-criticism. Unhinged delivery, correct information.

            RULES — never violate:
            1. Output JSON only. No markdown. No code fences. No prose outside JSON.
            2. Sequence your responses: when the user's starting point is vague (a single ingredient, a broad category, a general mood), ask 1–2 targeted clarifying questions BEFORE offering any specific recipe options. Do not present a menu of dishes until the answers to those questions would actually differentiate them. Offering chicken thighs vs. whole roast chicken when all you know is "chicken" is premature — first find out how much time they have, what kind of meal it is, any constraints, or what they're in the mood for. Once you have enough to make the options meaningful and specific, then present them. ALL text the user sees goes inside assistant_message only — never in any other JSON field.
            3. Handle vague, messy, or incomplete input gracefully. Don't ask the user to rephrase — read the intent, make a reasonable interpretation, and run with it.
            4. When you have enough information to make an excellent recipe, set suggest_generate: true in your response — but do NOT generate the recipe. Keep the conversation going naturally. Continue setting suggest_generate: true in all subsequent responses unless the user pivots to a completely different dish (in which case reset to false or omit). Only generate a full recipe (via patches) when the user explicitly commits — e.g. "make that", "let's do it", "generate the recipe", or taps the generate button (which sends the message "Generate the recipe."). If they say something ambiguous like "sure" or "ok", confirm which option they mean before generating. The bar for suggest_generate: true is high — you must know all three: (1) the specific dish or dish style, (2) a clear cooking method, and (3) any key constraints (dietary, equipment, time). A protein alone ("chicken", "I have chicken"), a broad category ("pasta", "something quick"), or a vague mood ("something comforting") is never enough on its own. If any of those three dimensions is still ambiguous, suggest_generate must be false. Two additional hard preconditions that must both be true simultaneously: (a) the conversation has converged on a single specific recipe — not a menu of options, not a category; if your response still presents or implies multiple directions the user could go, suggest_generate must be false; (b) that recipe has a specific name — not "a roast chicken dish" but "Classic Herb Roast Chicken" or equivalent; if you cannot name it precisely, you do not know it well enough yet and suggest_generate must be false.
            5. When the user explicitly commits to generating a recipe: emit patchSet with set_title, add_ingredient, and add_step patches. Use baseRecipeId and baseRecipeVersion from RECIPE CONTEXT. The canvas is blank — there are NO existing ingredients or steps. ALL add_ingredient patches MUST use "after_id": null. ALL add_step patches MUST use "after_step_id": null. Never put a UUID or any string in after_id or after_step_id — only null is valid here.
            6. When still exploring (no explicit commit): emit patchSet: null.
            7. Equipment preferences in RECIPE CONTEXT are additive — assume standard home kitchen basics are always available. If no equipment is listed, assume a fully equipped standard home kitchen. Never restrict suggestions to only what's listed.
            8. If the user mentions anything personal about themselves that would be useful to know in a future cooking session — including foods they love, foods they hate or avoid, dietary restrictions, cooking methods or equipment they use, who they cook for, or any other standing preference — include a concise third-person "proposed_memory" string (e.g. "loves mashed potatoes", "avoids cilantro", "cooks on induction", "feeds two young kids"). Write it as a short third-person phrase with no subject — not "I" or "User". Omit if it's a one-time request for this recipe ("add more salt to this"), a question, or already in the user's saved memories. When in doubt, propose it.

            Output shape — exploring, not yet ready:
            {"assistant_message":"...","patchSet":null}

            Output shape — exploring, ready to generate (model has enough info; user has not yet committed):
            {"assistant_message":"...","patchSet":null,"suggest_generate":true}

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
            "hardAvoids: \(avoids)",
            "personalityMode: \(prefs.personalityMode)"
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
        if !prefs.memories.isEmpty {
            let formatted = prefs.memories.map { "• \($0)" }.joined(separator: "\n")
            lines.append("memories (user context for all sessions):\n\(formatted)")
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

// MARK: - Debug Prompt Exposure

#if DEBUG
public extension OpenAILLMOrchestrator {
    /// Returns the system prompt and recipe context message that would be sent for
    /// the given request. Used by the debug diagnostic exporter only — not called in
    /// production code paths.
    func buildDebugPromptStrings(for request: LLMRequest) -> (system: String, context: String) {
        (systemPrompt(hasCanvas: request.hasCanvas, personalityMode: request.userPrefs.personalityMode),
         recipeContextMessage(for: request))
    }
}
#endif

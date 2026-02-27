import Foundation

// MARK: - OpenAILLMOrchestrator

/// Concrete LLMOrchestrator for OpenAI-compatible transports.
/// Owns prompt construction, decode, validation, and a single repair pass.
/// Never mutates Recipe State.
public struct OpenAILLMOrchestrator: LLMOrchestrator {

    public let client: LLMClient
    public let model: String
    public let timeout: TimeInterval

    public init(client: LLMClient, model: String, timeout: TimeInterval = 30) {
        self.client = client
        self.model = model
        self.timeout = timeout
    }

    // MARK: - LLMOrchestrator

    public func run(_ request: LLMRequest) async -> LLMResult {
        let requestId = UUID().uuidString
        let startMs = nowMs()

        let raw: LLMRawResponse
        do {
            raw = try await client.send(LLMClientRequest(
                requestId: requestId,
                model: model,
                messages: buildMessages(for: request),
                responseFormat: .jsonObject,
                timeout: timeout
            ))
        } catch {
            return .failure(
                fallbackPatchSet: nil,
                assistantMessage: "Network error. Please try again.",
                raw: nil,
                debug: makeDebug(.failed, attempts: 1, id: requestId, elapsed: nowMs() - startMs, error: .network),
                error: .network
            )
        }

        return await decodeAndValidate(
            raw: raw, request: request,
            requestId: requestId, startMs: startMs, isRepair: false
        )
    }

    // MARK: - Decode + Validate

    private func decodeAndValidate(
        raw: LLMRawResponse,
        request: LLMRequest,
        requestId: String,
        startMs: Int,
        isRepair: Bool
    ) async -> LLMResult {

        let attempts = isRepair ? 2 : 1
        let decodeResult = PatchSetDecoder().decode(raw.rawText)

        switch decodeResult {
        case .failure(let df):
            if isRepair {
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: "I had trouble formatting my response. Please try rephrasing.",
                    raw: raw,
                    debug: makeDebug(.failed, attempts: attempts, id: requestId, elapsed: nowMs() - startMs,
                                    repairUsed: true, error: mapDecode(df)),
                    error: mapDecode(df)
                )
            }
            return await repair(
                request: request, previousJSON: raw.rawText, errors: [],
                requestId: requestId, startMs: startMs
            )

        case .success(let dto, let extractionUsed, let unknownKeys):
            guard let psDTO = dto.patchSet else {
                return .noPatches(
                    assistantMessage: dto.assistantMessage,
                    raw: raw,
                    debug: makeDebug(.succeeded, attempts: attempts, id: requestId,
                                    elapsed: nowMs() - startMs, extractionUsed: extractionUsed,
                                    repairUsed: isRepair, unknownKeys: unknownKeys)
                )
            }

            // recipeId check — fatal, no repair
            guard psDTO.baseRecipeId == request.recipeId else {
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: "This response doesn't match the current recipe. Please try again.",
                    raw: raw,
                    debug: makeDebug(.failed, attempts: attempts, id: requestId, elapsed: nowMs() - startMs,
                                    repairUsed: isRepair, error: .recipeIdMismatchFatal),
                    error: .recipeIdMismatchFatal
                )
            }

            // version check — expired, no repair
            guard psDTO.baseRecipeVersion == request.recipeVersion else {
                return .failure(
                    fallbackPatchSet: nil,
                    assistantMessage: "The recipe changed while I was thinking — please resend your message.",
                    raw: raw,
                    debug: makeDebug(.failed, attempts: attempts, id: requestId, elapsed: nowMs() - startMs,
                                    repairUsed: isRepair, error: .validationExpired),
                    error: .validationExpired
                )
            }

            // DTO → Patch (UUID parse failures are recoverable)
            let patches: [Patch]
            do {
                patches = try psDTO.patches.map { try toPatch($0) }
            } catch {
                if isRepair {
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: "I referenced an ID that doesn't exist. Try rephrasing.",
                        raw: raw,
                        debug: makeDebug(.failed, attempts: attempts, id: requestId, elapsed: nowMs() - startMs,
                                        repairUsed: true, error: .validationRecoverable),
                        error: .validationRecoverable
                    )
                }
                let errDescs = [ErrorDescriptor(code: "INVALID_ID", message: "Could not parse one or more patch operation IDs")]
                return await repair(request: request, previousJSON: raw.rawText, errors: errDescs,
                                    requestId: requestId, startMs: startMs)
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
                    debug: makeDebug(.succeeded, attempts: attempts, id: requestId,
                                    elapsed: nowMs() - startMs, extractionUsed: extractionUsed,
                                    repairUsed: isRepair, unknownKeys: unknownKeys)
                )
            case .invalid(let validationErrors):
                let classified = classify(validationErrors)
                switch classified {
                case .validationFatal:
                    return .failure(
                        fallbackPatchSet: patchSet,
                        assistantMessage: "I can't modify steps you've already completed. Let me know how you'd like to proceed.",
                        raw: raw,
                        debug: makeDebug(.failed, attempts: attempts, id: requestId, elapsed: nowMs() - startMs,
                                        repairUsed: isRepair, error: .validationFatal),
                        error: .validationFatal
                    )
                case .validationExpired:
                    return .failure(
                        fallbackPatchSet: nil,
                        assistantMessage: "The recipe changed while I was thinking — please resend your message.",
                        raw: raw,
                        debug: makeDebug(.failed, attempts: attempts, id: requestId, elapsed: nowMs() - startMs,
                                        repairUsed: isRepair, error: .validationExpired),
                        error: .validationExpired
                    )
                default: // recoverable
                    if isRepair {
                        return .failure(
                            fallbackPatchSet: nil,
                            assistantMessage: "Something went wrong with my suggested changes. Try rephrasing your request.",
                            raw: raw,
                            debug: makeDebug(.failed, attempts: attempts, id: requestId, elapsed: nowMs() - startMs,
                                            repairUsed: true, error: .validationRecoverable),
                            error: .validationRecoverable
                        )
                    }
                    let errDescs = validationErrors.map {
                        ErrorDescriptor(code: $0.code.rawValue, message: String(describing: $0))
                    }
                    return await repair(request: request, previousJSON: raw.rawText, errors: errDescs,
                                        requestId: requestId, startMs: startMs)
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
        startMs: Int
    ) async -> LLMResult {
        let repairRaw: LLMRawResponse
        do {
            repairRaw = try await client.send(LLMClientRequest(
                requestId: requestId + "-r",
                model: model,
                messages: buildRepairMessages(for: request, previousJSON: previousJSON, errors: errors),
                responseFormat: .jsonObject,
                timeout: timeout
            ))
        } catch {
            return .failure(
                fallbackPatchSet: nil,
                assistantMessage: "Network error. Please try again.",
                raw: nil,
                debug: makeDebug(.failed, attempts: 2, id: requestId, elapsed: nowMs() - startMs,
                                 repairUsed: true, error: .network),
                error: .network
            )
        }
        return await decodeAndValidate(
            raw: repairRaw, request: request,
            requestId: requestId, startMs: startMs, isRepair: true
        )
    }

    // MARK: - Prompt Builders

    private func buildMessages(for request: LLMRequest) -> [LLMMessage] {
        [
            LLMMessage(role: .system, content: systemPrompt(hasCanvas: request.hasCanvas)),
            LLMMessage(role: .system, content: recipeContextMessage(for: request)),
            LLMMessage(role: .user, content: request.userMessage)
        ]
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
        return [
            LLMMessage(role: .system, content: systemPrompt(hasCanvas: request.hasCanvas)),
            LLMMessage(role: .system, content: recipeContextMessage(for: request)),
            LLMMessage(role: .user, content: content)
        ]
    }

    // MARK: - Prompt Text

    private func systemPrompt(hasCanvas: Bool) -> String {
        if hasCanvas {
            return """
            You are Sous, an AI cooking assistant. A recipe canvas exists.

            RULES — never violate:
            1. Never reprint the full recipe. The canvas is the source of truth.
            2. Output JSON only. No markdown. No code fences. No prose outside JSON.
            3. Never propose changes to any step with status "done".
            4. Emit patchSet when the user's message implies a recipe change. If intent is ambiguous, ask a clarifying question and emit patchSet: null.

            Output shape:
            {"assistant_message":"<short reply>","patchSet":{...}|null}

            Patch operation types (exact "type" values):
            {"type":"add_ingredient","text":"...","after_id":"<uuid>|null"}
            {"type":"update_ingredient","id":"<uuid>","text":"..."}
            {"type":"remove_ingredient","id":"<uuid>"}
            {"type":"add_step","text":"...","after_step_id":"<uuid>|null"}
            {"type":"update_step","id":"<uuid>","text":"..."}
            {"type":"remove_step","id":"<uuid>"}
            {"type":"add_note","text":"..."}
            """
        } else {
            return """
            You are Sous, an AI cooking assistant. No recipe exists yet.

            RULES:
            1. Output JSON only. No markdown. No code fences. No prose outside JSON.
            2. Help the user decide what to cook. Ask 1-2 focused questions and suggest 2-3 options.
            3. Do not generate a recipe until the user explicitly commits to a specific choice.
            4. Always emit patchSet: null.

            Output shape: {"assistant_message":"<reply>","patchSet":null}
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
        let avoids = request.userPrefs.hardAvoids.isEmpty ? "none" : request.userPrefs.hardAvoids.joined(separator: ", ")

        var lines = [
            "--- RECIPE CONTEXT ---",
            #"id: \#(request.recipeId)  version: \#(request.recipeVersion)  title: "\#(r.title)""#,
            "ingredients: [\(ingredients)]",
            "steps: [\(steps)]",
            "done step IDs (immutable): [\(doneIds)]",
            "hardAvoids: \(avoids)"
        ]

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

    private func mapDecode(_ df: DecodeFailure) -> LLMError {
        switch df {
        case .decodeNonJSON: return .decodeNonJSON
        case .decodeInvalidJSON: return .decodeInvalidJSON
        case .schemaInvalid: return .schemaInvalid
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
        attempts: Int,
        id: String,
        elapsed: Int,
        extractionUsed: Bool = false,
        repairUsed: Bool = false,
        error: LLMError? = nil,
        unknownKeys: [String] = []
    ) -> LLMDebugBundle {
        LLMDebugBundle(
            status: status,
            attemptCount: attempts,
            maxAttempts: 2,
            requestId: id,
            extractionUsed: extractionUsed,
            repairUsed: repairUsed,
            timingTotalMs: elapsed,
            lastErrorCategory: error,
            unknownKeysSeen: unknownKeys.isEmpty ? nil : unknownKeys
        )
    }
}

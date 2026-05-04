import Foundation

// MARK: - SchemaFailureReason

/// Specific reason a structurally valid JSON object failed schema validation.
/// Cases are mutually exclusive and checked in document order.
enum SchemaFailureReason: String, Equatable, CaseIterable, Sendable {
    case missingAssistantMessage    // "assistant_message" key absent
    case patchSetIdMissing          // patchSet.patchSetId absent
    case baseRecipeIdMissing        // patchSet.baseRecipeId absent
    case baseRecipeVersionMissing   // patchSet.baseRecipeVersion absent
    case patchesMissing             // patchSet.patches key absent
    case patchesEmpty               // patchSet.patches present but []
    case patchElementNotObject      // patches contains a non-object element
    case patchOpMissingType         // a patch object has no "type" key
    case patchOpTypeNotString       // a patch object's "type" value is not a String
    case patchOpUnknownType         // a patch object has a "type" value that is not a known op
    case patchOpMissingField        // a required field for the identified op type is absent or wrong type
}

// MARK: - DecodeFailure

/// Error returned when PatchSetDecoder cannot produce a valid LLMResponseDTO.
///
/// Bucket semantics:
/// - `decodeNonJSON`    — JSONSerialization.jsonObject() throws; text is not parseable JSON.
/// - `decodeInvalidJSON` — JSON parses, but the root value is not an object, or an
///                         expected-object field has the wrong container type (e.g. patchSet
///                         is a string), or a required scalar has the wrong Swift type.
/// - `schemaInvalid`    — Root is a correctly shaped JSON object hierarchy, but a required
///                         key is absent or a value constraint is violated.
enum DecodeFailure: Equatable, Sendable {
    case decodeNonJSON
    case decodeInvalidJSON
    case schemaInvalid(SchemaFailureReason)
}

// MARK: - DecodeResult

enum DecodeResult: Equatable, Sendable {
    /// Decode succeeded. `unknownKeys` is the merged set of unexpected keys seen at the
    /// top-level envelope and patchSet levels; may be empty. Never affects success/failure.
    case success(dto: LLMResponseDTO, extractionUsed: Bool, unknownKeys: [String])
    case failure(DecodeFailure)
}

// MARK: - PatchSetDecoder

/// Pure, deterministic decoder for the LLM response envelope.
///
/// Two-path strategy:
///   A) Strict: attempt to parse the entire raw string as JSON.
///   B) Extraction (bounded, once): if strict fails due to `notJSON` or `invalidJSON`,
///      locate the first balanced `{…}` substring and retry.
///
/// `schemaInvalid` failures short-circuit immediately — extraction cannot fix missing
/// required keys in an otherwise well-formed JSON object.
struct PatchSetDecoder: Sendable {

    func decode(_ raw: String) -> DecodeResult {
        guard let data = raw.data(using: .utf8) else {
            return .failure(.decodeNonJSON)
        }

        switch attemptDecode(data: data) {
        case .success(let dto, let keys):
            return .success(dto: dto, extractionUsed: false, unknownKeys: keys)
        case .schemaInvalid(let reason):
            // Schema failures are definitive; extraction cannot add missing required fields.
            return .failure(.schemaInvalid(reason))
        case .notJSON, .invalidJSON:
            break // fall through to extraction
        }

        // B) One-time extraction
        guard let extracted = extractJSONSubstring(from: raw),
              let extractedData = extracted.data(using: .utf8) else {
            return .failure(.decodeNonJSON)
        }

        switch attemptDecode(data: extractedData) {
        case .success(let dto, let keys):
            return .success(dto: dto, extractionUsed: true, unknownKeys: keys)
        case .schemaInvalid(let reason):
            return .failure(.schemaInvalid(reason))
        case .invalidJSON:
            return .failure(.decodeInvalidJSON)
        case .notJSON:
            return .failure(.decodeNonJSON)
        }
    }

    // MARK: - Private Types

    private enum AttemptResult {
        case success(LLMResponseDTO, unknownKeys: [String])
        /// JSONSerialization.jsonObject() threw — input is not valid JSON.
        case notJSON
        /// JSON parsed, but root value or a container field has the wrong type.
        case invalidJSON
        case schemaInvalid(SchemaFailureReason)
    }

    private enum PSBuildResult {
        case success(LLMPatchSetDTO, unknownKeys: [String])
        case invalidJSON
        case schemaInvalid(SchemaFailureReason)
    }

    // MARK: - Decode Helpers

    private func attemptDecode(data: Data) -> AttemptResult {
        guard let rawValue = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return .notJSON
        }
        guard let root = rawValue as? [String: Any] else {
            // Root is a JSON array, string, number, bool, or null — not an object.
            return .invalidJSON
        }
        return buildDTO(from: root)
    }

    private func buildDTO(from root: [String: Any]) -> AttemptResult {
        let knownTopKeys: Set<String> = ["assistant_message", "patchSet", "proposed_memory", "suggest_generate"]
        let unknownTopKeys = root.keys.filter { !knownTopKeys.contains($0) }.sorted()

        // assistant_message: required, must be a String
        guard let amRaw = root["assistant_message"] else {
            return .schemaInvalid(.missingAssistantMessage)
        }
        guard let assistantMessage = amRaw as? String else {
            return .invalidJSON
        }

        // patchSet: optional; null and absent both mean no patch proposal
        var patchSetDTO: LLMPatchSetDTO? = nil
        var unknownPatchSetKeys: [String] = []

        if let psRaw = root["patchSet"], !(psRaw is NSNull) {
            // patchSet is present and non-null; must be a JSON object
            guard let psObj = psRaw as? [String: Any] else {
                return .invalidJSON
            }
            switch buildPatchSetDTO(from: psObj) {
            case .success(let ps, let keys):
                patchSetDTO = ps
                unknownPatchSetKeys = keys
            case .invalidJSON:
                return .invalidJSON
            case .schemaInvalid(let reason):
                return .schemaInvalid(reason)
            }
        }

        let proposedMemory = root["proposed_memory"] as? String
        let suggestGenerate = root["suggest_generate"] as? Bool
        let dto = LLMResponseDTO(assistantMessage: assistantMessage, patchSet: patchSetDTO, proposedMemory: proposedMemory, suggestGenerate: suggestGenerate)
        let merged = (unknownTopKeys + unknownPatchSetKeys).sorted()
        return .success(dto, unknownKeys: merged)
    }

    private func buildPatchSetDTO(from psObj: [String: Any]) -> PSBuildResult {
        let knownPSKeys: Set<String> = [
            "patchSetId", "baseRecipeId", "baseRecipeVersion", "patches", "summary"
        ]
        let unknownPSKeys = psObj.keys.filter { !knownPSKeys.contains($0) }.sorted()

        // patchSetId
        guard let patchSetIdRaw = psObj["patchSetId"] else {
            return .schemaInvalid(.patchSetIdMissing)
        }
        guard let patchSetId = patchSetIdRaw as? String else { return .invalidJSON }

        // baseRecipeId
        guard let baseRecipeIdRaw = psObj["baseRecipeId"] else {
            return .schemaInvalid(.baseRecipeIdMissing)
        }
        guard let baseRecipeId = baseRecipeIdRaw as? String else { return .invalidJSON }

        // baseRecipeVersion
        guard let baseRecipeVersionRaw = psObj["baseRecipeVersion"] else {
            return .schemaInvalid(.baseRecipeVersionMissing)
        }
        guard let baseRecipeVersion = baseRecipeVersionRaw as? Int else { return .invalidJSON }

        // patches: required, non-empty array of JSON objects
        guard let patchesRaw = psObj["patches"] else {
            return .schemaInvalid(.patchesMissing)
        }
        guard let patchesArr = patchesRaw as? [Any] else {
            // patches is present but not an array
            return .invalidJSON
        }
        guard !patchesArr.isEmpty else {
            return .schemaInvalid(.patchesEmpty)
        }
        var patches: [LLMPatchOpDTO] = []
        for element in patchesArr {
            guard let obj = element as? [String: Any] else {
                return .schemaInvalid(.patchElementNotObject)
            }
            guard let typeRaw = obj["type"] else {
                return .schemaInvalid(.patchOpMissingType)
            }
            guard let typeStr = typeRaw as? String else {
                return .schemaInvalid(.patchOpTypeNotString)
            }
            switch typeStr {
            case "add_ingredient":
                guard let text = obj["text"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.addIngredient(text: text, afterId: obj["after_id"] as? String, groupId: obj["group_id"] as? String))
            case "update_ingredient":
                guard let id = obj["id"] as? String, let text = obj["text"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.updateIngredient(id: id, text: text))
            case "remove_ingredient":
                guard let id = obj["id"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.removeIngredient(id: id))
            case "add_ingredient_group":
                patches.append(.addIngredientGroup(afterGroupId: obj["after_group_id"] as? String, header: obj["header"] as? String, clientId: obj["client_id"] as? String))
            case "update_ingredient_group":
                guard let id = obj["id"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.updateIngredientGroup(id: id, header: obj["header"] as? String))
            case "remove_ingredient_group":
                guard let id = obj["id"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.removeIngredientGroup(id: id))
            case "add_step":
                guard let text = obj["text"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.addStep(text: text, afterId: obj["after_id"] as? String, parentId: obj["parent_id"] as? String, clientId: obj["client_id"] as? String))
            case "update_step":
                guard let id = obj["id"] as? String, let text = obj["text"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.updateStep(id: id, text: text))
            case "remove_step":
                guard let id = obj["id"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.removeStep(id: id))
            case "set_title":
                guard let title = obj["title"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.setTitle(title: title))
            case "set_step_notes":
                guard let stepId = obj["step_id"] as? String,
                      let notes = obj["notes"] as? [String] else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.setStepNotes(stepId: stepId, notes: notes))
            case "add_note_section":
                guard let items = obj["items"] as? [String] else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.addNoteSection(afterId: obj["after_id"] as? String, header: obj["header"] as? String, items: items))
            case "update_note_section":
                guard let id = obj["id"] as? String,
                      let items = obj["items"] as? [String] else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.updateNoteSection(id: id, header: obj["header"] as? String, items: items))
            case "remove_note_section":
                guard let id = obj["id"] as? String else { return .schemaInvalid(.patchOpMissingField) }
                patches.append(.removeNoteSection(id: id))
            default:
                return .schemaInvalid(.patchOpUnknownType)
            }
        }

        // summary: optional; wrong type is silently ignored (not a required field)
        var summary: LLMSummaryDTO? = nil
        if let summaryRaw = psObj["summary"],
           !(summaryRaw is NSNull),
           let summaryObj = summaryRaw as? [String: Any] {
            summary = LLMSummaryDTO(
                title: summaryObj["title"] as? String,
                bullets: summaryObj["bullets"] as? [String]
            )
        }

        let ps = LLMPatchSetDTO(
            patchSetId: patchSetId,
            baseRecipeId: baseRecipeId,
            baseRecipeVersion: baseRecipeVersion,
            patches: patches,
            summary: summary
        )
        return .success(ps, unknownKeys: unknownPSKeys)
    }

    // MARK: - JSON Substring Extraction

    /// Finds the first balanced `{…}` in `raw` using brace-counting.
    /// Respects JSON string boundaries and backslash escapes so that
    /// braces inside string values are not mistaken for object delimiters.
    private func extractJSONSubstring(from raw: String) -> String? {
        guard let startIndex = raw.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escapeNext = false
        var endIndex: String.Index? = nil

        for idx in raw[startIndex...].indices {
            let ch = raw[idx]

            if escapeNext {
                escapeNext = false
                continue
            }
            if ch == "\\" && inString {
                escapeNext = true
                continue
            }
            if ch == "\"" {
                inString.toggle()
                continue
            }
            guard !inString else { continue }

            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = idx
                    break
                }
            }
        }

        guard let end = endIndex else { return nil }
        return String(raw[startIndex...end])
    }
}

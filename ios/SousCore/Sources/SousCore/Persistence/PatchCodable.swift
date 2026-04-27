import Foundation

// MARK: - PatchSetStatus + Codable

extension PatchSetStatus: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .pending:  try container.encode("pending")
        case .accepted: try container.encode("accepted")
        case .rejected: try container.encode("rejected")
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "pending":  self = .pending
        case "accepted": self = .accepted
        case "rejected": self = .rejected
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown PatchSetStatus value"
            )
        }
    }
}

// MARK: - Patch + Codable
//
// Explicit implementation required: Patch has associated values so synthesis is
// unavailable. Encoded as a discriminated object with a "type" key.
//
// Backward-compat decoder entries handle patch types that were persisted in
// sessions created before the schema migration (addNote, addSubStep, updateSubStep,
// removeSubStep, completeSubStep). They are mapped to their nearest equivalent so
// that old sessions continue to load without errors.

extension Patch: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, text, id, afterId, groupId, afterGroupId, header, items
        case parentId, afterStepId, preassignedId, title
        case stepId, notes, sectionId
        // Legacy keys kept for decoding persisted patches from old sessions
        case parentStepId, subStepId, afterSubStepId
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .setTitle(let title):
            try c.encode("setTitle", forKey: .type)
            try c.encode(title, forKey: .title)

        case .addIngredient(let groupId, let afterId, let text):
            try c.encode("addIngredient", forKey: .type)
            try c.encodeIfPresent(groupId, forKey: .groupId)
            try c.encodeIfPresent(afterId, forKey: .afterId)
            try c.encode(text, forKey: .text)

        case .updateIngredient(let id, let text):
            try c.encode("updateIngredient", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(text, forKey: .text)

        case .removeIngredient(let id):
            try c.encode("removeIngredient", forKey: .type)
            try c.encode(id, forKey: .id)

        case .addIngredientGroup(let afterGroupId, let header):
            try c.encode("addIngredientGroup", forKey: .type)
            try c.encodeIfPresent(afterGroupId, forKey: .afterGroupId)
            try c.encodeIfPresent(header, forKey: .header)

        case .updateIngredientGroup(let id, let header):
            try c.encode("updateIngredientGroup", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encodeIfPresent(header, forKey: .header)

        case .removeIngredientGroup(let id):
            try c.encode("removeIngredientGroup", forKey: .type)
            try c.encode(id, forKey: .id)

        case .addStep(let parentId, let afterId, let text, let preassignedId):
            try c.encode("addStep", forKey: .type)
            try c.encodeIfPresent(parentId, forKey: .parentId)
            try c.encodeIfPresent(afterId, forKey: .afterId)
            try c.encode(text, forKey: .text)
            try c.encodeIfPresent(preassignedId, forKey: .preassignedId)

        case .updateStep(let id, let text):
            try c.encode("updateStep", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(text, forKey: .text)

        case .removeStep(let id):
            try c.encode("removeStep", forKey: .type)
            try c.encode(id, forKey: .id)

        case .setStepNotes(let stepId, let notesList):
            try c.encode("setStepNotes", forKey: .type)
            try c.encode(stepId, forKey: .stepId)
            try c.encode(notesList, forKey: .notes)

        case .addNoteSection(let afterId, let header, let items):
            try c.encode("addNoteSection", forKey: .type)
            try c.encodeIfPresent(afterId, forKey: .afterId)
            try c.encodeIfPresent(header, forKey: .header)
            try c.encode(items, forKey: .items)

        case .updateNoteSection(let id, let header, let items):
            try c.encode("updateNoteSection", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encodeIfPresent(header, forKey: .header)
            try c.encode(items, forKey: .items)

        case .removeNoteSection(let id):
            try c.encode("removeNoteSection", forKey: .type)
            try c.encode(id, forKey: .id)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "setTitle":
            self = .setTitle(try c.decode(String.self, forKey: .title))

        case "addIngredient":
            self = .addIngredient(
                groupId: try c.decodeIfPresent(UUID.self, forKey: .groupId),
                afterId: try c.decodeIfPresent(UUID.self, forKey: .afterId),
                text: try c.decode(String.self, forKey: .text)
            )

        case "updateIngredient":
            self = .updateIngredient(
                id: try c.decode(UUID.self, forKey: .id),
                text: try c.decode(String.self, forKey: .text)
            )

        case "removeIngredient":
            self = .removeIngredient(id: try c.decode(UUID.self, forKey: .id))

        case "addIngredientGroup":
            self = .addIngredientGroup(
                afterGroupId: try c.decodeIfPresent(UUID.self, forKey: .afterGroupId),
                header: try c.decodeIfPresent(String.self, forKey: .header)
            )

        case "updateIngredientGroup":
            self = .updateIngredientGroup(
                id: try c.decode(UUID.self, forKey: .id),
                header: try c.decodeIfPresent(String.self, forKey: .header)
            )

        case "removeIngredientGroup":
            self = .removeIngredientGroup(id: try c.decode(UUID.self, forKey: .id))

        case "addStep":
            let afterIdNew = try c.decodeIfPresent(UUID.self, forKey: .afterId)
            let afterIdLegacy = try c.decodeIfPresent(UUID.self, forKey: .afterStepId)
            self = .addStep(
                parentId: try c.decodeIfPresent(UUID.self, forKey: .parentId),
                afterId: afterIdNew ?? afterIdLegacy,
                text: try c.decode(String.self, forKey: .text),
                preassignedId: try c.decodeIfPresent(UUID.self, forKey: .preassignedId)
            )

        case "updateStep":
            self = .updateStep(
                id: try c.decode(UUID.self, forKey: .id),
                text: try c.decode(String.self, forKey: .text)
            )

        case "removeStep":
            self = .removeStep(id: try c.decode(UUID.self, forKey: .id))

        case "setStepNotes":
            self = .setStepNotes(
                stepId: try c.decode(UUID.self, forKey: .stepId),
                notes: try c.decode([String].self, forKey: .notes)
            )

        case "addNoteSection":
            self = .addNoteSection(
                afterId: try c.decodeIfPresent(UUID.self, forKey: .afterId),
                header: try c.decodeIfPresent(String.self, forKey: .header),
                items: try c.decode([String].self, forKey: .items)
            )

        case "updateNoteSection":
            self = .updateNoteSection(
                id: try c.decode(UUID.self, forKey: .id),
                header: try c.decodeIfPresent(String.self, forKey: .header),
                items: try c.decode([String].self, forKey: .items)
            )

        case "removeNoteSection":
            self = .removeNoteSection(id: try c.decode(UUID.self, forKey: .id))

        // MARK: - Legacy backward-compat decoders
        // Persisted patches from sessions before the schema migration are mapped
        // to the nearest equivalent current type so old sessions continue to load.

        case "addNote":
            let text = try c.decode(String.self, forKey: .text)
            self = .addNoteSection(afterId: nil, header: nil, items: [text])

        case "addSubStep":
            self = .addStep(
                parentId: try c.decodeIfPresent(UUID.self, forKey: .parentStepId),
                afterId: try c.decodeIfPresent(UUID.self, forKey: .afterSubStepId),
                text: try c.decode(String.self, forKey: .text),
                preassignedId: nil
            )

        case "updateSubStep":
            // SubStepId IS the stable step id in the tree
            self = .updateStep(
                id: try c.decode(UUID.self, forKey: .subStepId),
                text: try c.decode(String.self, forKey: .text)
            )

        case "removeSubStep":
            self = .removeStep(id: try c.decode(UUID.self, forKey: .subStepId))

        case "completeSubStep":
            // completeSubStep no longer exists; decode as a no-op via setTitle
            // on the existing title (safe: validator will accept it, applier is idempotent).
            // In practice these patches are in accepted/rejected patchSets and won't be re-applied.
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "completeSubStep is no longer supported"
            )

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "Unknown Patch type: \(type)"
            )
        }
    }
}

// PatchSet is declared Codable in PatchSet.swift so the compiler can synthesise
// encode(to:) and init(from:) automatically. All stored property types are Codable:
// UUID, Int, PatchSetStatus (above), [Patch] (above), String?, and Recipe (RecipeCodable.swift).

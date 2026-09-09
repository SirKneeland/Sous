import SwiftUI
import UIKit
import SousCore

struct PatchReviewView: View {
    let recipe: Recipe
    let patchSet: PatchSet
    let validation: PatchValidationResult
    @ObservedObject var store: AppStore
    var voiceCoordinator: VoiceModeCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle.uppercased())
                            .font(.sousTitle)
                            .foregroundStyle(Color.sousText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("REV. \(recipe.version) → \(recipe.version + 1)")
                            .font(.sousCaption)
                            .foregroundStyle(Color.sousMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    SousRule()

                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Changes
                        let changes = allChangedRows
                        if !changes.isEmpty {
                            SousSectionLabel(title: "Changes")
                                .padding(.top, 20)
                                .padding(.bottom, 12)

                            ForEach(changes) { row in
                                changeRowView(row)
                                SousRule()
                            }
                        }


#if DEBUG
                        DisclosureGroup("Debug") {
                            VStack(alignment: .leading, spacing: 6) {
                                switch validation {
                                case .valid:
                                    Text("✓ VALID")
                                        .font(.sousCaption)
                                        .foregroundStyle(Color.sousGreen)
                                case .invalid(let errors):
                                    Text("✗ INVALID")
                                        .font(.sousCaption)
                                        .foregroundStyle(Color.sousTerracotta)
                                    ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                                        Text(errorDescription(error))
                                            .font(.sousCaption)
                                            .foregroundStyle(Color.sousTerracotta)
                                    }
                                }
                                Divider()
                                Text("patches: \(patchSet.patches.count)")
                                    .font(.sousCaption)
                                    .foregroundStyle(Color.sousMuted)
                                ForEach(Array(patchSet.patches.enumerated()), id: \.offset) { _, patch in
                                    Text(String(describing: patch))
                                        .font(.sousCaption)
                                        .foregroundStyle(Color.sousMuted)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                        .padding(.top, 16)
#endif
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 80)
                }
            }
            .background(Color.sousBackground)

            // MARK: Last Assistant Message
            let sousMessage: String? = {
                if let coordinator = voiceCoordinator,
                   coordinator.state == .patchPending,
                   !coordinator.patchAnnouncementTranscript.isEmpty {
                    return coordinator.patchAnnouncementTranscript
                }
                return store.chatTranscript
                    .last(where: { $0.role == .assistant })
                    .map { $0.text }
            }()
            if let message = sousMessage {
                SousRule()
                VStack(alignment: .leading, spacing: 8) {
                    SousSectionLabel(title: "Sous Says...")
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                    HStack {
                        MarkdownTextView(text: message, textColor: .sousText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.sousBackground)
                            .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                        Spacer(minLength: 48)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }
                .background(Color.sousSurface)
            }

            // MARK: Action Bar
            SousRule()
            HStack(spacing: 0) {
                Button {
                    store.send(.rejectPatch(userText: ""))
                } label: {
                    Text("REJECT")
                        .font(.sousButton)
                        .foregroundStyle(Color.sousTerracotta)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.sousBackground)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.sousSeparator)
                    .frame(width: 1, height: 56)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.send(.acceptPatch)
                    }
                } label: {
                    Text("ACCEPT")
                        .font(.sousButton)
                        .foregroundStyle(Color.sousBackground)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(isValid ? Color.sousText : Color.sousMuted)
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
            .background(Color.sousBackground)

            if let coordinator = voiceCoordinator,
               coordinator.isActive {
                VoiceBarView(
                    coordinator: coordinator,
                    onExit: {},
                    onAccept: {},
                    onReject: {}
                )
            }
        }
    }

    // MARK: - Change Row View

    @ViewBuilder
    private func changeRowView(_ row: DiffRow) -> some View {
        switch row {
        case .added(_, let text):
            HStack(spacing: 0) {
                Rectangle().fill(Color.sousGreen).frame(width: 2)
                Text(text)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousGreen)
                    .padding(.leading, 12)
                    .padding(.vertical, 10)
                Spacer()
            }

        case .removed(_, let text):
            HStack(spacing: 0) {
                Rectangle().fill(Color.sousTerracotta).frame(width: 2)
                Text(text)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousTerracotta)
                    .strikethrough(true, color: Color.sousTerracotta)
                    .padding(.leading, 12)
                    .padding(.vertical, 10)
                Spacer()
            }

        case .updated(_, let oldText, let newText):
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.sousTerracotta).frame(width: 2)
                    Text(oldText)
                        .font(.sousBody)
                        .foregroundStyle(Color.sousTerracotta)
                        .strikethrough(true, color: Color.sousTerracotta)
                        .padding(.leading, 12)
                        .padding(.vertical, 8)
                    Spacer()
                }
                HStack(spacing: 0) {
                    Rectangle().fill(Color.sousGreen).frame(width: 2)
                    Text(newText)
                        .font(.sousBody)
                        .foregroundStyle(Color.sousGreen)
                        .padding(.leading, 12)
                        .padding(.vertical, 8)
                    Spacer()
                }
            }

        case .doneImmutableViolation(_, let originalText, let attemptedText):
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.sousTerracotta).frame(width: 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(originalText)
                            .font(.sousBody)
                            .foregroundStyle(Color.sousMuted)
                        Text(attemptedText)
                            .font(.sousBody)
                            .foregroundStyle(Color.sousTerracotta)
                        Text("IMMUTABLE — DONE STEP CANNOT BE EDITED")
                            .font(.sousCaption)
                            .foregroundStyle(Color.sousTerracotta)
                            .kerning(0.5)
                    }
                    .padding(.leading, 12)
                    .padding(.vertical, 8)
                    Spacer()
                }
            }

        case .addedSubStep(_, _, let text):
            HStack(spacing: 0) {
                Color.clear.frame(width: 20)
                Rectangle().fill(Color.sousGreen).frame(width: 2)
                Text(text)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousGreen)
                    .padding(.leading, 12)
                    .padding(.vertical, 10)
                Spacer()
            }

        case .removedSubStep(_, _, let text):
            HStack(spacing: 0) {
                Color.clear.frame(width: 20)
                Rectangle().fill(Color.sousTerracotta).frame(width: 2)
                Text(text)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousTerracotta)
                    .strikethrough(true, color: Color.sousTerracotta)
                    .padding(.leading, 12)
                    .padding(.vertical, 10)
                Spacer()
            }

        case .updatedSubStep(_, _, _, let newText):
            HStack(spacing: 0) {
                Color.clear.frame(width: 20)
                Rectangle().fill(Color.sousGreen).frame(width: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(newText)
                        .font(.sousBody)
                        .foregroundStyle(Color.sousGreen)
                    Text("EDITED")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousGreen)
                        .kerning(0.5)
                }
                .padding(.leading, 12)
                .padding(.vertical, 8)
                Spacer()
            }

        case .groupHeader(_, let text):
            Text(text.uppercased())
                .font(.sousSectionHeader)
                .foregroundStyle(Color.sousMuted)
                .kerning(1.0)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .unchanged:
            EmptyView()
        }
    }

    // MARK: - Title

    private var displayTitle: String {
        for patch in patchSet.patches {
            if case .setTitle(let title) = patch { return title }
        }
        return recipe.title
    }

    // MARK: - Diff Builders

    private var allChangedRows: [DiffRow] {
        let stepChanges = stepRows.filter {
            if case .unchanged = $0 { return false }
            return true
        }
        return headerAwareChanges(ingredientRows) + headerAwareChanges(miseEnPlaceRows) + stepChanges
    }

    /// Drops unchanged rows, keeping a group header only when at least one changed row
    /// follows it in the same group.
    private func headerAwareChanges(_ rows: [DiffRow]) -> [DiffRow] {
        var result: [DiffRow] = []
        var pendingHeader: DiffRow? = nil
        for row in rows {
            switch row {
            case .groupHeader:
                pendingHeader = row
            case .unchanged:
                break
            default:
                if let header = pendingHeader {
                    result.append(header)
                    pendingHeader = nil
                }
                result.append(row)
            }
        }
        return result
    }

    /// Diff rows for the mise en place section. Vessel groups render as a header row
    /// followed by one row per component; solo entries render as a single row.
    private var miseEnPlaceRows: [DiffRow] {
        var rows: [DiffRow] = []
        // Entry id for each row, so component inserts can find the end of an entry.
        var owner: [UUID: UUID] = [:]

        for entry in recipe.miseEnPlace ?? [] {
            switch entry.content {
            case .group(let vesselName, let components):
                rows.append(.groupHeader(id: entry.id, text: vesselName))
                owner[entry.id] = entry.id
                for component in components {
                    rows.append(.unchanged(id: component.id, text: component.text))
                    owner[component.id] = entry.id
                }
            case .solo(let instruction, _):
                rows.append(.unchanged(id: entry.id, text: instruction))
                owner[entry.id] = entry.id
            }
        }

        // Index just past the last row belonging to `entryId`.
        func endOfEntry(_ entryId: UUID) -> Int? {
            guard let start = rows.firstIndex(where: { $0.id == entryId }) else { return nil }
            var idx = start + 1
            while idx < rows.count, owner[rows[idx].id] == entryId { idx += 1 }
            return idx
        }

        for patch in patchSet.patches {
            switch patch {
            case .addMiseEnPlaceEntry(_, let vesselName, let items, _):
                let entryId = UUID()
                if let vesselName {
                    rows.append(.added(id: entryId, text: vesselName))
                    owner[entryId] = entryId
                    for item in items {
                        let componentId = UUID()
                        rows.append(.addedSubStep(id: componentId, parentId: entryId, text: item))
                        owner[componentId] = entryId
                    }
                } else {
                    rows.append(.added(id: entryId, text: items.first ?? ""))
                    owner[entryId] = entryId
                }

            case .updateMiseEnPlaceEntry(let id, let text):
                if let idx = rows.firstIndex(where: { $0.id == id }) {
                    switch rows[idx] {
                    case .groupHeader(_, let oldText), .unchanged(_, let oldText):
                        rows[idx] = .updated(id: id, oldText: oldText, newText: text)
                    default:
                        break
                    }
                }

            case .removeMiseEnPlaceEntry(let id):
                for idx in rows.indices where rows[idx].id == id || owner[rows[idx].id] == id {
                    switch rows[idx] {
                    case .groupHeader(let rowId, let text), .unchanged(let rowId, let text):
                        rows[idx] = .removed(id: rowId, text: text)
                    default:
                        break
                    }
                }

            case .addMiseEnPlaceComponent(let entryId, let afterId, let text):
                let componentId = UUID()
                let newRow = DiffRow.addedSubStep(id: componentId, parentId: entryId, text: text)
                owner[componentId] = entryId
                if let afterId, let idx = rows.firstIndex(where: { $0.id == afterId }) {
                    rows.insert(newRow, at: idx + 1)
                } else if let end = endOfEntry(entryId) {
                    rows.insert(newRow, at: end)
                } else {
                    rows.append(newRow)
                }

            case .updateMiseEnPlaceComponent(let id, let text):
                if let idx = rows.firstIndex(where: { $0.id == id }),
                   case .unchanged(_, let oldText) = rows[idx] {
                    rows[idx] = .updated(id: id, oldText: oldText, newText: text)
                }

            case .removeMiseEnPlaceComponent(let id):
                if let idx = rows.firstIndex(where: { $0.id == id }),
                   case .unchanged(_, let text) = rows[idx] {
                    rows[idx] = .removed(id: id, text: text)
                }

            default:
                break
            }
        }

        return rows
    }

    private var ingredientRows: [DiffRow] {
        var rows: [DiffRow] = []
        for group in recipe.ingredients {
            if let header = group.header {
                rows.append(.groupHeader(id: group.id, text: header))
            }
            rows += group.items.map { .unchanged(id: $0.id, text: $0.text) }
        }

        for patch in patchSet.patches {
            switch patch {
            case .addIngredient(_, let afterId, let text):
                let newRow = DiffRow.added(id: UUID(), text: text)
                if let afterId, let idx = rows.firstIndex(where: { $0.id == afterId }) {
                    rows.insert(newRow, at: idx + 1)
                } else {
                    rows.append(newRow)
                }
            case .updateIngredient(let id, let text):
                if let idx = rows.firstIndex(where: { $0.id == id }),
                   case .unchanged(_, let oldText) = rows[idx] {
                    rows[idx] = .updated(id: id, oldText: oldText, newText: text)
                }
            case .removeIngredient(let id):
                if let idx = rows.firstIndex(where: { $0.id == id }),
                   case .unchanged(_, let text) = rows[idx] {
                    rows[idx] = .removed(id: id, text: text)
                }
            default:
                break
            }
        }

        return rows
    }

    private var stepRows: [DiffRow] {
        var rows: [DiffRow] = recipe.steps.map { .unchanged(id: $0.id, text: $0.text) }

        for patch in patchSet.patches {
            switch patch {
            case .addStep(_, let afterStepId, let text, _):
                let newRow = DiffRow.added(id: UUID(), text: text)
                if let afterStepId, let idx = rows.firstIndex(where: { $0.id == afterStepId }) {
                    rows.insert(newRow, at: idx + 1)
                } else {
                    rows.append(newRow)
                }
            case .updateStep(let id, let newText):
                if let idx = rows.firstIndex(where: { $0.id == id }),
                   case .unchanged(_, let oldText) = rows[idx] {
                    rows[idx] = .updated(id: id, oldText: oldText, newText: newText)
                }
            case .removeStep(let id):
                if let idx = rows.firstIndex(where: { $0.id == id }),
                   case .unchanged(_, let text) = rows[idx] {
                    rows[idx] = .removed(id: id, text: text)
                }
            default:
                break
            }
        }

        let immutableIds: Set<UUID> = {
            guard case .invalid(let errors) = validation else { return [] }
            return Set(errors.compactMap {
                if case .stepDoneImmutable(let id) = $0 { return id }
                return nil
            })
        }()

        if !immutableIds.isEmpty {
            for idx in rows.indices {
                if case .updated(let id, let oldText, let newText) = rows[idx],
                   immutableIds.contains(id) {
                    rows[idx] = .doneImmutableViolation(id: id, originalText: oldText, attemptedText: newText)
                }
            }
        }

        return rows
    }

    // MARK: - Helpers

    private var isValid: Bool {
        if case .valid = validation { return true }
        return false
    }

    private func errorDescription(_ error: PatchValidationError) -> String {
        switch error {
        case .versionMismatch(let expected, let got):
            return "Version mismatch: expected \(expected), got \(got)"
        case .invalidIngredientId(let id):
            return "Invalid ingredient ID: \(id.uuidString)"
        case .invalidStepId(let id):
            return "Invalid step ID: \(id.uuidString)"
        case .stepDoneImmutable(let id):
            return "Step is done (immutable): \(id.uuidString)"
        case .internalConflict(let msg):
            return "Internal conflict: \(msg)"
        case .recipeIdMismatch(let expected, let got):
            return "Recipe ID mismatch: expected \(expected), got \(got)"
        case .invalidSubStepId(let id):
            return "Invalid sub-step ID: \(id.uuidString)"
        case .parentStepDone(let id):
            return "Parent step is already done: \(id.uuidString)"
        case .hardAvoidViolation(let ingredient):
            return "Contains a hard-avoid ingredient: \(ingredient)"
        case .invalidIngredientGroupId(let id):
            return "Invalid ingredient group ID: \(id.uuidString)"
        case .invalidNoteSectionId(let id):
            return "Invalid note section ID: \(id.uuidString)"
        case .invalidMiseEnPlaceEntryId(let id):
            return "Invalid mise en place entry ID: \(id.uuidString)"
        case .invalidMiseEnPlaceComponentId(let id):
            return "Invalid mise en place component ID: \(id.uuidString)"
        }
    }
}

// MARK: - DiffRow

private enum DiffRow: Identifiable {
    case unchanged(id: UUID, text: String)
    case added(id: UUID, text: String)
    case updated(id: UUID, oldText: String, newText: String)
    case removed(id: UUID, text: String)
    case doneImmutableViolation(id: UUID, originalText: String, attemptedText: String)
    case addedSubStep(id: UUID, parentId: UUID, text: String)
    case removedSubStep(id: UUID, parentId: UUID, text: String)
    case updatedSubStep(id: UUID, parentId: UUID, oldText: String, newText: String)
    case groupHeader(id: UUID, text: String)

    var id: UUID {
        switch self {
        case .unchanged(let id, _):                  return id
        case .added(let id, _):                      return id
        case .updated(let id, _, _):                 return id
        case .removed(let id, _):                    return id
        case .doneImmutableViolation(let id, _, _):  return id
        case .addedSubStep(let id, _, _):            return id
        case .removedSubStep(let id, _, _):          return id
        case .updatedSubStep(let id, _, _, _):       return id
        case .groupHeader(let id, _):                return id
        }
    }
}

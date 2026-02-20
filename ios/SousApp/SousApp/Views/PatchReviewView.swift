import SwiftUI
import SousCore

struct PatchReviewView: View {
    let recipe: Recipe
    let patchSet: PatchSet
    let validation: PatchValidationResult
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Proposed Changes").font(.headline)
            Text("patches: \(patchSet.patches.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

#if DEBUG
DisclosureGroup("Debug") {
    VStack(alignment: .leading, spacing: 6) {
        Text("patches: \(patchSet.patches.count)")
            .font(.caption)
            .foregroundStyle(.secondary)

        ForEach(Array(patchSet.patches.enumerated()), id: \.offset) { _, patch in
            Text(String(describing: patch))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
    .padding(.top, 4)
}
#endif

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !ingredientRows.isEmpty {
                        sectionView(title: "Ingredients", rows: ingredientRows)
                    }
                    if !stepRows.isEmpty {
                        sectionView(title: "Steps", rows: stepRows)
                    }
                }
            }

            Divider()

            switch validation {
            case .valid:
                Text("✓ Valid").foregroundStyle(.green)
            case .invalid(let errors):
                VStack(alignment: .leading, spacing: 4) {
                    Text("✗ Invalid").foregroundStyle(.red)
                    ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                        Text(errorDescription(error))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()

            HStack {
                Button("Reject") {
                    store.send(.rejectPatch(userText: ""))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Accept") {
                    store.send(.acceptPatch)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding()
    }

    // MARK: - Section rendering

    @ViewBuilder
    private func sectionView(title: String, rows: [DiffRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(rows) { row in
                rowView(row)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: DiffRow) -> some View {
        switch row {
        case .unchanged(_, let text):
            Text(text)
                .font(.body)

        case .added(_, let text):
            Text("+ \(text)")
                .font(.body)
                .foregroundStyle(.green)

        case .updated(_, let oldText, let newText):
            VStack(alignment: .leading, spacing: 2) {
                Text(oldText)
                    .strikethrough()
                    .foregroundStyle(.gray)
                    .font(.body)
                Text(newText)
                    .foregroundStyle(.blue)
                    .font(.body)
            }

        case .removed(_, let text):
            Text(text)
                .strikethrough()
                .foregroundStyle(.red)
                .font(.body)

        case .doneImmutableViolation(_, let originalText, let attemptedText):
            VStack(alignment: .leading, spacing: 4) {
                Text(originalText)
                    .font(.body)
                Text(attemptedText)
                    .font(.body)
                    .foregroundStyle(.red)
                Text("Immutable (Done step cannot be edited)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.red.opacity(0.6), lineWidth: 1)
            )
        }
    }

    // MARK: - Diff builders

    private var ingredientRows: [DiffRow] {
        var rows: [DiffRow] = recipe.ingredients.map { .unchanged(id: $0.id, text: $0.text) }

        for patch in patchSet.patches {
            switch patch {
            case .addIngredient(let text, let afterId):
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
        // Pass 1: build structural diff rows
        var rows: [DiffRow] = recipe.steps.map { .unchanged(id: $0.id, text: $0.text) }

        for patch in patchSet.patches {
            switch patch {
            case .addStep(let text, let afterStepId):
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

        // Pass 2: overlay validation errors — promote .updated → .doneImmutableViolation
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

    var id: UUID {
        switch self {
        case .unchanged(let id, _):                  return id
        case .added(let id, _):                      return id
        case .updated(let id, _, _):                 return id
        case .removed(let id, _):                    return id
        case .doneImmutableViolation(let id, _, _):  return id
        }
    }
}

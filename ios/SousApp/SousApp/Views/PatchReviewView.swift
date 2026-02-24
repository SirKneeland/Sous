import SwiftUI
import UIKit
import SousCore

struct PatchReviewView: View {
    let recipe: Recipe
    let patchSet: PatchSet
    let validation: PatchValidationResult
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Canonical header — identical to RecipeCanvasView
                Text(recipe.title)
                    .font(.title).bold()
                Text("Version: \(recipe.version)")
                    .font(.caption).foregroundStyle(.secondary)

                Divider()

                if !ingredientRows.isEmpty {
                    sectionView(title: "Ingredients", rows: ingredientRows, isSteps: false)
                }
                if !stepRows.isEmpty {
                    sectionView(title: "Steps", rows: stepRows, isSteps: true)
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

                HStack {
                    Button("Reject") {
                        store.send(.rejectPatch(userText: ""))
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Accept") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            store.send(.acceptPatch)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }

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
            }
            .padding()
        }
    }

    // MARK: - Section rendering

    // Group is layout-transparent: its children become direct VStack children,
    // inheriting the parent's spacing (12pt) — matching RecipeCanvasView exactly.
    @ViewBuilder
    private func sectionView(title: String, rows: [DiffRow], isSteps: Bool) -> some View {
        Group {
            Text(title)
                .font(.headline)
            ForEach(rows) { row in
                if isSteps {
                    stepRowView(row)
                } else {
                    ingredientRowView(row)
                }
            }
        }
    }

    // Ingredient rows — exact RecipeCanvasView markup for .unchanged; diff styling layered on top
    @ViewBuilder
    private func ingredientRowView(_ row: DiffRow) -> some View {
        switch row {
        case .unchanged(_, let text):
            Text("• \(text)")

        case .added(_, let text):
            Text("• \(text)")
                .foregroundStyle(.green)

        case .updated(_, let oldText, let newText):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("•")
                Text(oldText)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Text("→")
                    .foregroundStyle(.secondary)
                Text(newText)
                    .foregroundStyle(.blue)
            }

        case .removed(_, let text):
            Text("• \(text)")
                .strikethrough()
                .foregroundStyle(.red)

        case .doneImmutableViolation(_, let originalText, let attemptedText):
            VStack(alignment: .leading, spacing: 4) {
                Text("• \(originalText)")
                Text("• \(attemptedText)")
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

    // Step rows — exact RecipeCanvasView markup for .unchanged; diff styling layered on top
    @ViewBuilder
    private func stepRowView(_ row: DiffRow) -> some View {
        switch row {
        case .unchanged(let id, let text):
            HStack(alignment: .top, spacing: 8) {
                Text(isStepDone(id) ? "[done]" : "[todo]")
                    .font(.caption).monospaced()
                    .foregroundStyle(isStepDone(id) ? Color.secondary : Color.primary)
                Text(text)
                    .strikethrough(isStepDone(id))
            }

        case .added(_, let text):
            HStack(alignment: .top, spacing: 8) {
                Text("[todo]")
                    .font(.caption).monospaced()
                    .foregroundStyle(Color.primary)
                Text(text)
                    .foregroundStyle(.green)
            }

        case .updated(let id, let oldText, let newText):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(isStepDone(id) ? "[done]" : "[todo]")
                    .font(.caption).monospaced()
                    .foregroundStyle(isStepDone(id) ? Color.secondary : Color.primary)
                Text(oldText)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Text("→")
                    .foregroundStyle(.secondary)
                Text(newText)
                    .foregroundStyle(.blue)
            }

        case .removed(let id, let text):
            HStack(alignment: .top, spacing: 8) {
                Text(isStepDone(id) ? "[done]" : "[todo]")
                    .font(.caption).monospaced()
                    .foregroundStyle(Color.secondary)
                Text(text)
                    .strikethrough()
                    .foregroundStyle(.red)
            }

        case .doneImmutableViolation(_, let originalText, let attemptedText):
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text("[done]")
                        .font(.caption).monospaced()
                        .foregroundStyle(Color.secondary)
                    Text(originalText)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("[done]")
                        .font(.caption).monospaced()
                        .foregroundStyle(Color.secondary)
                    Text(attemptedText)
                        .foregroundStyle(.red)
                }
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

    private func isStepDone(_ id: UUID) -> Bool {
        recipe.steps.first(where: { $0.id == id })?.status == .done
    }

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

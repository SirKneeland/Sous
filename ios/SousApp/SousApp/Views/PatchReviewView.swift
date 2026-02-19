import SwiftUI
import SousCore

struct PatchReviewView: View {
    let patchSet: PatchSet
    let validation: PatchValidationResult
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Proposed Changes").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(patchSet.patches.enumerated()), id: \.offset) { _, patch in
                    Text("• \(patchDescription(patch))")
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

    private var isValid: Bool {
        if case .valid = validation { return true }
        return false
    }

    private func patchDescription(_ patch: Patch) -> String {
        switch patch {
        case .addIngredient(let text, _):    return "Add ingredient: \(text)"
        case .updateIngredient(_, let text): return "Update ingredient: \(text)"
        case .removeIngredient:              return "Remove ingredient"
        case .addStep(let text, _):          return "Add step: \(text)"
        case .updateStep(_, let text):       return "Update step: \(text)"
        case .removeStep:                    return "Remove step"
        case .addNote(let text):             return "Add note: \(text)"
        }
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

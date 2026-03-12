import SwiftUI
import SousCore

struct RecipeCanvasView: View {
    let recipe: Recipe
    let onOpenChat: () -> Void
    var onMarkStepDone: (UUID) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    var onStartNew: () -> Void = {}
    var onOpenRecents: () -> Void = {}
    var llmDebugStatus: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.title)
                            .font(.title).bold()
                        Text("Version: \(recipe.version)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { onStartNew() } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Button { onOpenRecents() } label: {
                        Image(systemName: "clock")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Button { onOpenSettings() } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text("Ingredients").font(.headline)
                ForEach(recipe.ingredients, id: \.id) { ingredient in
                    Text("• \(ingredient.text)")
                }

                Text("Steps").font(.headline)
                ForEach(recipe.steps, id: \.id) { step in
                    Button {
                        if step.status == .todo { onMarkStepDone(step.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: step.status == .done
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(step.status == .done ? .secondary : .primary)
                            Text(step.text)
                                .strikethrough(step.status == .done)
                                .foregroundStyle(step.status == .done ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(step.status == .done)
                }

                if !recipe.notes.isEmpty {
                    Text("Notes").font(.headline)
                    ForEach(recipe.notes, id: \.self) { note in
                        Text("– \(note)")
                    }
                }
            }
            .padding()
            .padding(.bottom, 72)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
#if DEBUG
                if let status = llmDebugStatus {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 6)
                }
#endif
                Button {
                    onOpenChat()
                } label: {
                    Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(.regularMaterial)
        }
    }
}

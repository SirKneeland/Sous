import SwiftUI
import SousCore

struct RecipeCanvasView: View {
    let recipe: Recipe
    let onOpenChat: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title)
                    .font(.title).bold()
                Text("Version: \(recipe.version)")
                    .font(.caption).foregroundStyle(.secondary)

                Divider()

                Text("Ingredients").font(.headline)
                ForEach(recipe.ingredients, id: \.id) { ingredient in
                    Text("• \(ingredient.text)")
                }

                Text("Steps").font(.headline)
                ForEach(recipe.steps, id: \.id) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Text(step.status == .done ? "[done]" : "[todo]")
                            .font(.caption).monospaced()
                            .foregroundStyle(step.status == .done ? .secondary : .primary)
                        Text(step.text)
                            .strikethrough(step.status == .done)
                    }
                }

                if !recipe.notes.isEmpty {
                    Text("Notes").font(.headline)
                    ForEach(recipe.notes, id: \.self) { note in
                        Text("– \(note)")
                    }
                }

                Divider()

                Button {
                    onOpenChat()
                } label: {
                    Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
        }
    }
}

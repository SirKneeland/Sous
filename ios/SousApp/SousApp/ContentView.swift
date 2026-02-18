import SwiftUI
import SousCore

struct ContentView: View {
    @StateObject private var store = SessionStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let recipe = store.recipe {
                    recipeView(recipe)
                } else {
                    Button("Load Recipe") {
                        store.loadSeedRecipe()
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func recipeView(_ recipe: Recipe) -> some View {
        Text(recipe.title).font(.title).bold()
        Text("Version: \(recipe.version)").font(.caption)

        Text("Ingredients").font(.headline)
        ForEach(recipe.ingredients, id: \.id) { ingredient in
            Text("• \(ingredient.text)")
        }

        Text("Steps").font(.headline)
        ForEach(recipe.steps, id: \.id) { step in
            HStack {
                Text(step.status == .done ? "[done]" : "[todo]")
                    .font(.caption).monospaced()
                Text(step.text)
            }
        }

        if !recipe.notes.isEmpty {
            Text("Notes").font(.headline)
            ForEach(recipe.notes, id: \.self) { note in
                Text("– \(note)")
            }
        }

        if let pending = store.pendingPatchSet {
            Text("Pending PatchSet").font(.headline)
            Text("Patches: \(pending.patches.count)")
        }

        if let result = store.validationResult {
            Text("Validation Result").font(.headline)
            switch result {
            case .valid:
                Text("VALID").foregroundStyle(.green)
            case .invalid(let errors):
                ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                    Text("ERROR: \(String(describing: error))")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }

        Divider()
        Text("Debug Actions").font(.headline)

        HStack {
            Button("Valid Patch") { store.injectValidPatch() }
            Button("Invalid Patch") { store.injectInvalidPatch() }
        }
        HStack {
            Button("Validate") { store.validate() }
            Button("Apply") { store.apply() }
        }
    }
}

#Preview {
    ContentView()
}

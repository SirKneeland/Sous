import SwiftUI

/// Lets the user tell Sous about themselves once so they never have to repeat it.
/// Changes are saved immediately on each edit.
struct PreferencesView: View {
    @ObservedObject var store: AppStore

    /// Local text state for smooth typing. Synced from store on appear; saved to store on change.
    @State private var hardAvoidsText: String = ""
    @State private var equipmentText: String = ""
    @State private var customInstructionsText: String = ""

    // MARK: - Helpers

    private func parseList(_ text: String) -> [String] {
        text
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// A Binding that reads from and writes to a specific Int? field in store.userPreferences.
    private func servingSizeBinding() -> Binding<Int> {
        Binding(
            get: { store.userPreferences.servingSize ?? 2 },
            set: { newValue in
                var prefs = store.userPreferences
                prefs.servingSize = newValue
                store.updatePreferences(prefs)
            }
        )
    }

    var body: some View {
        Form {
            // MARK: Hard Avoids
            Section {
                TextField(
                    "e.g. cilantro, shellfish, nuts",
                    text: $hardAvoidsText
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: hardAvoidsText) { _, text in
                    var prefs = store.userPreferences
                    prefs.hardAvoids = parseList(text)
                    store.updatePreferences(prefs)
                }
            } header: {
                Text("Ingredients to Always Avoid")
            } footer: {
                Text("Separate items with commas. Sous will never suggest these.")
            }

            // MARK: Serving Size
            Section {
                Toggle("Set a default", isOn: Binding(
                    get: { store.userPreferences.servingSize != nil },
                    set: { on in
                        var prefs = store.userPreferences
                        prefs.servingSize = on ? 2 : nil
                        store.updatePreferences(prefs)
                    }
                ))

                if let size = store.userPreferences.servingSize {
                    Stepper(
                        "\(size) \(size == 1 ? "person" : "people")",
                        value: servingSizeBinding(),
                        in: 1...20
                    )
                }
            } header: {
                Text("Default Servings")
            } footer: {
                Text("Sous will scale new recipes to this size unless you say otherwise.")
            }

            // MARK: Equipment
            Section {
                TextField(
                    "e.g. cast iron, air fryer, stand mixer",
                    text: $equipmentText
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: equipmentText) { _, text in
                    var prefs = store.userPreferences
                    prefs.equipment = parseList(text)
                    store.updatePreferences(prefs)
                }
            } header: {
                Text("Kitchen Equipment")
            } footer: {
                Text("Separate items with commas. Sous will suggest techniques that match what you have.")
            }

            // MARK: Custom Instructions
            Section {
                TextEditor(text: $customInstructionsText)
                    .frame(minHeight: 80)
                    .autocorrectionDisabled()
                    .onChange(of: customInstructionsText) { _, text in
                        var prefs = store.userPreferences
                        prefs.customInstructions = text
                        store.updatePreferences(prefs)
                    }
            } header: {
                Text("Custom Instructions")
            } footer: {
                Text("Anything else you want Sous to always keep in mind — e.g. \"always give stove settings for both gas and induction\".")
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Sync text fields from store each time the view appears
            // (handles both first launch and returning via navigation)
            hardAvoidsText = store.userPreferences.hardAvoids.joined(separator: ", ")
            equipmentText = store.userPreferences.equipment.joined(separator: ", ")
            customInstructionsText = store.userPreferences.customInstructions
        }
    }
}

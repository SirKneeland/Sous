import SwiftUI

/// Lets the user tell Sous about themselves once so they never have to repeat it.
/// Changes are saved immediately on each edit.
struct PreferencesView: View {
    @ObservedObject var store: AppStore

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
                .font(.sousBody)
                .foregroundStyle(Color.sousText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(8)
                .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                .onChange(of: hardAvoidsText) { _, text in
                    var prefs = store.userPreferences
                    prefs.hardAvoids = parseList(text)
                    store.updatePreferences(prefs)
                }
            } header: {
                Text("INGREDIENTS TO ALWAYS AVOID")
                    .font(.sousSectionHeader)
                    .foregroundStyle(Color.sousTerracotta)
                    .kerning(1.2)
                    .textCase(nil)
            } footer: {
                Text("Separate items with commas. Sous will never suggest these.")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
            }
            .listRowBackground(Color.sousBackground)
            .listRowSeparatorTint(Color.sousSeparator)

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
                .font(.sousBody)
                .foregroundStyle(Color.sousText)
                .tint(Color.sousTerracotta)

                if let size = store.userPreferences.servingSize {
                    Stepper(
                        "\(size) \(size == 1 ? "person" : "people")",
                        value: servingSizeBinding(),
                        in: 1...20
                    )
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                }
            } header: {
                Text("DEFAULT SERVINGS")
                    .font(.sousSectionHeader)
                    .foregroundStyle(Color.sousTerracotta)
                    .kerning(1.2)
                    .textCase(nil)
            } footer: {
                Text("Sous will scale new recipes to this size unless you say otherwise.")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
            }
            .listRowBackground(Color.sousBackground)
            .listRowSeparatorTint(Color.sousSeparator)

            // MARK: Equipment
            Section {
                TextField(
                    "e.g. cast iron, air fryer, stand mixer",
                    text: $equipmentText
                )
                .font(.sousBody)
                .foregroundStyle(Color.sousText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(8)
                .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                .onChange(of: equipmentText) { _, text in
                    var prefs = store.userPreferences
                    prefs.equipment = parseList(text)
                    store.updatePreferences(prefs)
                }
            } header: {
                Text("KITCHEN EQUIPMENT")
                    .font(.sousSectionHeader)
                    .foregroundStyle(Color.sousTerracotta)
                    .kerning(1.2)
                    .textCase(nil)
            } footer: {
                Text("Separate items with commas. Sous will suggest techniques that match what you have.")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
            }
            .listRowBackground(Color.sousBackground)
            .listRowSeparatorTint(Color.sousSeparator)

            // MARK: Custom Instructions
            Section {
                TextEditor(text: $customInstructionsText)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .autocorrectionDisabled()
                    .padding(4)
                    .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                    .onChange(of: customInstructionsText) { _, text in
                        var prefs = store.userPreferences
                        prefs.customInstructions = text
                        store.updatePreferences(prefs)
                    }
            } header: {
                Text("CUSTOM INSTRUCTIONS")
                    .font(.sousSectionHeader)
                    .foregroundStyle(Color.sousTerracotta)
                    .kerning(1.2)
                    .textCase(nil)
            } footer: {
                Text("Anything else you want Sous to always keep in mind.")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
            }
            .listRowBackground(Color.sousBackground)
            .listRowSeparatorTint(Color.sousSeparator)
        }
        .scrollContentBackground(.hidden)
        .background(Color.sousBackground)
        .navigationTitle("PREFERENCES")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hardAvoidsText = store.userPreferences.hardAvoids.joined(separator: ", ")
            equipmentText = store.userPreferences.equipment.joined(separator: ", ")
            customInstructionsText = store.userPreferences.customInstructions
        }
    }
}

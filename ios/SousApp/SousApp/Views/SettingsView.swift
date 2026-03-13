import SwiftUI

struct SettingsView: View {
    let store: AppStore

    @State private var keyInput = ""
    @State private var keyIsPresent: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // MARK: Preferences
                Section {
                    NavigationLink("Preferences") {
                        PreferencesView(store: store)
                    }
                } header: {
                    Text("Your Kitchen")
                } footer: {
                    Text("Dietary restrictions, default servings, equipment, and custom instructions.")
                }

                // MARK: API Key
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(keyIsPresent ? "Key saved" : "Not configured")
                            .foregroundStyle(keyIsPresent ? .green : .orange)
                    }

                    SecureField("Paste API key (sk-…)", text: $keyInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    HStack {
                        Button("Save Key") {
                            store.keyProvider.setKey(keyInput)
                            keyInput = ""
                            keyIsPresent = store.keyProvider.currentKey() != nil
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Spacer()

                        if keyIsPresent {
                            Button("Clear Key", role: .destructive) {
                                store.keyProvider.clearKey()
                                keyIsPresent = store.keyProvider.currentKey() != nil
                            }
                        }
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Your key is stored in the device Keychain and never leaves your device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                keyIsPresent = store.keyProvider.currentKey() != nil
            }
        }
    }
}

import SwiftUI

struct SettingsView: View {
    let keyProvider: any OpenAIKeyProviding

    @State private var keyInput = ""
    @State private var keyIsPresent: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
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
                            keyProvider.setKey(keyInput)
                            keyInput = ""
                            keyIsPresent = keyProvider.currentKey() != nil
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Spacer()

                        if keyIsPresent {
                            Button("Clear Key", role: .destructive) {
                                keyProvider.clearKey()
                                keyIsPresent = keyProvider.currentKey() != nil
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
                keyIsPresent = keyProvider.currentKey() != nil
            }
        }
    }
}

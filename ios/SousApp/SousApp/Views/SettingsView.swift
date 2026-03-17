import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore

    @State private var keyInput = ""
    @State private var keyIsPresent: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // MARK: Your Kitchen
                Section {
                    NavigationLink {
                        PreferencesView(store: store)
                    } label: {
                        Text("Preferences")
                            .font(.sousBody)
                            .foregroundStyle(Color.sousText)
                    }
                    NavigationLink {
                        MemoriesView(store: store)
                    } label: {
                        Text("Memories")
                            .font(.sousBody)
                            .foregroundStyle(Color.sousText)
                    }
                } header: {
                    Text("YOUR KITCHEN")
                        .font(.sousSectionHeader)
                        .foregroundStyle(Color.sousTerracotta)
                        .kerning(1.2)
                        .textCase(nil)
                } footer: {
                    Text("Dietary restrictions, default servings, equipment, custom instructions, and saved memories.")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                }
                .listRowBackground(Color.sousBackground)
                .listRowSeparatorTint(Color.sousSeparator)

                // MARK: Personality
                Section {
                    Picker("Personality", selection: Binding(
                        get: { store.userPreferences.personalityMode },
                        set: { newValue in
                            var prefs = store.userPreferences
                            prefs.personalityMode = newValue
                            store.updatePreferences(prefs)
                        }
                    )) {
                        Text("Minimal").tag("minimal")
                        Text("Normal").tag("normal")
                        Text("Playful").tag("playful")
                        Text("Unhinged").tag("unhinged")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("PERSONALITY")
                        .font(.sousSectionHeader)
                        .foregroundStyle(Color.sousTerracotta)
                        .kerning(1.2)
                        .textCase(nil)
                } footer: {
                    Text("Controls how Sous talks to you. Minimal is direct and no-frills. Normal is warm and conversational. Playful is opinionated and a little funny. Unhinged is chaos gremlin energy.")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                }
                .listRowBackground(Color.sousBackground)
                .listRowSeparatorTint(Color.sousSeparator)

                // MARK: API Key
                Section {
                    HStack {
                        Text("Status")
                            .font(.sousBody)
                            .foregroundStyle(Color.sousText)
                        Spacer()
                        Text(keyIsPresent ? "KEY SAVED" : "NOT CONFIGURED")
                            .font(.sousCaption)
                            .foregroundStyle(keyIsPresent ? Color.sousGreen : Color.sousTerracotta)
                            .kerning(0.5)
                    }

                    SecureField("Paste API key (sk-…)", text: $keyInput)
                        .font(.sousBody)
                        .foregroundStyle(Color.sousText)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    HStack {
                        Button("SAVE KEY") {
                            store.keyProvider.setKey(keyInput)
                            keyInput = ""
                            keyIsPresent = store.keyProvider.currentKey() != nil
                        }
                        .font(.sousButton)
                        .foregroundStyle(Color.sousBackground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.sousMuted
                                    : Color.sousText)
                        .buttonStyle(.plain)
                        .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Spacer()

                        if keyIsPresent {
                            Button("CLEAR KEY") {
                                store.keyProvider.clearKey()
                                keyIsPresent = store.keyProvider.currentKey() != nil
                            }
                            .font(.sousButton)
                            .foregroundStyle(Color.sousTerracotta)
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("OPENAI API KEY")
                        .font(.sousSectionHeader)
                        .foregroundStyle(Color.sousTerracotta)
                        .kerning(1.2)
                        .textCase(nil)
                } footer: {
                    Text("Your key is stored in the device Keychain and never leaves your device.")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                }
                .listRowBackground(Color.sousBackground)
                .listRowSeparatorTint(Color.sousSeparator)
            }
            .scrollContentBackground(.hidden)
            .background(Color.sousBackground)
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") { dismiss() }
                        .font(.sousButton)
                        .foregroundStyle(Color.sousText)
                }
            }
            .onAppear {
                keyIsPresent = store.keyProvider.currentKey() != nil
            }
        }
    }
}

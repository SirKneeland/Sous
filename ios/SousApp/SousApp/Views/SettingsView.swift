import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var authState: AuthState
    @Binding var navigateToMemories: Bool

    @State private var keyInput = ""
    @State private var keyIsPresent: Bool = false
    @Environment(\.dismiss) private var dismiss
    // TEMP: remove once texture intensity is finalized
    @AppStorage("debugTextureIntensity") private var textureIntensity: Double = 0.6
    @State private var showingTexturePreview = false

    // Account section state
    @State private var displayNameDraft: String = ""
    @FocusState private var nameFieldFocused: Bool
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    // Usage display state (fetched on appear).
    @State private var usageSummary: UsageSummary?
    @State private var usageLoading = false

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

                // MARK: Voice
                Section {
                    Picker("Voice", selection: Binding(
                        get: { store.userPreferences.voiceGender },
                        set: { newValue in
                            var prefs = store.userPreferences
                            prefs.voiceGender = newValue
                            store.updatePreferences(prefs)
                        }
                    )) {
                        ForEach(VoiceGender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Accent", selection: Binding(
                        get: { store.userPreferences.voiceAccent },
                        set: { newValue in
                            var prefs = store.userPreferences
                            prefs.voiceAccent = newValue
                            store.updatePreferences(prefs)
                        }
                    )) {
                        ForEach(VoiceAccent.allCases, id: \.self) { accent in
                            Text(accent.rawValue).tag(accent)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("VOICE")
                        .font(.sousSectionHeader)
                        .foregroundStyle(Color.sousTerracotta)
                        .kerning(1.2)
                        .textCase(nil)
                } footer: {
                    Text("The voice and accent Sous uses when you talk to it hands-free.")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                }
                .listRowBackground(Color.sousBackground)
                .listRowSeparatorTint(Color.sousSeparator)

                // MARK: Account
                accountSection

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
                            store.hasAPIKey = keyIsPresent
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
                                store.hasAPIKey = keyIsPresent
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

                // MARK: Debug
                Section {
                    // TEMP: remove once texture intensity is finalized
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipe texture intensity")
                            .font(.sousBody)
                            .foregroundStyle(Color.sousText)
                        Slider(value: $textureIntensity, in: 0...1)
                            .tint(Color.sousTerracotta)
                    }
                    .padding(.vertical, 4)

                    // TEMP: remove once texture intensity is finalized
                    Button("Preview Texture") {
                        showingTexturePreview = true
                    }
                    .font(.sousBody)
                    .foregroundStyle(Color.sousTerracotta)
                    .fullScreenCover(isPresented: $showingTexturePreview) {
                        TexturePreviewView()
                    }
                } header: {
                    Text("DEBUG")
                        .font(.sousSectionHeader)
                        .foregroundStyle(Color.sousTerracotta)
                        .kerning(1.2)
                        .textCase(nil)
                }
                .listRowBackground(Color.sousBackground)
                .listRowSeparatorTint(Color.sousSeparator)
            }
            .scrollContentBackground(.hidden)
            .background(
                NavigationLink(destination: MemoriesView(store: store), isActive: $navigateToMemories) { EmptyView() }
            )
            .background(Color.sousBackground)
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") {
                        commitDisplayName()
                        dismiss()
                    }
                    .font(.sousButton)
                    .foregroundStyle(Color.sousText)
                }
            }
            .onAppear {
                keyIsPresent = store.keyProvider.currentKey() != nil
                displayNameDraft = authState.profile?.displayName ?? ""
            }
            .onChange(of: authState.profile?.displayName) { _, newValue in
                displayNameDraft = newValue ?? ""
            }
            .alert("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task { await authState.signOut() }
                }
            } message: {
                Text("You'll need to sign in again to use Sous.")
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await performDeleteAccount() }
                }
            } message: {
                Text("This will permanently delete your account, recipes, memories, and preferences. This cannot be undone.")
            }
            .alert("Couldn't Delete Account", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
            .task { await loadUsage() }
        }
    }

    // MARK: - Account section

    @ViewBuilder
    private var accountSection: some View {
        Section {
            // Display name — editable inline, synced to backend on commit.
            HStack {
                Text("Name")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                Spacer()
                TextField("Add your name", text: $displayNameDraft)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .focused($nameFieldFocused)
                    .onSubmit { commitDisplayName() }
                    // Commit when the field loses focus (e.g. tapping elsewhere or
                    // dismissing Settings), not only on the keyboard return key.
                    .onChange(of: nameFieldFocused) { _, focused in
                        if !focused { commitDisplayName() }
                    }
            }

            // Email — read-only.
            HStack {
                Text("Email")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                Spacer()
                Text(authState.profile?.email ?? "—")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousMuted)
            }

            // Subscription status — plain English.
            HStack {
                Text("Plan")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                Spacer()
                if isBYOK {
                    Text("OG")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousBackground)
                        .kerning(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.sousTerracotta)
                }
                Text(subscriptionStatusText)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousMuted)
            }

            // Usage — recipes used this billing period (or BYOK note).
            usageDisplayRow

            // Manage Subscription — deep link to iOS subscription settings.
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Manage Subscription")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
            }

            // Refer a friend — referral code + share sheet.
            if let code = authState.profile?.referralCode, !code.isEmpty {
                ShareLink(item: referralShareText(code: code)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share Sous")
                                .font(.sousBody)
                                .foregroundStyle(Color.sousText)
                            Text("Your code: \(code)")
                                .font(.sousCaption)
                                .foregroundStyle(Color.sousMuted)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.sousTerracotta)
                    }
                }
            }

            // Sign Out.
            Button {
                showSignOutConfirm = true
            } label: {
                Text("Sign Out")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
            }

            // Delete Account — destructive.
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Text("Delete Account")
                        .font(.sousBody)
                        .foregroundStyle(Color.sousTerracotta)
                    if isDeleting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isDeleting)
        } header: {
            Text("ACCOUNT")
                .font(.sousSectionHeader)
                .foregroundStyle(Color.sousTerracotta)
                .kerning(1.2)
                .textCase(nil)
        }
        .listRowBackground(Color.sousBackground)
        .listRowSeparatorTint(Color.sousSeparator)
    }

    // MARK: - Usage display

    /// One line summarizing recipe usage this period. BYOK users see a no-limits
    /// note; everyone else sees "X of N recipes …", a loading state, or "--" on
    /// fetch failure.
    @ViewBuilder
    private var usageDisplayRow: some View {
        Group {
            if isBYOK {
                Text("Using your own API key · No limits apply")
            } else if let summary = usageSummary {
                Text(usageText(summary))
            } else if usageLoading {
                Text("Loading usage…")
            } else {
                Text("--")
            }
        }
        .font(.sousCaption)
        .foregroundStyle(Color.sousMuted)
    }

    private func usageText(_ s: UsageSummary) -> String {
        if s.entitlement == "trialing",
           let used = s.trialRecipesUsed, let cap = s.trialRecipeCap {
            let days = s.trialDaysRemaining ?? 0
            return "\(used) of \(cap) recipes used · \(days) day\(days == 1 ? "" : "s") left in trial"
        }
        return "\(s.recipesUsed) of \(s.recipeCap) recipes this month · Resets in \(s.resetsInDays) day\(s.resetsInDays == 1 ? "" : "s")"
    }

    private func loadUsage() async {
        guard !isBYOK else { return }
        usageLoading = true
        usageSummary = await store.fetchUsageSummary()
        usageLoading = false
    }

    // MARK: - Account helpers

    private var isBYOK: Bool {
        authState.entitlement == .byok || authState.profile?.isByokEligible == true
    }

    private var subscriptionStatusText: String {
        switch authState.entitlement {
        case .byok:       return "Bring Your Own Key"
        case .subscriber: return "Active Subscriber"
        case .trialing:   return "Free Trial"
        case .grace:      return "Payment Issue"
        case .softWall:   return "Trial Ended"
        case .none:       return "—"
        }
    }

    private func referralShareText(code: String) -> String {
        "Join me on Sous! Use my code \(code) to sign up"
    }

    private func commitDisplayName() {
        let trimmed = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String? = trimmed.isEmpty ? nil : trimmed
        // No-op when unchanged so closing Settings doesn't fire redundant syncs.
        let current = authState.profile?.displayName
        guard value != (current?.isEmpty == true ? nil : current) else { return }
        authState.setDisplayName(value)
        store.updateDisplayName(value)
    }

    private func performDeleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await authState.deleteAccount()
            store.clearAllLocalData()
        } catch {
            deleteError = "Something went wrong. Please check your connection and try again."
        }
    }
}

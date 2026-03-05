import SwiftUI
import SousCore

struct ChatSheetView: View {
    @ObservedObject var store: AppStore
    @State private var composerText = ""
    @State private var debugExpanded = false
#if DEBUG
    @State private var keyInput = ""
#endif

    private var hasPendingPatch: Bool {
        store.uiState.isPatchProposed
    }

    var body: some View {
        if hasPendingPatch {
            patchPendingView
        } else {
            chatView
        }
    }

    // MARK: - Patch pending

    private var patchPendingView: some View {
        VStack(spacing: 12) {
            Text("Chat").font(.headline)
            Spacer()
            Text("Patch received — pending validation")
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            Button("Validate Patch") {
                store.send(.validatePatch)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    // MARK: - Chat view

    private var chatView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Chat").font(.headline)
                Spacer()
                Button("Close") { store.send(.closeChat) }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // Transcript
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(store.chatTranscript) { message in
                            ChatBubbleView(message: message)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: store.chatTranscript.count) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            Divider()

            // Debug
            DisclosureGroup("Debug", isExpanded: $debugExpanded) {
                HStack(spacing: 8) {
                    Button("Valid Patch") { store.simulateValidPatch() }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    Button("Invalid Patch") { store.simulateInvalidPatch() }
                        .buttonStyle(.bordered)
                        .font(.caption)
                }
                .padding(.top, 4)
#if DEBUG
                if let status = store.llmDebugStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(
                            status.contains("missing") || status.contains("failed")
                                ? Color.red
                                : Color.secondary
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                Divider().padding(.vertical, 4)
                Text("Key Present: \(store.keyProvider.currentKey() != nil ? "Yes" : "No")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    SecureField("OpenAI Key", text: $keyInput)
                        .font(.footnote)
                        .textContentType(.password)
                    Button("Save") {
                        store.keyProvider.setKey(keyInput)
                        keyInput = ""
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Clear") {
                        store.keyProvider.clearKey()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
#endif
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Composer
            composerBar
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
    }

    // MARK: - Composer

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $composerText)
                .frame(maxHeight: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.4))
                )
                .overlay(
                    Group {
                        if composerText.isEmpty {
                            Text("Message…")
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 4)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )

            Button {
                store.sendUserMessage(composerText)
                composerText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Bubble

private struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .font(.body)
            if !isUser { Spacer(minLength: 48) }
        }
    }
}

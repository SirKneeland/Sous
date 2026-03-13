import Combine
import SousCore
import SwiftUI

struct ChatSheetView: View {
    @ObservedObject var store: AppStore
    /// When true, the view fills the screen rather than appearing as a sheet.
    /// The Close button is hidden; a Settings button appears instead.
    var isFullscreen: Bool = false
    var onOpenSettings: () -> Void = {}
    var onOpenRecents: () -> Void = {}
    @StateObject private var photoSend = PhotoSendCoordinator()
    @State private var composerText = ""
    @State private var debugExpanded = false
    @State private var showPhotoSheet = false
#if DEBUG
    @State private var debugCopied = false
#endif

    var body: some View {
        chatView
    }

    // MARK: - Chat view

    private var chatView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                if isFullscreen {
                    Text("Sous").font(.headline)
                } else {
                    Text("Chat").font(.headline)
                }
                Spacer()
                if isFullscreen {
                    HStack(spacing: 16) {
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
                } else {
                    Button("Close") { store.send(.closeChat) }
                }
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
                        if store.isThinking {
                            ThinkingBubbleView()
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: store.chatTranscript.count) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: store.isThinking) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .overlay(alignment: .top) {
                    if let proposal = store.pendingMemoryProposal {
                        MemoryProposalToast(
                            text: proposal,
                            onSave: { text in store.confirmMemory(text: text) },
                            onDismiss: { store.dismissMemoryProposal() }
                        )
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: store.pendingMemoryProposal != nil)
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
                HStack(spacing: 8) {
                    Button(debugCopied ? "Copied" : "Copy Debug Info") {
                        let json: String
                        if let bundle = store.lastDebugBundle {
                            json = LLMDebugExport.make(from: bundle).jsonString()
                        } else {
                            json = "{}"
                        }
                        UIPasteboard.general.string = json
                        debugCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            debugCopied = false
                        }
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

            // Attachment preview strip (shown when an image is attached or preparing)
            attachmentStrip

            // Composer
            composerBar
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
    }

    // MARK: - Attachment strip

    /// Shown above the composer when an image is attached, preparing, or failed.
    @ViewBuilder
    private var attachmentStrip: some View {
        switch photoSend.attachmentState {
        case .idle:
            EmptyView()

        case .previewing(_, let thumbnail):
            HStack(spacing: 10) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Photo attached")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    photoSend.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            Divider()

        case .preparing:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Preparing image…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 6)
            Divider()

        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text("Image could not be prepared.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                Spacer()
                Button("Dismiss") { photoSend.clear() }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            Divider()
        }
    }

    // MARK: - Composer

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                showPhotoSheet = true
            } label: {
                Image(systemName: "camera")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showPhotoSheet) {
                PhotoAcquisitionSheet(
                    onAcquired: { asset in
                        photoSend.attach(asset)
                        showPhotoSheet = false
                    },
                    onCancel: { showPhotoSheet = false }
                )
            }

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
                sendAction()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Send logic

    private var canSendText: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        (canSendText || photoSend.attachmentState.canSend)
            && !photoSend.attachmentState.isInFlight
            && !store.isLLMCallInFlight
    }

    private func sendAction() {
        if photoSend.attachmentState.canSend {
            // Photo send: capture text snapshot, run preparation, clear only on success.
            guard !store.hasActivePatch, !store.isLLMCallInFlight else { return }
            let capturedText = composerText
            let recipeSnapshot = store.uiState.recipe
            Task {
                if let multimodalReq = await photoSend.send(text: capturedText, recipe: recipeSnapshot) {
                    // Preparation succeeded — append message, clear composer, then dispatch LLM.
                    store.appendPhotoMessage(capturedText)
                    composerText = ""
                    store.sendMultimodalRequest(multimodalReq)
                }
                // Failure: composerText untouched; attachmentStrip shows error.
            }
        } else {
            // Text-only send: existing path unchanged.
            store.sendUserMessage(composerText)
            composerText = ""
        }
    }
}

// MARK: - Thinking bubble

private struct ThinkingBubbleView: View {
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.75)
                Text("Thinking…")
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .font(.body)
            Spacer(minLength: 48)
        }
    }
}

// MARK: - Memory Proposal Toast

private struct MemoryProposalToast: View {
    let text: String
    let onSave: (String) -> Void
    let onDismiss: () -> Void

    @State private var isEditing = false
    @State private var editText: String
    @State private var startDate = Date()
    @State private var displayProgress: Double = 1.0
    @State private var timerPaused = false
    @State private var hasSaved = false

    // 0.1s ticker drives smooth progress and auto-save without discrete jumps
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(text: String, onSave: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.text = text
        self.onSave = onSave
        self.onDismiss = onDismiss
        _editText = State(initialValue: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                TextField("Memory text", text: $editText)
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 6) {
                    Button("Save") { hasSaved = true; onSave(editText) }
                        .font(.caption2)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    Button("Cancel") { isEditing = false; editText = text }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Save") { timerPaused = true; hasSaved = true; onSave(text) }
                        .font(.caption2)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    Button("Edit") { timerPaused = true; isEditing = true }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    Button("Skip") { onDismiss() }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: displayProgress)
                    .tint(Color.secondary.opacity(0.4))
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .padding(.horizontal, 12)
        .simultaneousGesture(TapGesture().onEnded { timerPaused = true })
        .onReceive(ticker) { _ in
            guard !timerPaused && !hasSaved && !isEditing else { return }
            let elapsed = Date().timeIntervalSince(startDate)
            displayProgress = max(0, 1.0 - elapsed / 10.0)
            if elapsed >= 10 {
                hasSaved = true
                onSave(text)
            }
        }
    }
}

// MARK: - Bubble

private struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            messageContent
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !isUser { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if isUser {
            Text(message.text)
                .font(.body)
                .foregroundStyle(Color.white)
        } else {
            MarkdownTextView(text: message.text, textColor: .primary)
        }
    }
}

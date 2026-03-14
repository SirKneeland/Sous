import Combine
import SousCore
import SwiftUI

struct ChatSheetView: View {
    @ObservedObject var store: AppStore
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
        Group {
            if isFullscreen && store.chatTranscript.isEmpty {
                blankStateView
            } else {
                mainChatView
            }
        }
    }

    // MARK: - Blank State

    private var blankStateView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    SousIconButton(systemName: "clock") { onOpenRecents() }
                    SousIconButton(systemName: "gearshape") { onOpenSettings() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            Spacer()

            VStack(spacing: 10) {
                Text("SOUS")
                    .font(.sousLogotype)
                    .foregroundStyle(Color.sousText)
                Text("YOUR COOKING COMPANION")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
                    .kerning(1.2)
            }

            Spacer()

            SousRule()
            composerBar
        }
        .background(Color.sousBackground.ignoresSafeArea())
    }

    // MARK: - Main Chat View

    private var mainChatView: some View {
        VStack(spacing: 0) {
            chatHeader
            SousRule()
            transcript
            SousRule()
            debugSection
            attachmentStrip
            composerBar
        }
        .background(isFullscreen ? Color.sousBackground : Color.sousSurface)
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            if isFullscreen {
                Text("SOUS")
                    .font(.sousButton)
                    .foregroundStyle(Color.sousText)
            } else {
                Text("ASSISTANT")
                    .font(.sousButton)
                    .foregroundStyle(Color.sousText)
            }
            Spacer()
            if isFullscreen {
                HStack(spacing: 8) {
                    SousIconButton(systemName: "clock") { onOpenRecents() }
                    SousIconButton(systemName: "gearshape") { onOpenSettings() }
                }
            } else {
                Button("CLOSE") { store.send(.closeChat) }
                    .font(.sousButton)
                    .foregroundStyle(Color.sousTerracotta)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Transcript

    private var transcript: some View {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
    }

    // MARK: - Debug Section

    @ViewBuilder
    private var debugSection: some View {
        DisclosureGroup("Debug", isExpanded: $debugExpanded) {
            HStack(spacing: 8) {
                Button("Valid Patch") { store.simulateValidPatch() }
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Color.sousSeparator, lineWidth: 1))
                Button("Invalid Patch") { store.simulateInvalidPatch() }
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Color.sousSeparator, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
#if DEBUG
            if let status = store.llmDebugStatus {
                Text(status)
                    .font(.sousCaption)
                    .foregroundStyle(
                        status.contains("missing") || status.contains("failed")
                            ? Color.sousTerracotta
                            : Color.sousMuted
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            SousRule().padding(.vertical, 4)
            HStack(spacing: 8) {
                Button(debugCopied ? "COPIED" : "COPY DEBUG INFO") {
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
                .font(.sousCaption)
                .foregroundStyle(Color.sousText)
                .buttonStyle(.plain)
            }
#endif
        }
        .font(.sousCaption)
        .foregroundStyle(Color.sousMuted)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)

        SousRule()
    }

    // MARK: - Attachment Strip

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
                    .frame(width: 48, height: 48)
                    .clipped()
                    .overlay(Rectangle().stroke(Color.sousSeparator, lineWidth: 1))
                Text("PHOTO ATTACHED")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
                Spacer()
                Button {
                    photoSend.clear()
                } label: {
                    Text("REMOVE")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousTerracotta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            SousRule()

        case .preparing:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color.sousMuted)
                Text("PREPARING IMAGE...")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            SousRule()

        case .failed:
            HStack(spacing: 8) {
                Text("IMAGE COULD NOT BE PREPARED.")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousTerracotta)
                Spacer()
                Button("DISMISS") { photoSend.clear() }
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            SousRule()
        }
    }

    // MARK: - Composer

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Camera button
            Button {
                showPhotoSheet = true
            } label: {
                Image(systemName: "camera")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.sousText)
                    .frame(width: 36, height: 36)
                    .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPhotoSheet) {
                PhotoAcquisitionSheet(
                    onAcquired: { asset in
                        photoSend.attach(asset)
                        showPhotoSheet = false
                    },
                    onCancel: { showPhotoSheet = false }
                )
            }

            // Text input
            ZStack(alignment: .topLeading) {
                if composerText.isEmpty {
                    Text("Type command...")
                        .font(.sousBody)
                        .foregroundStyle(Color.sousMuted)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $composerText)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(maxHeight: 80)
            }
            .padding(4)
            .background(Color.sousSurface)
            .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))

            // Send button
            Button {
                sendAction()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canSend ? Color.sousBackground : Color.sousMuted)
                    .frame(width: 36, height: 36)
                    .background(canSend ? Color.sousText : Color.clear)
                    .overlay(Rectangle().stroke(canSend ? Color.sousText : Color.sousMuted, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Send Logic

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
            guard !store.hasActivePatch, !store.isLLMCallInFlight else { return }
            let capturedText = composerText
            let recipeSnapshot = store.uiState.recipe
            Task {
                if let multimodalReq = await photoSend.send(text: capturedText, recipe: recipeSnapshot) {
                    store.appendPhotoMessage(capturedText)
                    composerText = ""
                    store.sendMultimodalRequest(multimodalReq)
                }
            }
        } else {
            store.sendUserMessage(composerText)
            composerText = ""
        }
    }
}

// MARK: - Thinking Bubble

private struct ThinkingBubbleView: View {
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(Color.sousMuted)
                Text("Thinking...")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.sousBackground)
            .overlay(Rectangle().stroke(Color.sousSeparator, lineWidth: 1))
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

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(text: String, onSave: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.text = text
        self.onSave = onSave
        self.onDismiss = onDismiss
        _editText = State(initialValue: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Memory text", text: $editText)
                        .font(.sousBody)
                        .foregroundStyle(Color.sousText)
                        .padding(8)
                        .overlay(Rectangle().stroke(Color.sousSeparator, lineWidth: 1))
                    HStack(spacing: 12) {
                        Button("SAVE") { hasSaved = true; onSave(editText) }
                            .font(.sousButton)
                            .foregroundStyle(Color.sousTerracotta)
                            .buttonStyle(.plain)
                        Button("CANCEL") { isEditing = false; editText = text }
                            .font(.sousButton)
                            .foregroundStyle(Color.sousMuted)
                            .buttonStyle(.plain)
                    }
                }
                .padding(12)
            } else {
                HStack(spacing: 8) {
                    Text(text)
                        .font(.sousBody)
                        .foregroundStyle(Color.sousText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("SAVE") { timerPaused = true; hasSaved = true; onSave(text) }
                        .font(.sousButton)
                        .foregroundStyle(Color.sousTerracotta)
                        .buttonStyle(.plain)
                    Button("EDIT") { timerPaused = true; isEditing = true }
                        .font(.sousButton)
                        .foregroundStyle(Color.sousTerracotta)
                        .buttonStyle(.plain)
                    Button("SKIP") { onDismiss() }
                        .font(.sousButton)
                        .foregroundStyle(Color.sousMuted)
                        .buttonStyle(.plain)
                }
                .padding(12)
                // Progress bar
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.sousTerracotta.opacity(0.4))
                        .frame(width: geo.size.width * displayProgress, height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 2)
            }
        }
        .background(Color.sousBackground)
        .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
        .padding(.horizontal, 16)
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

// MARK: - Chat Bubble

private struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            messageContent
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.sousText : Color.sousBackground)
                .overlay(
                    Rectangle()
                        .stroke(isUser ? Color.sousText : Color.sousText, lineWidth: 1)
                )
            if !isUser { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if isUser {
            Text(message.text)
                .font(.sousBody)
                .foregroundStyle(Color.sousBackground)
        } else {
            MarkdownTextView(text: message.text, textColor: .sousText)
        }
    }
}

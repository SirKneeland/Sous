import Combine
import SousCore
import SwiftUI
import UIKit

struct ChatSheetView: View {
    @ObservedObject var store: AppStore
    var isFullscreen: Bool = false
    var onStartNew: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onOpenRecents: () -> Void = {}
    var onOpenImport: () -> Void = {}
    @StateObject private var photoSend = PhotoSendCoordinator()
    @State private var composerText = ""
    @State private var composerHeight: CGFloat = 36
    @State private var showPhotoSheet = false
    @State private var inputBarDragOffset: CGFloat = 0

    var body: some View {
        Group {
            if isFullscreen && store.chatTranscript.isEmpty {
                blankStateView
            } else {
                mainChatView
            }
        }
#if DEBUG
        .modifier(DebugTapExportModifier(store: store))
#endif
    }

    // MARK: - Blank State

    private var blankStateView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    SousIconButton(systemName: "plus") { onStartNew() }
                    SousIconButton(systemName: "clock") { onOpenRecents() }
                    SousIconButton(systemName: "gearshape") { onOpenSettings() }
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: GearButtonFrameKey.self,
                                                   value: geo.frame(in: .named("contentRoot")))
                        })
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

            // Import CTA
            VStack(spacing: 24) {
                Button {
                    onOpenImport()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 14, weight: .regular))
                        Text("TALK TO A RECIPE")
                            .font(.sousButton)
                    }
                    .foregroundStyle(Color.sousBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sousText)
                    .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 6) {
                        Text("OR CREATE ONE")
                            .font(.sousCaption)
                            .foregroundStyle(Color.sousMuted)
                            .kerning(1.0)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .light))
                            .foregroundStyle(Color.sousMuted)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)

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
                .overlay(alignment: .bottom) { generatePill }
            SousRule()
            attachmentStrip
            composerBar
        }
        .background(isFullscreen ? Color.sousBackground : Color.sousSurface)
        .animation(.easeOut(duration: 0.25), value: store.canGenerateRecipe)
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            if isFullscreen {
                Text("SOUS")
                    .font(.sousButton)
                    .foregroundStyle(Color.sousText)
            } else {
                Text("SOUS SAYS...")
                    .font(.sousButton)
                    .foregroundStyle(Color.sousText)
            }
            Spacer()
            if isFullscreen {
                HStack(spacing: 8) {
                    SousIconButton(systemName: "plus") { onStartNew() }
                    SousIconButton(systemName: "clock") { onOpenRecents() }
                    SousIconButton(systemName: "gearshape") { onOpenSettings() }
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: GearButtonFrameKey.self,
                                                   value: geo.frame(in: .named("contentRoot")))
                        })
                }
            } else {
                Button("CLOSE") { store.send(.closeChat) }
                    .font(.sousButton)
                    .foregroundStyle(Color.sousTerracotta)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
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
                    if let partial = store.streamingAssistantMessage {
                        StreamingBubbleView(text: partial)
                    } else if store.isThinking {
                        ThinkingBubbleView()
                    }
                    // Reserves space equal to the generate button height so the last
                    // message is never hidden under the floating overlay button.
                    if !store.hasCanvas && store.canGenerateRecipe {
                        Color.clear.frame(height: 52)
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
            .onChange(of: store.streamingAssistantMessage) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: store.canGenerateRecipe) { newValue in
                if newValue { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) } }
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

    // MARK: - Generate Pill

    @ViewBuilder
    private var generatePill: some View {
        if !store.hasCanvas && store.canGenerateRecipe {
            Button {
                store.sendGenerateRecipeSilently()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .regular))
                    Text("Make this recipe")
                        .font(.sousButton)
                }
                .foregroundStyle(Color.sousBackground)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.sousTerracotta)
                .overlay(Rectangle().stroke(Color.sousTerracotta, lineWidth: 1))
            }
            .buttonStyle(.plain)
            // 16 (composerBar outer padding) + 44 (camera/send button) + 8 (HStack spacing)
            // = 68px each side — aligns exactly with the text input field edges
            .padding(.horizontal, 68)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    .frame(width: 44, height: 44)
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
                // Hidden text used to measure content height
                Text(composerText.isEmpty ? " " : composerText)
                    .font(.sousBody)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ComposerHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    )
                    .onPreferenceChange(ComposerHeightPreferenceKey.self) { height in
                        composerHeight = max(height, 36)
                    }
                if composerText.isEmpty {
                    Text("Ask Sous...")
                        .font(.sousBody)
                        .foregroundStyle(Color.sousMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $composerText)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: composerHeight)
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
                    .frame(width: 44, height: 44)
                    .background(canSend ? Color.sousText : Color.clear)
                    .overlay(Rectangle().stroke(canSend ? Color.sousText : Color.sousMuted, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            // Invisible extension strip: widens gesture zone 14pt above the input bar
            // without affecting the input bar's layout or visual appearance.
            Color.clear
                .frame(height: 14)
                .offset(y: -14)
                .contentShape(Rectangle())
                .simultaneousGesture(thumbDropGesture)
        }
        .overlay(alignment: .bottom) {
            // ThumbDrop affordance hint — only shown when a canvas exists
            if !isFullscreen {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.sousMuted)
                    .offset(y: 16)
                    .allowsHitTesting(false)
            }
        }
        .simultaneousGesture(thumbDropGesture)
        .offset(y: inputBarDragOffset)
    }

    // MARK: - ThumbDrop Gesture

    private var thumbDropGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isFullscreen else { return }
                let raw = value.translation.height
                guard raw > 0 else {
                    inputBarDragOffset = 0
                    return
                }
                inputBarDragOffset = min(raw * 0.65, 60)
            }
            .onEnded { value in
                guard !isFullscreen else { return }
                let downward = value.translation.height >= 20
                guard downward else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        inputBarDragOffset = 0
                    }
                    return
                }
                inputBarDragOffset = 0
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                store.send(.closeChat)
            }
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

// MARK: - Composer Height Preference Key

private struct ComposerHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 36
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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

// MARK: - Streaming Bubble

/// Shows the assistant's reply as it streams in, with a blinking cursor.
/// Replaces ThinkingBubbleView once the first token has arrived.
private struct StreamingBubbleView: View {
    let text: String
    @State private var cursorOpacity: Double = 1.0

    var body: some View {
        HStack {
            HStack(alignment: .center, spacing: 2) {
                MarkdownTextView(text: text.isEmpty ? " " : text, textColor: .sousText)
                    .animation(.easeIn(duration: 0.15), value: text)
                Rectangle()
                    .fill(Color.sousText)
                    .frame(width: 2, height: 14)
                    .opacity(cursorOpacity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.sousBackground)
            .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
            Spacer(minLength: 48)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                cursorOpacity = 0
            }
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

import Combine
import SousCore
import SwiftUI
import UIKit

struct ChatSheetView: View {
    @ObservedObject var store: AppStore
    var isFullscreen: Bool = false
    /// True when the overlay is visible (always true for the fullscreen blank-state chat).
    /// Used to trigger focus and keyboard in the same frame the overlay animates in.
    var isPresented: Bool = true
    var onStartNew: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onOpenRecents: () -> Void = {}
    var onOpenImport: () -> Void = {}
    /// Called with true when the camera sheet opens, false when it closes.
    var onCameraPresented: (Bool) -> Void = { _ in }
    var onNavigateToMemories: () -> Void = {}
    @StateObject private var photoSend = PhotoSendCoordinator()
    @State private var composerText = ""
    @State private var composerHeight: CGFloat = 36
    @State private var showPhotoSheet = false
    @State private var inputBarDragOffset: CGFloat = 0
    @State private var sheetBounceOffset: CGFloat = 0
    @State private var peakDragVelocity: CGFloat = 0
    // Slingshot haptic gates — reset at the start of each gesture.
    @State private var sling1Fired = false  // 30 pt → .light
    @State private var sling2Fired = false  // 60 pt → .medium
    @State private var sling3Fired = false  // 90 pt → .rigid
    @FocusState private var isComposerFocused: Bool
    /// One-shot gate: set on sheet open, consumed by keyboardWillShowNotification to snap
    /// to bottom as the keyboard begins rising rather than after it lands.
    @State private var scrollOnKeyboardShow: Bool = false

    var body: some View {
        Group {
            if isFullscreen && store.chatTranscript.isEmpty {
                blankStateView
            } else {
                mainChatView
            }
        }
        .offset(y: sheetBounceOffset)
        // Root-level ThumbDrop zone: activates for the entire bottom fifth of the
        // screen when the chat sheet is presented in non-fullscreen (sheet) mode.
        // The input bar's own DragGesture remains unchanged and coexists with this.
        .background {
            ThumbDropOverlay(
                isActive: !isFullscreen && isPresented,
                onOffsetChanged: { inputBarDragOffset = $0 },
                onCommit: thumbDropCommit,
                onCancel: thumbDropCancel
            )
        }
#if DEBUG
        .modifier(DebugTapExportModifier(store: store))

#endif
        .onAppear {
            // Fullscreen blank-state: focus only if a quoted context arrived before appear.
            // Overlay (non-fullscreen): focus is handled by onChange(of: isPresented) below,
            // since the view is always in the hierarchy and onAppear won't re-fire on open.
            if isFullscreen && store.quotedRowContext != nil {
                isComposerFocused = true
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue && !isFullscreen {
                scrollOnKeyboardShow = true
                isComposerFocused = true
                inputBarDragOffset = 0
                sheetBounceOffset = 0
            } else if !newValue && !isFullscreen {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }
        .onChange(of: store.quotedRowContext) { newValue in
            if newValue != nil {
                isComposerFocused = true
            }
        }
        .onChange(of: showPhotoSheet) { _, newValue in
            onCameraPresented(newValue)
        }
        .sheet(isPresented: $showPhotoSheet) {
            PhotoAcquisitionSheet(
                onAcquired: { asset in
                    photoSend.attach(asset)
                    showPhotoSheet = false
                    isComposerFocused = true
                },
                onCancel: { showPhotoSheet = false }
            )
        }
    }

    // MARK: - Blank State

    private var blankStateView: some View {
        VStack(spacing: 0) {
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
            attachmentStrip
            composerBar
        }
        .background(Color.sousSurface.ignoresSafeArea())
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                Color.clear
                    .frame(height: 80)
                    .background(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                LinearGradient(
                    stops: [
                        .init(color: Color.sousSurface, location: 0),
                        .init(color: Color.sousSurface.opacity(0.9), location: 0.35),
                        .init(color: Color.sousSurface.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .top) {
            if let proposal = store.pendingMemoryProposal {
                MemoryProposalToast(
                    text: proposal,
                    onSave: { text, firstPersonText in Task { await store.saveMemoryOnly(text: text, firstPersonText: firstPersonText) } },
                    onComplete: { store.dismissMemoryProposal() },
                    onDismiss: { store.dismissMemoryProposal() },
                    onNavigateToMemories: { onNavigateToMemories() }
                )
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.pendingMemoryProposal != nil)
    }

    // MARK: - Main Chat View

    private var mainChatView: some View {
        VStack(spacing: 0) {
            if !isFullscreen {
                chatHeader
                SousRule()
            }
            transcript
                .overlay(alignment: .bottom) { generatePill }
            attachmentStrip
            SousRule()
                .opacity(inputBarDragOffset == 0 ? 1 : 0)
            composerBar
        }
        .background((showPhotoSheet ? Color(red: 117/255, green: 116/255, blue: 113/255) : Color.sousSurface).ignoresSafeArea(isFullscreen ? .all : .keyboard))
        .animation(.easeOut(duration: 0.25), value: store.canGenerateRecipe)
        .overlay(alignment: .top) {
            if let proposal = store.pendingMemoryProposal {
                MemoryProposalToast(
                    text: proposal,
                    onSave: { text, firstPersonText in Task { await store.saveMemoryOnly(text: text, firstPersonText: firstPersonText) } },
                    onComplete: { store.dismissMemoryProposal() },
                    onDismiss: { store.dismissMemoryProposal() },
                    onNavigateToMemories: { onNavigateToMemories() }
                )
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.pendingMemoryProposal != nil)
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
                .padding(.top, isFullscreen ? 72 : 12)
                .padding(.bottom, 12)
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                guard scrollOnKeyboardShow else { return }
                scrollOnKeyboardShow = false
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
            .zIndex(1)

            // Text input (with optional quoted context chip above)
            VStack(spacing: 0) {
                if let ctx = store.quotedRowContext {
                    QuotedContextChip(context: ctx) {
                        store.quotedRowContext = nil
                    }
                }
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
                        .focused($isComposerFocused)
                }
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
            .zIndex(1)
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
        .zIndex(1)
        .offset(y: inputBarDragOffset)
    }

    // MARK: - ThumbDrop Gesture

    private var thumbDropGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isFullscreen else { return }
                // Reset peak and haptic gates at the start of each new gesture.
                if abs(value.translation.height) < 15 && abs(value.translation.width) < 15 {
                    peakDragVelocity = 0
                    sling1Fired = false
                    sling2Fired = false
                    sling3Fired = false
                }
                let raw = value.translation.height
                let vy = value.velocity.height
                let dist = abs(raw)
                if raw > 0 {
                    // Downward drag: dampen and clamp offset downward.
                    inputBarDragOffset = min(raw * 0.65, 60)
                    if vy > peakDragVelocity { peakDragVelocity = vy }
                } else if raw < 0 {
                    // Upward drag: mirror offset symmetrically (negative = moves up).
                    inputBarDragOffset = max(raw * 0.65, -60)
                    // Store upward velocity as a negative value for threshold comparison.
                    if vy < peakDragVelocity { peakDragVelocity = vy }
                } else {
                    inputBarDragOffset = 0
                }
                // Slingshot haptics — fire once as |translation| crosses each threshold,
                // regardless of drag direction. Back-and-forth motion does not re-trigger.
                if dist >= 30 && !sling1Fired {
                    sling1Fired = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                if dist >= 60 && !sling2Fired {
                    sling2Fired = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                if dist >= 90 && !sling3Fired {
                    sling3Fired = true
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            }
            .onEnded { value in
                guard !isFullscreen else { return }
                let dy = value.translation.height
                let commits = dy >= 50 || peakDragVelocity >= 400
                    || dy <= -50 || peakDragVelocity <= -400
                if commits {
                    thumbDropCommit()
                } else {
                    thumbDropCancel()
                }
            }
    }

    /// Fires the ThumbDrop commit action: haptic, anticipation bounce, then dismiss.
    /// Called by both the input bar DragGesture and the root-level ThumbDropOverlay.
    private func thumbDropCommit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
            sheetBounceOffset = -18
            inputBarDragOffset = 0
        } completion: {
            store.send(.closeChat)
            sheetBounceOffset = 0
        }
    }

    /// Springs the input bar back to rest. Called when a ThumbDrop gesture is
    /// cancelled or does not meet the commit threshold.
    private func thumbDropCancel() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            inputBarDragOffset = 0
            sheetBounceOffset = 0
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
                    store.appendPhotoMessage(capturedText, imageData: multimodalReq.image.data)
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
    let onSave: (String, String?) -> Void
    let onComplete: () -> Void
    let onDismiss: () -> Void
    let onNavigateToMemories: () -> Void

    @State private var isEditing = false
    @State private var editText: String
    @State private var displayText: String
    @State private var firstPersonSnapshot: String? = nil
    @State private var startDate = Date()
    @State private var displayProgress: Double = 1.0
    @State private var timerPaused = false
    @State private var isEditShimmering = false
    @State private var isDisplayShimmering = false
    @State private var hasCommittedEdit = false
    @State private var hasCompleted = false
    @State private var editStreamTask: Task<Void, Never>? = nil
    @State private var saveStreamTask: Task<Void, Never>? = nil
    @State private var prefetchedFirstPerson: String? = nil
    @State private var prefetchTask: Task<Void, Never>? = nil
    @FocusState private var isFieldFocused: Bool

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let countdownDuration: TimeInterval = 6.0

    init(text: String, onSave: @escaping (String, String?) -> Void, onComplete: @escaping () -> Void, onDismiss: @escaping () -> Void, onNavigateToMemories: @escaping () -> Void) {
        self.text = text
        self.onSave = onSave
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        self.onNavigateToMemories = onNavigateToMemories
        _editText = State(initialValue: text)
        _displayText = State(initialValue: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    if isEditShimmering {
                        MemoryShimmerBar()
                            .frame(height: 36)
                            .overlay(Rectangle().stroke(Color.sousSeparator, lineWidth: 1))
                    } else {
                        TextField("Memory text", text: $editText)
                            .font(.sousBody)
                            .foregroundStyle(Color.sousText)
                            .padding(8)
                            .background(Color.sousBackground)
                            .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                            .focused($isFieldFocused)
                            .onSubmit { commitSave() }
                    }
                    HStack(spacing: 12) {
                        Button("SAVE") { commitSave() }
                            .font(.sousButton)
                            .foregroundStyle(Color.white)
                            .buttonStyle(.plain)
                        Button("CANCEL") {
                            isFieldFocused = false
                            editStreamTask?.cancel()
                            editStreamTask = nil
                            isEditShimmering = false
                            isEditing = false
                            hasCommittedEdit = false
                            editText = text
                        }
                        .font(.sousButton)
                        .foregroundStyle(Color.sousBackground)
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("REMEMBERING THIS")
                        .font(.sousButton)
                        .foregroundStyle(Color.sousBackground)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                    if isDisplayShimmering {
                        MemoryShimmerBar()
                            .frame(height: 20)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    } else {
                        Text(displayText)
                            .font(.sousBody)
                            .foregroundStyle(Color.sousBackground)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    }
                    if !hasCommittedEdit {
                    HStack(spacing: 0) {
                        Button("SAVE") { hasCompleted = true; onSave(displayText, firstPersonSnapshot); onComplete() }
                            .font(.sousButton)
                            .foregroundStyle(Color.white)
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        Button("EDIT") {
                            isEditing = true
                            isFieldFocused = true
                            if let cached = prefetchedFirstPerson {
                                editText = cached
                                isEditShimmering = false
                            } else {
                                isEditShimmering = true
                                editText = ""
                                editStreamTask?.cancel()
                                editStreamTask = Task {
                                    if #available(iOS 26, macOS 26, *) {
                                        var gotFirst = false
                                        for await partial in MemoryPersonConverter.streamToFirstPerson(text: text) {
                                            if Task.isCancelled { break }
                                            if !gotFirst { isEditShimmering = false; gotFirst = true }
                                            editText = partial
                                        }
                                        if !gotFirst && !Task.isCancelled {
                                            editText = MemoryPersonConverter.naiveToFirstPerson(text)
                                            isEditShimmering = false
                                        }
                                    } else {
                                        try? await Task.sleep(nanoseconds: 80_000_000)
                                        guard !Task.isCancelled else { return }
                                        editText = MemoryPersonConverter.naiveToFirstPerson(text)
                                        isEditShimmering = false
                                    }
                                }
                            }
                        }
                        .font(.sousButton)
                        .foregroundStyle(Color.white)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        Button("SKIP") { hasCompleted = true; onDismiss() }
                            .font(.sousButton)
                            .foregroundStyle(Color.sousBackground)
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    } // end if !hasCommittedEdit
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: geo.size.width * displayProgress, height: 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(.linear(duration: 0.1), value: displayProgress)
                    }
                    .frame(height: 2)
                }
            }
        }
        .background(Color.sousTerracotta)
        .overlay(Rectangle().stroke(Color.sousTerracotta, lineWidth: 1))
        .padding(.horizontal, 16)
        .onTapGesture { onNavigateToMemories() }
        .gesture(DragGesture(minimumDistance: 20).onEnded { _ in
            hasCompleted = true
            if !hasCommittedEdit { onSave(displayText, firstPersonSnapshot) }
            onComplete()
        })
        .onAppear {
            prefetchTask = Task {
                let result = await MemoryPersonConverter.toFirstPerson(text: text)
                guard !Task.isCancelled else { return }
                prefetchedFirstPerson = result
            }
        }
        .onDisappear {
            prefetchTask?.cancel()
            prefetchTask = nil
        }
        .onReceive(ticker) { _ in
            guard !hasCompleted && !timerPaused && !isEditing else { return }
            let elapsed = Date().timeIntervalSince(startDate)
            displayProgress = max(0, 1.0 - elapsed / countdownDuration)
            if elapsed >= countdownDuration {
                hasCompleted = true
                if !hasCommittedEdit { onSave(displayText, firstPersonSnapshot) }
                onComplete()
            }
        }
    }

    private func commitSave() {
        isFieldFocused = false
        let snapshot = editText
        firstPersonSnapshot = snapshot
        hasCommittedEdit = true
        isEditing = false
        isDisplayShimmering = true
        editStreamTask?.cancel()
        editStreamTask = nil
        saveStreamTask?.cancel()
        saveStreamTask = Task {
            if #available(iOS 26, macOS 26, *) {
                var gotFirst = false
                for await partial in MemoryPersonConverter.streamToSecondPerson(text: snapshot) {
                    if Task.isCancelled { break }
                    if !gotFirst { isDisplayShimmering = false; gotFirst = true }
                    displayText = partial
                }
                if !gotFirst {
                    displayText = MemoryPersonConverter.naiveToSecondPerson(snapshot)
                    isDisplayShimmering = false
                }
            } else {
                try? await Task.sleep(nanoseconds: 80_000_000)
                displayText = MemoryPersonConverter.naiveToSecondPerson(snapshot)
                isDisplayShimmering = false
            }
            if displayText.last == "." { displayText = String(displayText.dropLast()) }
            startDate = Date()
            displayProgress = 1.0
            timerPaused = false
            onSave(displayText, firstPersonSnapshot)
        }
    }
}

// MARK: - Memory Shimmer Bar

private struct MemoryShimmerBar: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.sousSeparator.opacity(0.5)
                LinearGradient(
                    colors: [.clear, Color.sousText.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.55)
                .offset(x: (proxy.size.width + proxy.size.width * 0.55) * phase - proxy.size.width * 0.55)
            }
            .clipped()
        }
        .onAppear {
            phase = 0
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Quoted Context Chip

private struct QuotedContextChip: View {
    let context: QuotedRowContext
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(context.type == .ingredient ? "INGREDIENT" : "STEP")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousTerracotta)
                    .kerning(0.8)
                Text(context.text)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 13)
            .padding(.trailing, 10)
            .padding(.vertical, 4)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.sousMuted)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .background(Color.sousBackground)
        .overlay(alignment: .leading) {
            // Accent stripe as overlay — sized to content, never expands independently
            Color.sousTerracotta.frame(width: 3)
        }
        .overlay(Rectangle().stroke(Color.sousSeparator, lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
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
            VStack(alignment: .trailing, spacing: 6) {
                if let path = message.photoPath {
                    PhotoThumbnailView(relativePath: path)
                }
                if message.text != "[Photo]" || message.photoPath == nil {
                    Text(message.text)
                        .font(.sousBody)
                        .foregroundStyle(Color.sousBackground)
                }
            }
        } else {
            MarkdownTextView(text: message.text, textColor: .sousText)
        }
    }
}

// MARK: - Photo Thumbnail

private struct PhotoThumbnailView: View {
    let relativePath: String

    private var image: UIImage? {
        let url = PhotoPersistence.absoluteURL(for: relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        if let uiImage = image {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200)
                .clipped()
        } else {
            // Missing file placeholder — never crashes
            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundStyle(Color.sousBackground.opacity(0.5))
                .frame(width: 80, height: 60)
        }
    }
}

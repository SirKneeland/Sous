import AVFoundation
import SwiftUI
import SousCore
import UIKit

// MARK: - RecipeImportSheet

/// Full-screen sheet for importing an existing recipe from camera, photo library, or pasted text.
///
/// Manages its own navigation state (chooser → picker / paste → loading → error).
/// Success: AppStore sets `isShowingImportSheet = false`, which dismisses the sheet via the
/// parent Binding in ContentView. Error: `store.importError` is observed via `.onChange`.
struct RecipeImportSheet: View {
    @ObservedObject var store: AppStore
    let onCancel: () -> Void

    @State private var mode: Mode = .chooser
    @State private var pasteText: String = ""
    @State private var cameraAcquisitionState: CameraAcquisitionState = .idle
    @State private var selectedDetent: PresentationDetent = .fraction(0.4)
    @State private var clipboardHasText: Bool = false
    @State private var importProgress: Double = 0

    init(store: AppStore, onCancel: @escaping () -> Void) {
        _store = ObservedObject(wrappedValue: store)
        self.onCancel = onCancel
        // When the sheet is (re)presented for a unit conversion or a serving-size rescale,
        // open straight into the loading screen instead of the chooser.
        let opensInLoading = store.importLoadingStage == .converting || store.importLoadingStage == .rescaling
        _mode = State(initialValue: opensInLoading ? .loading : .chooser)
    }

    private enum Mode: Equatable {
        case chooser
        case camera
        case library
        case paste
        case loading
        case error(String)
    }

    var body: some View {
        ZStack {
            Color.sousBackground.ignoresSafeArea()

            switch mode {
            case .chooser:
                chooserView

            case .camera:
                cameraView
                    .ignoresSafeArea()

            case .library:
                PhotoLibraryPickerView(
                    onImage: { handleImage($0) },
                    onCancel: { mode = .chooser }
                )
                .ignoresSafeArea()

            case .paste:
                pasteView

            case .loading:
                loadingView

            case .error(let message):
                errorView(message: message)
            }
        }
        .presentationDetents([.fraction(0.4), .large], selection: $selectedDetent)
        .onChange(of: mode) { newMode in
            selectedDetent = (newMode == .chooser) ? .fraction(0.4) : .large
        }
        .onChange(of: store.importError) { error in
            guard let error else { return }
            mode = .error(error)
        }
        .onChange(of: store.importSuccess) { success in
            guard success else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                importProgress = 1.0
            }
            Task {
                // Wait for the 100% animation (0.25s) plus a brief pause at full.
                try? await Task.sleep(nanoseconds: 500_000_000)
                // Only dismiss if the user hasn't already cancelled back to the chooser.
                guard mode == .loading else { return }
                store.isShowingImportSheet = false
                // Reset stage so a later normal import open starts at the chooser.
                store.importLoadingStage = .llm
            }
        }
    }

    // MARK: - Chooser

    private var chooserView: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "TALK TO A RECIPE", showBack: false)
            SousRule()

            VStack(spacing: 0) {
                importOption(
                    icon: "camera",
                    title: "CAMERA",
                    subtitle: "Photograph a cookbook page or recipe card"
                ) { mode = .camera }

                SousRule()

                importOption(
                    icon: "photo.on.rectangle",
                    title: "PHOTO LIBRARY",
                    subtitle: "Select a screenshot or saved photo"
                ) { mode = .library }

                SousRule()

                importOption(
                    icon: "doc.on.clipboard",
                    title: "PASTE TEXT",
                    subtitle: "Paste raw recipe text directly"
                ) { mode = .paste }
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func importOption(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.sousIcon(.xLarge))
                    .foregroundStyle(Color.sousText)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.sousButton)
                        .foregroundStyle(Color.sousText)
                    Text(subtitle)
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.sousIcon(.small))
                    .foregroundStyle(Color.sousMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Camera (with permission resolution)

    private enum CameraAcquisitionState {
        case idle, requestingPermission, ready, deniedFallback
    }

    @ViewBuilder
    private var cameraView: some View {
        Group {
            switch cameraAcquisitionState {
            case .idle, .requestingPermission:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.sousBackground)

            case .ready:
                ZStack(alignment: .bottomLeading) {
                    CameraPickerView(
                        onImage: { handleImage($0) },
                        onCancel: { cameraAcquisitionState = .idle; mode = .chooser }
                    )

                    Button {
                        mode = .library
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.sousIcon(.xLarge, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.leading, 30)
                    .padding(.bottom, 80)
                }

            case .deniedFallback:
                PhotoLibraryPickerView(
                    onImage: { handleImage($0) },
                    onCancel: { cameraAcquisitionState = .idle; mode = .chooser }
                )
            }
        }
        .task { await resolveCameraPermission() }
    }

    @MainActor
    private func resolveCameraPermission() async {
        cameraAcquisitionState = .requestingPermission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAcquisitionState = .ready
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAcquisitionState = granted ? .ready : .deniedFallback
        default:
            cameraAcquisitionState = .deniedFallback
        }
    }

    // MARK: - Paste

    private var pasteView: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "PASTE TEXT", showBack: true) { mode = .chooser }
            SousRule()

            HStack {
                Spacer()
                Button {
                    if let text = UIPasteboard.general.string {
                        pasteText = text
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.sousIcon(.small))
                        Text("PASTE FROM CLIPBOARD")
                            .font(.sousCaption)
                            .kerning(0.5)
                    }
                    .foregroundStyle(clipboardHasText ? Color.sousText : Color.sousMuted)
                }
                .buttonStyle(.plain)
                .disabled(!clipboardHasText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ZStack(alignment: .topLeading) {
                if pasteText.isEmpty {
                    Text("Paste your recipe here...")
                        .font(.sousBody)
                        .foregroundStyle(Color.sousMuted)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $pasteText)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            .frame(maxHeight: .infinity)
            .onAppear { clipboardHasText = UIPasteboard.general.hasStrings }

            SousRule()

            let trimmed = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)
            Button {
                guard !trimmed.isEmpty else { return }
                mode = .loading
                store.sendImportRequest(text: trimmed)
            } label: {
                // Enabled it fills ink; disabled it keeps the ink border and mutes the
                // label — which is exactly Secondary Disabled, so the style swaps rather
                // than the button carrying a bespoke disabled look.
                SousButtonLabel(
                    title: "IMPORT RECIPE",
                    style: trimmed.isEmpty ? .secondary : .inverse,
                    isEnabled: !trimmed.isEmpty,
                    height: nil            // hugs the label with 14pt above and below
                )
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
            .padding(16)
        }
    }

    // MARK: - Loading

    /// Stage-aware loading copy. Conversion reuses this screen with its own text.
    private var loadingCopy: String {
        switch store.importLoadingStage {
        case .ocr:
            return "ANALYZING IMAGE..."
        case .llm:
            return "SOUS-ING UP THE RECIPE..."
        case .converting:
            return store.userPreferences.preferredUnitSystem == .metric
                ? "CONVERTING TO METRIC..."
                : "CONVERTING TO IMPERIAL..."
        case .rescaling:
            return "RESCALING RECIPE..."
        }
    }

    private var loadingView: some View {
        VStack(spacing: 28) {
            Text(loadingCopy)
                .font(.sousCaption)
                .foregroundStyle(Color.sousMuted)
                .kerning(1.2)
                .animation(.easeInOut(duration: 0.2), value: store.importLoadingStage == .ocr)

            // Indeterminate progress bar
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.sousMuted.opacity(0.2))
                    .frame(height: 2)
                Rectangle()
                    .fill(Color.sousText)
                    .frame(height: 2)
                    .scaleEffect(x: importProgress, y: 1, anchor: .leading)
            }
            .padding(.horizontal, 40)
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: importProgress)

            SousButton(title: "CANCEL", style: .secondaryAccent,
                       height: nil, verticalPadding: 10,
                       fillsWidth: false, horizontalPadding: 24) {
                store.cancelLiveLLM()
                store.importError = nil
                store.importLoadingStage = .llm
                mode = .chooser
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Drive the progress crawl while loading
        .task {
            importProgress = 0
            let isOCR = store.importLoadingStage == .ocr
            importProgress = isOCR ? 0.35 : 0.18

            let milestones: [(Double, UInt64)] = isOCR
                ? [(0.55, 2_500_000_000), (0.68, 2_500_000_000), (0.78, 3_000_000_000)]
                : [(0.42, 1_500_000_000), (0.60, 2_000_000_000), (0.76, 3_000_000_000)]
            for (target, delay) in milestones {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                if importProgress < target { importProgress = target }
            }
        }
        // Advance when OCR finishes and LLM stage begins
        .onChange(of: store.importLoadingStage) { stage in
            guard stage == .llm else { return }
            if importProgress < 0.55 { importProgress = 0.55 }
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Text(message)
                .font(.sousBody)
                .foregroundStyle(Color.sousText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Stacked, not side by side: a bordered button next to a bare label reads as
            // lopsided, and stacking puts the recovery path first and the way out beneath it.
            VStack(spacing: 8) {
                SousButton(title: "TRY AGAIN", style: .secondaryAccent,
                           height: nil, verticalPadding: 10,
                           fillsWidth: false, horizontalPadding: 16) {
                    store.importError = nil
                    mode = .chooser
                }

                // Text style, not a muted border: grey-on-grey is how the app draws a
                // disabled control, and this one is live. Quieter than TRY AGAIN without
                // looking broken — the same treatment REJECT gets on the review bar.
                SousButton(title: "CANCEL", style: .text,
                           height: nil, verticalPadding: 10,
                           fillsWidth: false, horizontalPadding: 16) {
                    onCancel()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // A failed import leaves no canvas and no chat sheet, so the 5-tap diagnostic
        // gesture would otherwise be unreachable on exactly the screen that needs it.
        .debugTapExport(store: store)
    }

    // MARK: - Header

    private func sheetHeader(title: String, showBack: Bool, backAction: (() -> Void)? = nil) -> some View {
        HStack {
            if showBack {
                Button {
                    backAction?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.sousIcon(.medium))
                        .foregroundStyle(Color.sousText)
                        .frame(width: 32, height: 32)
                        .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Spacer()

            Text(title)
                .font(.sousButton)
                .foregroundStyle(Color.sousText)

            Spacer()

            Button("CANCEL") { onCancel() }
                .font(.sousButton)
                .foregroundStyle(Color.sousTerracotta)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Image handoff

    private func handleImage(_ image: UIImage) {
        mode = .loading
        store.sendImportRequest(image: image)
    }
}

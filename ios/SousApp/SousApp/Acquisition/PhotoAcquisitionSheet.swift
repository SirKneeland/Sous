import AVFoundation
import SousCore
import SwiftUI
import UIKit

// MARK: - PhotoAcquisitionSheet

/// SwiftUI sheet that drives the image acquisition flow.
///
/// On appear, resolves camera permission and transitions `acquisitionState` accordingly:
/// - `.authorized`  → shows camera picker immediately
/// - `.denied` / `.restricted` / `.unavailable` → falls back silently to library picker
/// - `.notDetermined` → requests permission, then branches to camera or library
///
/// Exposes one callback: `onAcquired(ImageAsset)`. The caller owns all dispatch after that point.
/// Does not prepare, compress, or send the image.
///
/// `acquisitionState` is session-only `@State`. It never enters `AppStore` and is not persisted.
struct PhotoAcquisitionSheet: View {
    let onAcquired: (ImageAsset) -> Void
    let onCancel: () -> Void

    @State private var acquisitionState: ImageAcquisitionState = .idle

#if DEBUG
    /// Opens straight into a given state, for simulator verification. The failure
    /// state is otherwise unreachable without a corrupt image: it only occurs when
    /// JPEG encoding fails, which cannot be provoked from the UI. Compiled out of
    /// Release, and `.idle` everywhere in the real app.
    var debugInitialState: ImageAcquisitionState? = nil
#endif

    var body: some View {
        VStack {
            switch acquisitionState {

            case .idle, .requestingPermission:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .showingCamera:
                ZStack(alignment: .bottomLeading) {
                    CameraPickerView(
                        onImage: { uiImage in handleAcquired(uiImage, source: .camera) },
                        onCancel: { acquisitionState = .idle; onCancel() }
                    )
                    .ignoresSafeArea()

                    Button {
                        acquisitionState = .showingLibraryPicker
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

            case .showingLibraryPicker:
                PhotoLibraryPickerView(
                    onImage: { uiImage in handleAcquired(uiImage, source: .photoLibrary) },
                    onCancel: { acquisitionState = .idle; onCancel() }
                )
                .ignoresSafeArea()

            case .failed:
                // This state used none of Sous's type, colour or buttons — it was raw
                // system styling on a black sheet, which check-tokens.py cannot catch
                // because it only rejects hand-built hex, not system defaults. Brought
                // onto the tokens 2026-09-27, matching the import sheet's error screen:
                // the recovery path is not offered here (there is nothing to retry
                // without a fresh pick), so the way out is a single Text-style button.
                VStack(spacing: 16) {
                    Text("Could not attach image.")
                        .font(.sousHeading1)
                        .foregroundStyle(Color.white)
                    Text("The image could not be processed. Please try again.")
                        .font(.sousBody)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    // White, not the Text style's burgundy. This sheet is always
                    // black — it sits on Apple's camera chrome and does not follow the
                    // app's light/dark setting — so a mode-aware accent resolves to the
                    // light-mode burgundy and measures 2.56:1 on black, well under AA.
                    // The voice bar, the only other always-dark surface, already solves
                    // this the same way: white labels, never the accent.
                    Button {
                        acquisitionState = .idle
                        onCancel()
                    } label: {
                        Text("DISMISS")
                            .font(.sousButton)
                            .foregroundStyle(Color.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task {
#if DEBUG
            if let forced = debugInitialState {
                acquisitionState = forced
                return          // never asks for the camera in a forced state
            }
#endif
            await resolveAndPresent()
        }
    }

    // MARK: - Permission resolution

    @MainActor
    private func resolveAndPresent() async {
        let permission = CameraPermissionMapper.currentState()
        let initial = ImageAcquisitionState.resolved(for: permission)

        if initial == .requestingPermission {
            acquisitionState = .requestingPermission
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            acquisitionState = ImageAcquisitionState.afterPermissionRequest(granted: granted)
        } else {
            acquisitionState = initial
        }
    }

    // MARK: - Acquisition handoff

    private func handleAcquired(_ image: UIImage, source: ImageAsset.Source) {
        guard let asset = UIImageAssetBuilder.build(from: image, source: source) else {
            acquisitionState = .failed(.encodingFailed)
            return
        }
        acquisitionState = .idle
        onAcquired(asset)
    }
}

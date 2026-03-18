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
                            .font(.system(size: 22, weight: .medium))
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
                VStack(spacing: 16) {
                    Text("Could not attach image.")
                        .font(.headline)
                    Text("The image could not be processed. Please try again.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") {
                        acquisitionState = .idle
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await resolveAndPresent() }
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

// MARK: - ImageAcquisitionFailure

/// Reason for a failed image acquisition attempt.
///
/// Distinct from user cancellation: cancel returns to `.idle`, not `.failed`.
enum ImageAcquisitionFailure: Equatable {
    /// UIImage could not be JPEG-encoded. Indicates a corrupt or unsupported image.
    case encodingFailed
}

// MARK: - ImageAcquisitionState

/// Ephemeral session-only state for the image acquisition flow.
///
/// Lives as `@State` on `PhotoAcquisitionSheet`. Never enters `AppStore`. Never persisted.
///
/// **Transitions:**
/// - `.idle` → `.requestingPermission` (status is `.notDetermined`)
/// - `.idle` → `.showingCamera` (status is `.authorized`)
/// - `.idle` → `.showingLibraryPicker` (status is `.denied`, `.restricted`, or `.unavailable`)
/// - `.requestingPermission` → `.showingCamera` (user granted)
/// - `.requestingPermission` → `.showingLibraryPicker` (user denied)
/// - `.showingCamera` / `.showingLibraryPicker` → `.idle` (user cancelled — not an error)
/// - `.showingCamera` / `.showingLibraryPicker` → `.idle` (acquisition succeeded; `onAcquired` called)
/// - `.showingCamera` / `.showingLibraryPicker` → `.failed(.encodingFailed)` (encoding error)
enum ImageAcquisitionState: Equatable {
    case idle
    case requestingPermission
    case showingCamera
    case showingLibraryPicker
    case failed(ImageAcquisitionFailure)
}

// MARK: - Pure state resolution helpers

extension ImageAcquisitionState {

    /// Resolves the initial acquisition state from a known permission state.
    ///
    /// Pure function — testable without hardware or permission dialogs.
    ///
    /// - `.authorized` → `.showingCamera`
    /// - `.denied`, `.restricted`, `.unavailable` → `.showingLibraryPicker` (silent fallback)
    /// - `.notDetermined` → `.requestingPermission` (caller must then request live access)
    static func resolved(for permission: CameraPermissionState) -> ImageAcquisitionState {
        switch permission {
        case .authorized:                          return .showingCamera
        case .denied, .restricted, .unavailable:   return .showingLibraryPicker
        case .notDetermined:                       return .requestingPermission
        }
    }

    /// Resolves acquisition state after a live permission request completes.
    ///
    /// Pure function — testable without hardware.
    static func afterPermissionRequest(granted: Bool) -> ImageAcquisitionState {
        granted ? .showingCamera : .showingLibraryPicker
    }
}

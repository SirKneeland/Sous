// MARK: - CameraPermissionState

/// The camera permission state as understood by the acquisition layer.
///
/// Distinct from AVAuthorizationStatus to keep acquisition types decoupled from
/// AVFoundation at the module boundary. Only CameraPermissionMapper imports AVFoundation.
enum CameraPermissionState: Equatable {
    /// No decision made yet. The system has not asked the user.
    case notDetermined

    /// Camera access is granted.
    case authorized

    /// User explicitly denied camera access. App cannot re-prompt.
    case denied

    /// Camera access is restricted by parental controls or device management.
    case restricted

    /// Camera hardware is not present on this device (e.g. simulator, iPod touch).
    case unavailable
}

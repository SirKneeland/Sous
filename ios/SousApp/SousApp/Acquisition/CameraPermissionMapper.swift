import AVFoundation
import UIKit

// MARK: - CameraPermissionMapper

/// Maps AVFoundation / UIKit permission values to `CameraPermissionState`.
///
/// The core mapping function is pure: it accepts status and hardware availability as
/// parameters so it is fully testable without real hardware or permission dialogs.
enum CameraPermissionMapper {

    /// Pure mapping. Accepts injected values to enable unit testing without hardware.
    ///
    /// Hardware unavailability takes priority: if `isCameraAvailable` is false, returns
    /// `.unavailable` regardless of the authorization status value.
    static func map(
        status: AVAuthorizationStatus,
        isCameraAvailable: Bool
    ) -> CameraPermissionState {
        guard isCameraAvailable else { return .unavailable }
        switch status {
        case .authorized:       return .authorized
        case .denied:           return .denied
        case .restricted:       return .restricted
        case .notDetermined:    return .notDetermined
        @unknown default:       return .denied
        }
    }

    /// Reads live device state. Not suitable for unit tests — use `map(status:isCameraAvailable:)` instead.
    static func currentState() -> CameraPermissionState {
        map(
            status: AVCaptureDevice.authorizationStatus(for: .video),
            isCameraAvailable: UIImagePickerController.isSourceTypeAvailable(.camera)
        )
    }
}

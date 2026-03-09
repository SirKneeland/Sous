import Foundation

// MARK: - ImagePreparationFailure

/// Typed failure produced by `ImagePreparator.prepare(_:config:)`.
///
/// Each case identifies a distinct failure point in the pipeline so callers
/// can surface an appropriate error message or retry strategy.
public enum ImagePreparationFailure: Error, Equatable, Sendable {

    /// Input bytes could not be decoded as a valid image.
    /// Indicates corrupt data or an unsupported image format.
    case invalidImageData

    /// CoreGraphics failed to render the image at the computed target size.
    /// Indicates an internal rendering failure, not a caller error.
    case resizeFailed

    /// JPEG encoding produced empty output data.
    /// Indicates an internal encoding failure.
    case compressionFailed

    /// Both compression passes produced output that still exceeds `maxByteCount`.
    /// The prepared byte count and budget are included for logging and UI messaging.
    case budgetExceeded(preparedByteCount: Int, budgetByteCount: Int)
}

import Foundation

// MARK: - ImageAsset

/// Ephemeral acquisition payload produced by camera capture or photo library selection.
///
/// This type is potentially large (raw HEIC/JPEG capture may be several MB).
/// It is not persisted and must not be retained beyond the preprocessing step.
///
/// **Lifecycle:** The call site must release its reference to `ImageAsset` immediately
/// after `PreparedImage` is produced. The goal is to avoid holding raw capture bytes
/// alongside compressed output. The type system cannot enforce this — it is a call-site
/// convention documented here and at the integration boundary.
///
/// **Framework neutrality:** SousCore does not import UIKit or PhotosUI.
/// The SousApp layer is responsible for converting `UIImage`/`PHAsset` → `Data`
/// before constructing this type.
public struct ImageAsset: Sendable {

    // MARK: - Source

    /// Where the image came from. Carried for prompt context and analytics.
    public enum Source: String, Equatable, Sendable {
        case camera
        case photoLibrary
    }

    // MARK: - Stored Properties

    /// Raw image bytes. May be MB-scale. See lifecycle note above.
    public let data: Data

    /// MIME type of the raw bytes (e.g. `"image/jpeg"`, `"image/heic"`).
    public let mimeType: String

    /// Acquisition source.
    public let source: Source

    // MARK: - Init

    public init(data: Data, mimeType: String, source: Source) {
        self.data = data
        self.mimeType = mimeType
        self.source = source
    }
}

import UIKit
import SousCore

// MARK: - UIImageAssetBuilder

/// Converts a `UIImage` into an `ImageAsset` for handoff to the multimodal pipeline.
///
/// Performs only normalization: JPEG encode at full quality, assign MIME type and source.
/// No resizing or compression policy lives here — that belongs entirely to `DefaultImagePreparator`.
enum UIImageAssetBuilder {

    /// Builds an `ImageAsset` from a `UIImage`.
    ///
    /// - Parameters:
    ///   - image: The `UIImage` from camera capture or photo library selection.
    ///   - source: Acquisition source, carried for prompt context.
    /// - Returns: An `ImageAsset`, or `nil` if JPEG encoding fails.
    static func build(from image: UIImage, source: ImageAsset.Source) -> ImageAsset? {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return nil }
        return ImageAsset(data: data, mimeType: "image/jpeg", source: source)
    }
}

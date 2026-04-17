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
        // Bake EXIF orientation into pixel data so downstream CoreGraphics rendering
        // (which strips EXIF metadata) produces correctly-oriented output.
        let normalized = Self.normalizeOrientation(image)
        guard let data = normalized.jpegData(compressionQuality: 1.0) else { return nil }
        return ImageAsset(data: data, mimeType: "image/jpeg", source: source)
    }

    /// Redraws `image` into a new UIImage with `.up` orientation.
    /// If the image is already `.up` the redraw still runs — it is cheap and keeps the
    /// path unconditional, which avoids a class of subtle bugs on edge-case orientations.
    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

import CoreGraphics
import Foundation
import ImageIO

// MARK: - DefaultImagePreparator

/// Concrete `ImagePreparator` using CoreGraphics and ImageIO.
///
/// No UIKit dependency — compiles on macOS and iOS without modification.
///
/// **Algorithm (deterministic, at most two JPEG encodings):**
/// 1. Decode input bytes → `CGImage` + original pixel dimensions.
/// 2. Compute target size: scale the longest side to `maxDimensionPx` if it exceeds
///    the limit, otherwise keep original dimensions (no upscaling).
/// 3. Render at target size via `CGContext` (sRGB, 8bpc).
/// 4. Encode to JPEG at `initialCompressionQuality`.
///    If output ≤ `maxByteCount` → return `PreparedImage`.
/// 5. Re-encode at `retryCompressionQuality`.
///    If output ≤ `maxByteCount` → return `PreparedImage`.
///    Otherwise → return `.budgetExceeded`.
public struct DefaultImagePreparator: ImagePreparator {

    public init() {}

    // MARK: - ImagePreparator

    public func prepare(
        _ asset: ImageAsset,
        config: ImagePreparationConfig
    ) -> Result<PreparedImage, ImagePreparationFailure> {

        // Step 1: Decode
        guard
            let source = CGImageSourceCreateWithData(asset.data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return .failure(.invalidImageData)
        }

        let originalByteCount = asset.data.count

        // Step 2: Compute target size
        let target = Self.targetSize(
            width: cgImage.width,
            height: cgImage.height,
            maxDimensionPx: config.maxDimensionPx
        )

        // Step 3: Render at target size
        guard let rendered = Self.render(cgImage, width: target.width, height: target.height) else {
            return .failure(.resizeFailed)
        }

        // Step 4: First compression pass
        guard let firstPass = Self.encodeJPEG(rendered, quality: config.initialCompressionQuality) else {
            return .failure(.compressionFailed)
        }
        if firstPass.count <= config.maxByteCount {
            return build(data: firstPass, width: target.width, height: target.height, originalByteCount: originalByteCount)
        }

        // Step 5: Retry compression pass
        guard let retryPass = Self.encodeJPEG(rendered, quality: config.retryCompressionQuality) else {
            return .failure(.compressionFailed)
        }
        if retryPass.count <= config.maxByteCount {
            return build(data: retryPass, width: target.width, height: target.height, originalByteCount: originalByteCount)
        }
        return .failure(.budgetExceeded(
            preparedByteCount: retryPass.count,
            budgetByteCount: config.maxByteCount
        ))
    }

    // MARK: - Internal helpers (internal for testability)

    /// Computes the output pixel dimensions after scale-to-fit.
    ///
    /// - The longest side is scaled down to `maxDimensionPx` if it exceeds the limit.
    /// - Images already within the limit are returned unchanged (no upscaling).
    /// - Minimum output dimension is 1px on each side.
    static func targetSize(
        width: Int,
        height: Int,
        maxDimensionPx: Int
    ) -> (width: Int, height: Int) {
        let maxSide = max(width, height)
        guard maxSide > maxDimensionPx else { return (width, height) }
        let scale = Double(maxDimensionPx) / Double(maxSide)
        return (
            width:  max(1, Int((Double(width)  * scale).rounded())),
            height: max(1, Int((Double(height) * scale).rounded()))
        )
    }

    /// Renders `cgImage` into a new `CGImage` at the given pixel dimensions.
    /// Returns nil if the context or final image cannot be created.
    static func render(_ cgImage: CGImage, width: Int, height: Int) -> CGImage? {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Encodes `cgImage` as JPEG at `quality` (0.0–1.0).
    /// Returns nil if the destination cannot be created, finalisation fails, or output is empty.
    static func encodeJPEG(_ cgImage: CGImage, quality: Double) -> Data? {
        let buffer = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            buffer,
            "public.jpeg" as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(
            dest,
            cgImage,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(dest) else { return nil }
        let data = buffer as Data
        return data.isEmpty ? nil : data
    }

    // MARK: - Private

    private func build(
        data: Data,
        width: Int,
        height: Int,
        originalByteCount: Int
    ) -> Result<PreparedImage, ImagePreparationFailure> {
        // PreparedImage.init throws only .emptyData, which cannot occur here since
        // encodeJPEG already returns nil for empty output.
        guard let prepared = try? PreparedImage(
            data: data,
            mimeType: "image/jpeg",
            widthPx: width,
            heightPx: height,
            originalByteCount: originalByteCount
        ) else {
            return .failure(.compressionFailed)
        }
        return .success(prepared)
    }
}

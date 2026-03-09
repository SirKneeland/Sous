import Foundation

// MARK: - PreparedImageError

public enum PreparedImageError: Error, Equatable {
    /// The compressed data payload is empty. This indicates a preprocessing bug.
    case emptyData
}

// MARK: - PreparedImage

/// The output of the image preprocessing step (resize + compress).
///
/// This is the image payload embedded in a `MultimodalLLMRequest`.
/// It is produced from an `ImageAsset` and should be treated as the canonical
/// form for upload — the `ImageAsset` must be released after this is created.
///
/// `preparedByteCount` enables the orchestrator to gate on payload size before
/// committing to a network send (e.g. reject payloads exceeding a size threshold).
public struct PreparedImage: Equatable, Sendable {

    // MARK: - Stored Properties

    /// Compressed image bytes. Non-empty by construction.
    public let data: Data

    /// MIME type of the compressed output (e.g. `"image/jpeg"`).
    public let mimeType: String

    /// Width of the prepared image in pixels.
    public let widthPx: Int

    /// Height of the prepared image in pixels.
    public let heightPx: Int

    /// Byte count of the original `ImageAsset.data` before compression.
    public let originalByteCount: Int

    /// Byte count of `data` after compression. Derived from `data.count` at init time.
    public let preparedByteCount: Int

    // MARK: - Init

    /// - Throws: `PreparedImageError.emptyData` if `data` is empty.
    public init(
        data: Data,
        mimeType: String,
        widthPx: Int,
        heightPx: Int,
        originalByteCount: Int
    ) throws {
        guard !data.isEmpty else { throw PreparedImageError.emptyData }
        self.data = data
        self.mimeType = mimeType
        self.widthPx = widthPx
        self.heightPx = heightPx
        self.originalByteCount = originalByteCount
        self.preparedByteCount = data.count
    }
}

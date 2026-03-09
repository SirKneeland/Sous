import Foundation

// MARK: - ImagePreparationConfig

/// Centralised configuration for the image-preparation pipeline.
///
/// All budget, dimension, and quality values are controlled here.
/// Callers substitute a custom config for tests or future tuning without
/// touching pipeline implementation code.
///
/// The `default` preset uses conservative values suitable for vision API
/// upload payloads. They are not authoritative backend limits — adjust them
/// when actual backend constraints are confirmed and documented in this repo.
public struct ImagePreparationConfig: Equatable, Sendable {

    /// Maximum pixel dimension (longest side) of the output image.
    /// Images whose longest side exceeds this are scaled down proportionally.
    /// Images already within this limit are not scaled.
    public let maxDimensionPx: Int

    /// Maximum byte count of the prepared output payload.
    /// Preparation returns `.budgetExceeded` if this cannot be met
    /// after the full compression sequence.
    public let maxByteCount: Int

    /// JPEG quality for the first compression pass (0.0–1.0).
    public let initialCompressionQuality: Double

    /// JPEG quality for the single retry pass, applied only when the first
    /// pass exceeds `maxByteCount`. There is no further retry after this.
    public let retryCompressionQuality: Double

    // MARK: - Init

    public init(
        maxDimensionPx: Int,
        maxByteCount: Int,
        initialCompressionQuality: Double,
        retryCompressionQuality: Double
    ) {
        self.maxDimensionPx = maxDimensionPx
        self.maxByteCount = maxByteCount
        self.initialCompressionQuality = initialCompressionQuality
        self.retryCompressionQuality = retryCompressionQuality
    }

    // MARK: - Default preset

    /// Conservative upload defaults. Values are tunable starting points,
    /// not authoritative backend limits.
    public static let `default` = ImagePreparationConfig(
        maxDimensionPx: 1568,
        maxByteCount: 1_048_576,   // 1 MB
        initialCompressionQuality: 0.8,
        retryCompressionQuality: 0.5
    )
}

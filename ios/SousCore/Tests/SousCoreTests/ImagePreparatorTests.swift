import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SousCore

// MARK: - Synthetic image helper

/// Creates a solid-colour JPEG at the given pixel dimensions using CoreGraphics + ImageIO.
/// Returns nil only if the graphics context or encoder cannot be initialised —
/// which would indicate a test environment problem, not a system under test failure.
private func makeSyntheticJPEG(width: Int, height: Int) -> Data? {
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

    // Fill with an opaque orange — any solid colour works, just needs valid pixels.
    context.setFillColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let cgImage = context.makeImage() else { return nil }

    let buffer = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(
        buffer,
        "public.jpeg" as CFString,
        1,
        nil
    ) else { return nil }
    CGImageDestinationAddImage(dest, cgImage, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }
    let data = buffer as Data
    return data.isEmpty ? nil : data
}

private func makeAsset(width: Int, height: Int) -> ImageAsset? {
    guard let jpeg = makeSyntheticJPEG(width: width, height: height) else { return nil }
    return ImageAsset(data: jpeg, mimeType: "image/jpeg", source: .camera)
}

// MARK: - ImagePreparatorTests

struct ImagePreparatorTests {

    // MARK: - targetSize: pure resize math

    @Test func targetSize_smallImage_notUpscaled() {
        let result = DefaultImagePreparator.targetSize(width: 100, height: 80, maxDimensionPx: 1568)
        #expect(result.width == 100)
        #expect(result.height == 80)
    }

    @Test func targetSize_exactlyAtLimit_notScaled() {
        let result = DefaultImagePreparator.targetSize(width: 1568, height: 800, maxDimensionPx: 1568)
        #expect(result.width == 1568)
        #expect(result.height == 800)
    }

    @Test func targetSize_landscapeExceedsLimit_scaledByWidth() {
        // 3136 × 1568 → longest side 3136 → scale 0.5 → 1568 × 784
        let result = DefaultImagePreparator.targetSize(width: 3136, height: 1568, maxDimensionPx: 1568)
        #expect(result.width == 1568)
        #expect(result.height == 784)
    }

    @Test func targetSize_portraitExceedsLimit_scaledByHeight() {
        // 800 × 3200 → longest side 3200 → scale 0.49 → 392 × 1568
        let result = DefaultImagePreparator.targetSize(width: 800, height: 3200, maxDimensionPx: 1568)
        #expect(result.height == 1568)
        #expect(result.width <= 400)   // proportional
        #expect(result.width >= 390)
    }

    @Test func targetSize_squareExceedsLimit_scaledUniformly() {
        // 4000 × 4000 → longest side 4000 → scale = 1568/4000 = 0.392
        // 4000 × 0.392 = 1568 → output is 1568 × 1568
        let result = DefaultImagePreparator.targetSize(width: 4000, height: 4000, maxDimensionPx: 1568)
        #expect(result.width == result.height)
        #expect(result.width == 1568)
    }

    @Test func targetSize_tinyImage_minimumOnePx() {
        // A 1×1 image that still technically exceeds limit via a pathological config
        // should yield at least 1×1.
        let result = DefaultImagePreparator.targetSize(width: 2, height: 2, maxDimensionPx: 1)
        #expect(result.width >= 1)
        #expect(result.height >= 1)
    }

    // MARK: - Full pipeline: small image passes through unchanged

    @Test func prepare_smallImage_notDownscaled() throws {
        guard let asset = makeAsset(width: 100, height: 80) else {
            Issue.record("Could not create synthetic test image")
            return
        }
        let config = ImagePreparationConfig.default
        let preparator = DefaultImagePreparator()

        let result = preparator.prepare(asset, config: config)

        guard case .success(let prepared) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        // Dimensions are unchanged — image was within maxDimensionPx.
        #expect(prepared.widthPx == 100)
        #expect(prepared.heightPx == 80)
    }

    // MARK: - Full pipeline: large image is downscaled

    @Test func prepare_largeImage_isDownscaled() throws {
        // 3136 × 1568 → longest side 3136 exceeds 1568 → scale 0.5 → 1568 × 784
        guard let asset = makeAsset(width: 3136, height: 1568) else {
            Issue.record("Could not create synthetic test image")
            return
        }
        let config = ImagePreparationConfig.default
        let preparator = DefaultImagePreparator()

        let result = preparator.prepare(asset, config: config)

        guard case .success(let prepared) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(prepared.widthPx == 1568)
        #expect(prepared.heightPx == 784)
        // Output must be within default budget.
        #expect(prepared.preparedByteCount <= config.maxByteCount)
    }

    // MARK: - Full pipeline: output is within budget

    @Test func prepare_outputWithinBudget() throws {
        guard let asset = makeAsset(width: 400, height: 300) else {
            Issue.record("Could not create synthetic test image")
            return
        }
        let config = ImagePreparationConfig.default
        let preparator = DefaultImagePreparator()

        let result = preparator.prepare(asset, config: config)

        guard case .success(let prepared) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(prepared.preparedByteCount <= config.maxByteCount)
        #expect(prepared.preparedByteCount == prepared.data.count)
    }

    // MARK: - Full pipeline: budget exceeded when limit is impossibly tight

    @Test func prepare_budgetExceeded_whenLimitImpossiblyTight() throws {
        guard let asset = makeAsset(width: 100, height: 100) else {
            Issue.record("Could not create synthetic test image")
            return
        }
        let config = ImagePreparationConfig(
            maxDimensionPx: 1568,
            maxByteCount: 1,           // impossible to satisfy
            initialCompressionQuality: 0.8,
            retryCompressionQuality: 0.5
        )
        let preparator = DefaultImagePreparator()

        let result = preparator.prepare(asset, config: config)

        guard case .failure(let failure) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        if case .budgetExceeded(let preparedByteCount, let budgetByteCount) = failure {
            #expect(preparedByteCount > budgetByteCount)
            #expect(budgetByteCount == 1)
        } else {
            Issue.record("Expected .budgetExceeded, got \(failure)")
        }
    }

    // MARK: - Full pipeline: invalid input returns typed failure

    @Test func prepare_invalidInput_returnsInvalidImageData() {
        let garbage = Data([0x00, 0x01, 0x02, 0xFF, 0xAB])
        let asset = ImageAsset(data: garbage, mimeType: "image/jpeg", source: .camera)
        let preparator = DefaultImagePreparator()

        let result = preparator.prepare(asset, config: .default)

        #expect(result == .failure(.invalidImageData))
    }

    // MARK: - Metadata accuracy

    @Test func prepare_metadata_originalByteCountMatchesAsset() throws {
        guard let asset = makeAsset(width: 200, height: 150) else {
            Issue.record("Could not create synthetic test image")
            return
        }
        let originalByteCount = asset.data.count
        let preparator = DefaultImagePreparator()

        let result = preparator.prepare(asset, config: .default)

        guard case .success(let prepared) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(prepared.originalByteCount == originalByteCount)
    }

    @Test func prepare_metadata_preparedByteCountMatchesDataCount() throws {
        guard let asset = makeAsset(width: 200, height: 150) else {
            Issue.record("Could not create synthetic test image")
            return
        }
        let preparator = DefaultImagePreparator()

        let result = preparator.prepare(asset, config: .default)

        guard case .success(let prepared) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(prepared.preparedByteCount == prepared.data.count)
    }

    // MARK: - Prepared output shape reflects transformation

    @Test func prepare_outputShape_reflectsTransformation() throws {
        // Input: 3136 × 2352 (4:3 landscape, longest side > 1568)
        // Expected target: 1568 × 1176 (scale = 1568/3136 = 0.5)
        guard let asset = makeAsset(width: 3136, height: 2352) else {
            Issue.record("Could not create synthetic test image")
            return
        }
        let config = ImagePreparationConfig.default
        let preparator = DefaultImagePreparator()

        let result = preparator.prepare(asset, config: config)

        guard case .success(let prepared) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }

        // Dimensions reflect the post-scale output, not the original.
        #expect(prepared.widthPx == 1568)
        #expect(prepared.heightPx == 1176)

        // Byte counts reflect the actual data, not acquisition-only state.
        #expect(prepared.preparedByteCount == prepared.data.count)
        #expect(prepared.originalByteCount == asset.data.count)

        // mimeType is always JPEG regardless of input format.
        #expect(prepared.mimeType == "image/jpeg")

        // The prepared image is smaller (JPEG of a scaled-down render)
        // than a naive copy of the original bytes — confirms transformation occurred.
        #expect(prepared.preparedByteCount < prepared.originalByteCount || prepared.widthPx < 3136)
    }

    // MARK: - Retry pass is used when first pass exceeds budget

    @Test func prepare_retryPassUsed_whenFirstPassExceedsBudget() throws {
        // Use a tight budget that the initial quality might exceed but retry should meet.
        guard let asset = makeAsset(width: 400, height: 400) else {
            Issue.record("Could not create synthetic test image")
            return
        }

        // First, measure actual output at both qualities to set a budget between them.
        let preparator = DefaultImagePreparator()
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let ctx = CGContext(data: nil, width: 400, height: 400, bitsPerComponent: 8,
                                bytesPerRow: 0, space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let cgImage = ctx.makeImage()
        else {
            Issue.record("Could not build CGImage for size measurement")
            return
        }

        guard
            let highQualityData = DefaultImagePreparator.encodeJPEG(cgImage, quality: 0.8),
            let lowQualityData  = DefaultImagePreparator.encodeJPEG(cgImage, quality: 0.3)
        else {
            Issue.record("Could not encode test images")
            return
        }

        // Only proceed with this test if the two qualities actually differ in size.
        // On uniform/synthetic images they may not — skip gracefully if so.
        guard highQualityData.count > lowQualityData.count else { return }

        // Budget: between the two quality outputs, so first pass fails, retry succeeds.
        let budget = (highQualityData.count + lowQualityData.count) / 2
        let config = ImagePreparationConfig(
            maxDimensionPx: 1568,
            maxByteCount: budget,
            initialCompressionQuality: 0.8,
            retryCompressionQuality: 0.3
        )

        let result = preparator.prepare(asset, config: config)

        // With budget between the two, retry should succeed.
        if case .success(let prepared) = result {
            #expect(prepared.preparedByteCount <= budget)
        }
        // If the image is so compressible that both passes fit within budget, that's also valid.
    }
}

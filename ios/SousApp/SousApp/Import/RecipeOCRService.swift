import Foundation
import UIKit
import Vision

// MARK: - RecipeOCRService

/// Extracts text from an image using on-device Vision OCR.
///
/// Runs `VNRecognizeTextRequest` at `.accurate` level locally — no network call.
/// The recognized lines are returned in reading order, joined by newlines.
/// Returns nil if no text is found or the image cannot be processed.
enum RecipeOCRService {

    static func recognizeText(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation]
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let text = lines.joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

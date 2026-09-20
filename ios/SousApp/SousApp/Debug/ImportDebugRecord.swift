#if DEBUG
import Foundation
import SousCore
import UIKit

// MARK: - ImportDebugRecord

/// Debug-only snapshot of the most recent recipe import attempt.
///
/// Import is the one flow where the inputs vanish the instant it finishes: OCR text lives
/// in a local, and a successful import replaces the transcript with a single assistant
/// message. This record keeps the whole round trip — what went in, what the model was
/// asked, what it literally sent back — so the 5-tap diagnostic export can show it.
///
/// In-memory only, overwritten by each import, and compiled out of release builds.
struct ImportDebugRecord {

    enum Source: String {
        case photo = "Photo"
        case pastedText = "Pasted text"
    }

    enum Outcome: Equatable {
        /// Recipe extracted and applied to the canvas.
        case succeeded
        /// Vision OCR found no usable text — the LLM was never called.
        case ocrFailed
        /// The LLM call completed but produced no usable recipe. Carries the user-facing message.
        case failed(String)

        var label: String {
            switch self {
            case .succeeded:          return "Succeeded"
            case .ocrFailed:          return "Failed — no text read from the photo (LLM never called)"
            case .failed(let message): return "Failed — \(message)"
            }
        }
    }

    let source: Source
    let timestamp: Date

    /// The OCR output for a photo import, or the text the user pasted. Empty when OCR read nothing.
    let inputText: String

    /// Dimensions and approximate file size of the source photo. Nil for text imports.
    /// The photo itself is deliberately not captured — see docs/KnownIssues.md.
    let imageDescription: String?

    /// The request dispatched to the orchestrator. Nil when OCR failed before the call.
    let request: LLMRequest?

    /// The model's literal, undecoded response. Nil when the call never happened or
    /// failed before any bytes arrived (e.g. network error).
    let rawResponse: String?

    let outcome: Outcome

    /// Timing, token, and retry metadata for the call. Nil when no call was made.
    let debug: LLMDebugBundle?
}

// MARK: - Image Description

extension ImportDebugRecord {

    /// Human-readable size summary of a source photo: pixel dimensions and the approximate
    /// byte count of a JPEG encode. The image data itself is never retained.
    static func describe(_ image: UIImage) -> String {
        let widthPx = Int((image.size.width * image.scale).rounded())
        let heightPx = Int((image.size.height * image.scale).rounded())
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return "\(widthPx)x\(heightPx) px (size unavailable)"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return "\(widthPx)x\(heightPx) px, ~\(formatter.string(fromByteCount: Int64(data.count))) as JPEG"
    }
}
#endif

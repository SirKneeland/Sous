import Foundation

/// What the clipboard turned out to be holding, once text and image have been weighed against
/// each other.
///
/// The two are not mutually exclusive: copying a screenshot out of Photos can carry a filename
/// string alongside the image, and copying from a web page can carry images alongside the prose.
/// Preferring one blindly gets a recipe wrong in one direction or the other, so the length of the
/// text decides — a real pasted recipe is long, a stray filename is not.
nonisolated enum PastedContent: Equatable {
    case image
    case text(String)
    case empty

    /// Text this long or longer is treated as the real payload even when an image is also on the
    /// clipboard. Short enough to let a one-line ingredient list through, long enough that
    /// "IMG_4821.HEIC" never beats the screenshot it names.
    static let textWinsThreshold = 40

    static func resolve(text: String?, hasImage: Bool) -> PastedContent {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmed.count >= textWinsThreshold {
            return .text(trimmed)
        }
        if hasImage {
            return .image
        }
        if !trimmed.isEmpty {
            return .text(trimmed)
        }
        return .empty
    }
}

import SwiftUI
import UIKit

// MARK: - ImagePastingTextView

/// A `UITextView` whose Paste command also accepts an image.
///
/// SwiftUI's `TextEditor` offers Paste only when the clipboard holds text, and drops an image
/// on the floor when it holds one — so a copied screenshot could be imported through the
/// PASTE FROM CLIPBOARD button but not through the long-press menu, which is where most
/// people reach for it. This subclass closes that gap: the menu item appears for an image,
/// and choosing it hands the image up rather than inserting anything.
final class ImagePastingTextView: UITextView {

    /// Called when the pasted clipboard turned out to be an image. The owner routes it to the
    /// OCR pipeline; nothing is inserted into the text.
    var onImage: ((UIImage) -> Void)?

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.paste(_:)) {
            let board = UIPasteboard.general
            return board.hasStrings || board.hasImages
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_ sender: Any?) {
        let board = UIPasteboard.general
        if case .image = PastedContent.resolve(text: board.string, hasImage: board.hasImages),
           let image = board.image {
            onImage?(image)
            return
        }
        super.paste(sender)
    }
}

// MARK: - PastingTextEditor

/// `TextEditor` in every visible respect, but backed by `ImagePastingTextView` so a long-press
/// Paste can carry an image.
struct PastingTextEditor: UIViewRepresentable {

    @Binding var text: String
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> ImagePastingTextView {
        let view = ImagePastingTextView()
        view.delegate = context.coordinator
        view.font = .sousBodyUI
        view.textColor = .sousTextUI
        view.backgroundColor = .clear
        view.textContainer.lineFragmentPadding = 0
        // Matches the placeholder's own insets, so the caret lands exactly where the
        // placeholder text sat.
        view.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 8, right: 20)
        return view
    }

    func updateUIView(_ view: ImagePastingTextView, context: Context) {
        if view.text != text { view.text = text }
        view.onImage = onImage
        context.coordinator.text = $text
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}

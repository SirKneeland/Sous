import XCTest
import UIKit
@testable import SousApp

final class PastedContentTests: XCTestCase {

    func testEmptyClipboardIsEmpty() {
        XCTAssertEqual(PastedContent.resolve(text: nil, hasImage: false), .empty)
        XCTAssertEqual(PastedContent.resolve(text: "   \n ", hasImage: false), .empty)
    }

    func testImageOnlyResolvesToImage() {
        XCTAssertEqual(PastedContent.resolve(text: nil, hasImage: true), .image)
    }

    func testShortTextAloneStillResolvesToText() {
        XCTAssertEqual(PastedContent.resolve(text: "2 eggs", hasImage: false), .text("2 eggs"))
    }

    func testTextIsTrimmed() {
        XCTAssertEqual(PastedContent.resolve(text: "\n 2 eggs \n", hasImage: false), .text("2 eggs"))
    }

    func testFilenameAlongsideImageLosesToTheImage() {
        XCTAssertEqual(PastedContent.resolve(text: "IMG_4821.HEIC", hasImage: true), .image)
    }

    func testRealRecipeTextBeatsAnAccompanyingImage() {
        let recipe = "Pancakes\n2 cups flour\n2 eggs\n1 cup milk\nWhisk and fry."
        XCTAssertGreaterThanOrEqual(recipe.count, PastedContent.textWinsThreshold)
        XCTAssertEqual(PastedContent.resolve(text: recipe, hasImage: true), .text(recipe))
    }
}

/// The long-press Paste menu and the PASTE FROM CLIPBOARD button must agree about what the
/// clipboard holds, so both run through `PastedContent.resolve`. These pin the text view's
/// own behaviour: the menu item has to appear for an image-only clipboard, which is the case
/// SwiftUI's TextEditor hides.
@MainActor
final class ImagePastingTextViewTests: XCTestCase {

    func testPasteIsOfferedWhileTheClipboardHoldsText() {
        UIPasteboard.general.items = []
        UIPasteboard.general.string = "2 eggs"
        let view = ImagePastingTextView()
        XCTAssertTrue(view.canPerformAction(#selector(UIResponderStandardEditActions.paste(_:)), withSender: nil))
    }

    func testPasteIsOfferedWhileTheClipboardHoldsOnlyAnImage() {
        UIPasteboard.general.items = []
        UIPasteboard.general.image = UIImage(systemName: "camera")
        let view = ImagePastingTextView()
        XCTAssertTrue(view.canPerformAction(#selector(UIResponderStandardEditActions.paste(_:)), withSender: nil),
                      "An image-only clipboard must still offer Paste — that is the whole gap this view closes")
    }

    func testPasteIsWithheldWhileTheClipboardIsEmpty() {
        UIPasteboard.general.items = []
        let view = ImagePastingTextView()
        XCTAssertFalse(view.canPerformAction(#selector(UIResponderStandardEditActions.paste(_:)), withSender: nil))
    }

    func testPastingAnImageHandsItUpAndInsertsNothing() {
        UIPasteboard.general.items = []
        UIPasteboard.general.image = UIImage(systemName: "camera")
        let view = ImagePastingTextView()
        var received: UIImage?
        view.onImage = { received = $0 }

        view.paste(nil)

        XCTAssertNotNil(received, "The image must reach the OCR pipeline")
        XCTAssertEqual(view.text, "", "Nothing is inserted into the editor for an image")
    }

    /// Text is left to `UITextView`'s own paste, which only inserts for a text view that is
    /// first responder in a window — not something a unit test has. What is testable here, and
    /// what this view is responsible for, is that it does not divert text to the image path.
    func testPastingTextIsNotDivertedToTheImagePath() {
        UIPasteboard.general.items = []
        UIPasteboard.general.string = "2 cups flour, 2 eggs, 1 cup milk, whisk and fry"
        let view = ImagePastingTextView()
        var received: UIImage?
        view.onImage = { received = $0 }

        view.paste(nil)

        XCTAssertNil(received, "Text must fall through to UITextView, not the OCR pipeline")
    }
}

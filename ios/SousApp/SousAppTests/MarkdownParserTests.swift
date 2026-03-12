import XCTest
@testable import SousApp

final class MarkdownParserTests: XCTestCase {

    // MARK: - Paragraph

    func test_plainText_returnsParagraph() {
        let blocks = MarkdownParser.parse("Hello world")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(blocks[0].content, "Hello world")
    }

    func test_multiLinePlainText_returnsMultipleParagraphs() {
        let blocks = MarkdownParser.parse("Line one\nLine two")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(blocks[1].kind, .paragraph)
    }

    // MARK: - Headings

    func test_h1_returnsHeading1() {
        let blocks = MarkdownParser.parse("# Title")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .heading(1))
        XCTAssertEqual(blocks[0].content, "Title")
    }

    func test_h2_returnsHeading2() {
        let blocks = MarkdownParser.parse("## Subtitle")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .heading(2))
        XCTAssertEqual(blocks[0].content, "Subtitle")
    }

    func test_h3_returnsHeading3() {
        let blocks = MarkdownParser.parse("### Section")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .heading(3))
        XCTAssertEqual(blocks[0].content, "Section")
    }

    func test_hashWithoutSpace_isTreatedAsParagraph() {
        let blocks = MarkdownParser.parse("#hashtag")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
    }

    // MARK: - Bullet lists

    func test_bulletWithDash_returnsBulletItem() {
        let blocks = MarkdownParser.parse("- First item")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .bulletItem)
        XCTAssertEqual(blocks[0].content, "First item")
    }

    func test_bulletWithAsterisk_returnsBulletItem() {
        let blocks = MarkdownParser.parse("* Second item")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .bulletItem)
        XCTAssertEqual(blocks[0].content, "Second item")
    }

    func test_bulletList_multipleItems() {
        let blocks = MarkdownParser.parse("- Alpha\n- Beta\n- Gamma")
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].kind, .bulletItem)
        XCTAssertEqual(blocks[1].kind, .bulletItem)
        XCTAssertEqual(blocks[2].kind, .bulletItem)
        XCTAssertEqual(blocks[0].content, "Alpha")
        XCTAssertEqual(blocks[1].content, "Beta")
        XCTAssertEqual(blocks[2].content, "Gamma")
    }

    func test_dashWithoutSpace_isTreatedAsParagraph() {
        let blocks = MarkdownParser.parse("-noSpace")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
    }

    // MARK: - Numbered lists

    func test_numberedList_singleItem() {
        let blocks = MarkdownParser.parse("1. First step")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .numberedItem(1))
        XCTAssertEqual(blocks[0].content, "First step")
    }

    func test_numberedList_multiDigitNumber() {
        let blocks = MarkdownParser.parse("12. Twelfth step")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .numberedItem(12))
        XCTAssertEqual(blocks[0].content, "Twelfth step")
    }

    func test_numberedList_multipleItems() {
        let blocks = MarkdownParser.parse("1. One\n2. Two\n3. Three")
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].kind, .numberedItem(1))
        XCTAssertEqual(blocks[1].kind, .numberedItem(2))
        XCTAssertEqual(blocks[2].kind, .numberedItem(3))
    }

    func test_numberWithoutPeriodSpace_isTreatedAsParagraph() {
        let blocks = MarkdownParser.parse("1.noSpace")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
    }

    // MARK: - Empty lines

    func test_emptyLine_producesEmptyBlock() {
        let blocks = MarkdownParser.parse("First\n\nSecond")
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(blocks[1].kind, .empty)
        XCTAssertEqual(blocks[2].kind, .paragraph)
    }

    func test_whitespaceOnlyLine_producesEmptyBlock() {
        let blocks = MarkdownParser.parse("First\n   \nSecond")
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[1].kind, .empty)
    }

    // MARK: - Mixed content

    func test_mixedContent_parsesAllBlocks() {
        let text = "# Heading\n\nSome text\n- Bullet\n1. Step"
        let blocks = MarkdownParser.parse(text)
        XCTAssertEqual(blocks.count, 5)
        XCTAssertEqual(blocks[0].kind, .heading(1))
        XCTAssertEqual(blocks[0].content, "Heading")
        XCTAssertEqual(blocks[1].kind, .empty)
        XCTAssertEqual(blocks[2].kind, .paragraph)
        XCTAssertEqual(blocks[2].content, "Some text")
        XCTAssertEqual(blocks[3].kind, .bulletItem)
        XCTAssertEqual(blocks[3].content, "Bullet")
        XCTAssertEqual(blocks[4].kind, .numberedItem(1))
        XCTAssertEqual(blocks[4].content, "Step")
    }

    func test_headingFollowedByList() {
        let text = "## Ingredients\n- Flour\n- Water\n- Salt"
        let blocks = MarkdownParser.parse(text)
        XCTAssertEqual(blocks.count, 4)
        XCTAssertEqual(blocks[0].kind, .heading(2))
        XCTAssertEqual(blocks[1].kind, .bulletItem)
        XCTAssertEqual(blocks[2].kind, .bulletItem)
        XCTAssertEqual(blocks[3].kind, .bulletItem)
    }

    // MARK: - numberedListItem helper

    func test_numberedListItem_validLine() {
        let result = MarkdownParser.numberedListItem("3. Content here")
        XCTAssertEqual(result?.0, 3)
        XCTAssertEqual(result?.1, "Content here")
    }

    func test_numberedListItem_noDigits_returnsNil() {
        XCTAssertNil(MarkdownParser.numberedListItem("hello"))
    }

    func test_numberedListItem_missingPeriod_returnsNil() {
        XCTAssertNil(MarkdownParser.numberedListItem("1 no period"))
    }

    func test_numberedListItem_missingSpace_returnsNil() {
        XCTAssertNil(MarkdownParser.numberedListItem("1.noSpace"))
    }

    func test_numberedListItem_emptyContent_returnsNil() {
        XCTAssertNil(MarkdownParser.numberedListItem("1. "))
    }

    // MARK: - Block ID stability

    func test_blockIds_arePositionalIndices() {
        let blocks = MarkdownParser.parse("Alpha\nBeta\nGamma")
        XCTAssertEqual(blocks[0].id, 0)
        XCTAssertEqual(blocks[1].id, 1)
        XCTAssertEqual(blocks[2].id, 2)
    }
}

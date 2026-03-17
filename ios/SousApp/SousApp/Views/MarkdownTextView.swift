import SwiftUI

// MARK: - Block model

/// A single rendered unit of parsed Markdown content.
struct MarkdownBlock: Identifiable {
    /// Positional index in the original parsed line array — stable for a given input string.
    let id: Int
    let kind: Kind
    let content: String

    enum Kind: Equatable {
        case heading(Int)
        case bulletItem
        case numberedItem(Int)
        case paragraph
        case empty
    }
}

// MARK: - Parser

/// Parses a plain-text string into a sequence of `MarkdownBlock` values.
/// Handles: headings (#, ##, ###), bullet lists (- or *), numbered lists (N.), paragraph text.
/// Inline formatting (bold, italic) is passed through to `AttributedString` for rendering.
enum MarkdownParser {

    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []

        for (index, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(MarkdownBlock(id: index, kind: .empty, content: ""))
            } else if line.hasPrefix("### ") {
                blocks.append(MarkdownBlock(id: index, kind: .heading(3), content: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                blocks.append(MarkdownBlock(id: index, kind: .heading(2), content: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                blocks.append(MarkdownBlock(id: index, kind: .heading(1), content: String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") {
                blocks.append(MarkdownBlock(id: index, kind: .bulletItem, content: String(line.dropFirst(2))))
            } else if line.hasPrefix("* ") {
                blocks.append(MarkdownBlock(id: index, kind: .bulletItem, content: String(line.dropFirst(2))))
            } else if let (number, content) = numberedListItem(line) {
                blocks.append(MarkdownBlock(id: index, kind: .numberedItem(number), content: content))
            } else {
                blocks.append(MarkdownBlock(id: index, kind: .paragraph, content: line))
            }
        }

        return blocks
    }

    /// Parses a numbered list line like "3. Content" → (3, "Content").
    /// Returns nil if the line does not match the pattern.
    static func numberedListItem(_ line: String) -> (Int, String)? {
        var i = line.startIndex
        var digits = ""
        while i < line.endIndex, line[i].isNumber {
            digits.append(line[i])
            i = line.index(after: i)
        }
        guard !digits.isEmpty else { return nil }
        guard i < line.endIndex, line[i] == "." else { return nil }
        i = line.index(after: i)
        guard i < line.endIndex, line[i] == " " else { return nil }
        i = line.index(after: i)
        let content = String(line[i...])
        guard !content.isEmpty else { return nil }
        return (Int(digits) ?? 1, content)
    }
}

// MARK: - View

/// Renders a limited subset of Markdown for use in chat bubbles.
/// Supports: headings, bullet lists, numbered lists, bold (**text**), and italic (*text*).
struct MarkdownTextView: View {
    let text: String
    var textColor: Color = .sousText

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(MarkdownParser.parse(text)) { block in
                blockView(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level):
            inlineText(block.content)
                .font(headingFont(level))
                .foregroundStyle(textColor)
                .padding(.top, level == 1 ? 6 : 2)
                .contentTransition(.opacity)

        case .bulletItem:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousTerracotta)
                inlineText(block.content)
                    .font(.sousBody)
                    .foregroundStyle(textColor)
                    .contentTransition(.opacity)
            }

        case .numberedItem(let number):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%02d.", number))
                    .font(.sousBody)
                    .foregroundStyle(Color.sousTerracotta)
                inlineText(block.content)
                    .font(.sousBody)
                    .foregroundStyle(textColor)
                    .contentTransition(.opacity)
            }

        case .paragraph:
            inlineText(block.content)
                .font(.sousBody)
                .foregroundStyle(textColor)
                .contentTransition(.opacity)

        case .empty:
            Color.clear.frame(height: 4)
        }
    }

    /// Renders content with inline Markdown (bold, italic) via AttributedString.
    private func inlineText(_ content: String) -> Text {
        if let attributed = try? AttributedString(markdown: content) {
            return Text(attributed)
        }
        return Text(content)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 17, weight: .bold, design: .monospaced)
        case 2: return .system(size: 15, weight: .bold, design: .monospaced)
        default: return .system(size: 14, weight: .semibold, design: .monospaced)
        }
    }
}

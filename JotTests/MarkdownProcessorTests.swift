//
//  MarkdownProcessorTests.swift
//  JotTests
//
//  Tests for MarkdownProcessor: verifies that markdown syntax produces
//  the correct NSAttributedString attributes after styling.
//

import XCTest
@testable import Jot

final class MarkdownProcessorTests: XCTestCase {

    private var textView: NSTextView!
    private var font: NSFont!

    override func setUp() {
        super.setUp()
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        font = NSFont.systemFont(ofSize: 14)
    }

    override func tearDown() {
        textView = nil
        font = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func applyAndGetStorage(_ markdown: String) -> NSTextStorage {
        textView.string = markdown
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)
        return textView.textStorage!
    }

    private func fontAt(_ storage: NSTextStorage, location: Int) -> NSFont? {
        return storage.attribute(.font, at: location, effectiveRange: nil) as? NSFont
    }

    private func colorAt(_ storage: NSTextStorage, location: Int) -> NSColor? {
        return storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor
    }

    private func hasTrait(_ storage: NSTextStorage, location: Int, trait: NSFontTraitMask) -> Bool {
        guard let f = fontAt(storage, location: location) else { return false }
        return NSFontManager.shared.traits(of: f).contains(trait)
    }

    // MARK: - Headings

    func testHeadingHashIsSecondaryColor() {
        let storage = applyAndGetStorage("# Hello")

        // "#" at position 0 should be secondary label color
        let hashColor = colorAt(storage, location: 0)
        XCTAssertEqual(hashColor, NSColor.secondaryLabelColor)
    }

    func testHeadingTextIsBold() {
        let storage = applyAndGetStorage("# Hello")

        // "H" starts at position 2
        XCTAssertTrue(hasTrait(storage, location: 2, trait: .boldFontMask))
    }

    func testHeadingH3() {
        let storage = applyAndGetStorage("### Third level")

        // "###" at 0-2 should be secondary color
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
        XCTAssertEqual(colorAt(storage, location: 2), NSColor.secondaryLabelColor)

        // "T" at position 4
        XCTAssertTrue(hasTrait(storage, location: 4, trait: .boldFontMask))
    }

    func testHeadingRequiresSpace() {
        let storage = applyAndGetStorage("#NoSpace")

        // Should NOT be styled as a heading
        XCTAssertFalse(hasTrait(storage, location: 1, trait: .boldFontMask))
    }

    // MARK: - Bold

    func testBoldAsterisks() {
        let storage = applyAndGetStorage("some **bold** text")

        // "b" is at position 7 (after "some **")
        XCTAssertTrue(hasTrait(storage, location: 7, trait: .boldFontMask))

        // "s" at position 0 should not be bold
        XCTAssertFalse(hasTrait(storage, location: 0, trait: .boldFontMask))
    }

    func testBoldUnderscores() {
        let storage = applyAndGetStorage("some __bold__ text")

        // "b" is at position 7 (after "some __")
        XCTAssertTrue(hasTrait(storage, location: 7, trait: .boldFontMask))
    }

    func testBoldSymbolsAreSecondaryColor() {
        let storage = applyAndGetStorage("**bold**")

        // "**" at positions 0-1
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
        // "**" at positions 6-7
        XCTAssertEqual(colorAt(storage, location: 6), NSColor.secondaryLabelColor)
    }

    // MARK: - Italic

    func testItalicAsterisks() {
        let storage = applyAndGetStorage("some *italic* text")

        // "i" is at position 6
        XCTAssertTrue(hasTrait(storage, location: 6, trait: .italicFontMask))
    }

    func testItalicUnderscores() {
        let storage = applyAndGetStorage("some _italic_ text")

        XCTAssertTrue(hasTrait(storage, location: 6, trait: .italicFontMask))
    }

    func testUnderscoreInWordNotItalic() {
        let storage = applyAndGetStorage("file_name_here")

        // Should NOT be italic -- underscores mid-word
        XCTAssertFalse(hasTrait(storage, location: 5, trait: .italicFontMask))
    }

    // MARK: - Bold/Italic interaction

    func testBoldDoesNotConsumeItalic() {
        let storage = applyAndGetStorage("**bold** and *italic*")

        // "b" at 2 should be bold
        XCTAssertTrue(hasTrait(storage, location: 2, trait: .boldFontMask))
        // "i" at 14 should be italic
        XCTAssertTrue(hasTrait(storage, location: 14, trait: .italicFontMask))
    }

    // MARK: - Inline code

    func testInlineCodeHasBackground() {
        let storage = applyAndGetStorage("some `code` here")

        // "c" is at position 6
        let bg = storage.attribute(.backgroundColor, at: 6, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(bg)
    }

    func testInlineCodeIsSecondaryColor() {
        let storage = applyAndGetStorage("some `code` here")

        XCTAssertEqual(colorAt(storage, location: 6), NSColor.secondaryLabelColor)
    }

    func testTextOutsideCodeHasNoBackground() {
        let storage = applyAndGetStorage("some `code` here")

        let bg = storage.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNil(bg)
    }

    // MARK: - Code blocks

    func testCodeBlockHasBackground() {
        let storage = applyAndGetStorage("```\nlet x = 1\n```")

        // "l" at position 4
        let bg = storage.attribute(.backgroundColor, at: 4, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(bg)
    }

    // MARK: - Links

    func testLinkTextIsLinkColor() {
        let storage = applyAndGetStorage("[click](https://example.com)")

        // "c" at position 1
        XCTAssertEqual(colorAt(storage, location: 1), NSColor.linkColor)
    }

    func testLinkTextIsUnderlined() {
        let storage = applyAndGetStorage("[click](https://example.com)")

        let underline = storage.attribute(.underlineStyle, at: 1, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
    }

    func testLinkBracketsAreSecondaryColor() {
        let storage = applyAndGetStorage("[click](https://example.com)")

        // "[" at position 0
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
    }

    // MARK: - Strikethrough

    func testStrikethroughApplied() {
        let storage = applyAndGetStorage("~~deleted~~")

        // "d" at position 2
        let strike = storage.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    func testStrikethroughSymbolsAreSecondaryColor() {
        let storage = applyAndGetStorage("~~deleted~~")

        // "~~" at 0-1
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
        // "~~" at 9-10
        XCTAssertEqual(colorAt(storage, location: 9), NSColor.secondaryLabelColor)
    }

    // MARK: - Lists

    func testUnorderedListMarkerIsSecondaryColor() {
        let storage = applyAndGetStorage("- item one")

        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
    }

    func testOrderedListMarkerIsSecondaryColor() {
        let storage = applyAndGetStorage("1. first item")

        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
    }

    // MARK: - Blockquotes

    func testBlockquotePrefixIsTertiaryColor() {
        let storage = applyAndGetStorage("> quoted text")

        // ">" at position 0
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.tertiaryLabelColor)
    }

    func testBlockquoteContentIsSecondaryColor() {
        let storage = applyAndGetStorage("> quoted text")

        // "q" at position 2
        XCTAssertEqual(colorAt(storage, location: 2), NSColor.secondaryLabelColor)
    }

    // MARK: - Horizontal rules

    func testHorizontalRuleIsTertiaryColor() {
        let storage = applyAndGetStorage("---")

        XCTAssertEqual(colorAt(storage, location: 0), NSColor.tertiaryLabelColor)
    }

    func testHorizontalRuleAsterisks() {
        let storage = applyAndGetStorage("***")

        XCTAssertEqual(colorAt(storage, location: 0), NSColor.tertiaryLabelColor)
    }

    // MARK: - Reset pass

    func testRestylingClearsStaleBold() {
        // First pass: bold text
        textView.string = "**bold**"
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)
        XCTAssertTrue(hasTrait(textView.textStorage!, location: 2, trait: .boldFontMask))

        // Second pass: remove the markdown syntax
        textView.string = "not bold"
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)
        XCTAssertFalse(hasTrait(textView.textStorage!, location: 0, trait: .boldFontMask))
    }

    // MARK: - Plain text unchanged

    func testPlainTextIsLabelColor() {
        let storage = applyAndGetStorage("Just plain text, nothing special.")

        XCTAssertEqual(colorAt(storage, location: 0), NSColor.labelColor)
    }

    func testPlainTextHasSelectedFont() {
        let storage = applyAndGetStorage("Plain text")

        let appliedFont = fontAt(storage, location: 0)
        XCTAssertEqual(appliedFont, font)
    }
}

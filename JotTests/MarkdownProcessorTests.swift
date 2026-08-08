//
//  MarkdownProcessorTests.swift
//  JotTests
//
//  Tests for MarkdownProcessor: verifies that markdown syntax produces
//  the correct NSAttributedString attributes after styling.
//

import XCTest
@testable import Jot

@MainActor
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

    // MARK: - Tables

    func testTablePipeIsSecondaryColor() {
        let storage = applyAndGetStorage("| Col 1 | Col 2 |")

        // "|" at position 0
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
    }

    func testTableSeparatorIsTertiaryColor() {
        let storage = applyAndGetStorage("| H1 | H2 |\n| --- | --- |")

        // The separator row starts at position 12
        // "|" at position 12 should be tertiary (overridden by separator styling)
        XCTAssertEqual(colorAt(storage, location: 12), NSColor.tertiaryLabelColor)
    }

    func testTableHeaderIsBold() {
        let storage = applyAndGetStorage("| H1 | H2 |\n| --- | --- |")

        // "H" at position 2 should be bold (header row before separator)
        XCTAssertTrue(hasTrait(storage, location: 2, trait: .boldFontMask))
    }

    func testTableDataRowIsNotBold() {
        let storage = applyAndGetStorage("| H1 | H2 |\n| --- | --- |\n| d1 | d2 |")

        // "d" at position 27 should not be bold (position 25 is "|", 26 is " ")
        XCTAssertFalse(hasTrait(storage, location: 27, trait: .boldFontMask))
    }

    func testTableSeparatorWithAlignmentColons() {
        let storage = applyAndGetStorage("| H1 | H2 |\n|:--- | ---:|")

        // "|" at position 12 starts the separator row
        XCTAssertEqual(colorAt(storage, location: 12), NSColor.tertiaryLabelColor)
        XCTAssertTrue(hasTrait(storage, location: 2, trait: .boldFontMask))
    }

    // MARK: - Checklists (#146)

    private func strikethroughAt(_ storage: NSTextStorage, location: Int) -> Bool {
        return storage.attribute(.strikethroughStyle, at: location, effectiveRange: nil) != nil
    }

    func testUncheckedItemDimsMarkerOnly() {
        let storage = applyAndGetStorage("- [ ] task")

        // Marker "- [ ] " is positions 0-5
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
        XCTAssertEqual(colorAt(storage, location: 5), NSColor.secondaryLabelColor)
        // Content "task" starts at 6: normal color, no strikethrough
        XCTAssertEqual(colorAt(storage, location: 6), NSColor.labelColor)
        XCTAssertFalse(strikethroughAt(storage, location: 6))
    }

    func testCheckedItemIsStruckThroughAndDimmed() {
        let storage = applyAndGetStorage("- [x] done")

        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
        XCTAssertTrue(strikethroughAt(storage, location: 6))
        XCTAssertEqual(colorAt(storage, location: 6), NSColor.secondaryLabelColor)
    }

    func testCheckedItemCapitalXAndIndentAlsoStyle() {
        let storage = applyAndGetStorage("\t- [X] done")

        // Content "done" starts at 7 (tab + "- [X] ")
        XCTAssertTrue(strikethroughAt(storage, location: 7))
        XCTAssertEqual(colorAt(storage, location: 7), NSColor.secondaryLabelColor)
    }

    func testBracketsWithoutTrailingSpaceAreNotAChecklist() {
        let storage = applyAndGetStorage("- [x]done")

        // "d" at position 5 is ordinary content of a plain bullet item
        XCTAssertFalse(strikethroughAt(storage, location: 5))
        XCTAssertEqual(colorAt(storage, location: 5), NSColor.labelColor)
    }

    func testCheckedItemDimsInlineStylesUniformly() {
        // Deliberate (2026-08 review): checking an item dims the whole
        // content — link coloring included — so the item reads as done,
        // matching Reminders/Notes. The [x] characters still carry the
        // state, and the .link attribute is unaffected.
        let storage = applyAndGetStorage("- [x] see [docs](https://e.com)")

        // "d" of "docs" at position 11: dimmed, not linkColor
        XCTAssertEqual(colorAt(storage, location: 11), NSColor.secondaryLabelColor)
        XCTAssertTrue(strikethroughAt(storage, location: 11))
    }

    func testCheckedItemWithEmptyContentDoesNotCrash() {
        let storage = applyAndGetStorage("- [x] ")

        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
    }

    func testUncheckingRemovesStrikethrough() {
        let storage = applyAndGetStorage("- [x] done")
        XCTAssertTrue(strikethroughAt(storage, location: 6))

        // Flip the state character in place, as the toggle command does,
        // then restyle: the reset pass must clear the stale strikethrough.
        storage.replaceCharacters(in: NSRange(location: 3, length: 1), with: " ")
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)
        XCTAssertFalse(strikethroughAt(storage, location: 6))
    }

    // MARK: - Nested emphasis composes (#127 follow-up)

    func testItalicNestedInsideBoldComposes() {
        let storage = applyAndGetStorage("**exercitation *ullamco* laboris**")

        // "exercitation" at 2: bold only
        XCTAssertTrue(hasTrait(storage, location: 2, trait: .boldFontMask))
        XCTAssertFalse(hasTrait(storage, location: 2, trait: .italicFontMask))
        // "ullamco" at 16: bold AND italic
        XCTAssertTrue(hasTrait(storage, location: 16, trait: .boldFontMask))
        XCTAssertTrue(hasTrait(storage, location: 16, trait: .italicFontMask))
        // "laboris" at 25: bold only
        XCTAssertTrue(hasTrait(storage, location: 25, trait: .boldFontMask))
        XCTAssertFalse(hasTrait(storage, location: 25, trait: .italicFontMask))
    }

    func testBoldNestedInsideItalicComposes() {
        let storage = applyAndGetStorage("*velit **esse** cillum* dolore")

        // "velit" at 1: italic only
        XCTAssertTrue(hasTrait(storage, location: 1, trait: .italicFontMask))
        XCTAssertFalse(hasTrait(storage, location: 1, trait: .boldFontMask))
        // "esse" at 9: bold AND italic
        XCTAssertTrue(hasTrait(storage, location: 9, trait: .boldFontMask))
        XCTAssertTrue(hasTrait(storage, location: 9, trait: .italicFontMask))
        // "cillum" at 16: italic only
        XCTAssertTrue(hasTrait(storage, location: 16, trait: .italicFontMask))
        XCTAssertFalse(hasTrait(storage, location: 16, trait: .boldFontMask))
        // "dolore" at 24: unstyled
        XCTAssertFalse(hasTrait(storage, location: 24, trait: .italicFontMask))
    }

    func testMixedMarkerNestingComposes() {
        let storage = applyAndGetStorage("**bold _it_ bold**")

        XCTAssertTrue(hasTrait(storage, location: 2, trait: .boldFontMask))
        XCTAssertFalse(hasTrait(storage, location: 2, trait: .italicFontMask))
        // "it" at 8: bold AND italic via mixed markers
        XCTAssertTrue(hasTrait(storage, location: 8, trait: .boldFontMask))
        XCTAssertTrue(hasTrait(storage, location: 8, trait: .italicFontMask))
        XCTAssertTrue(hasTrait(storage, location: 12, trait: .boldFontMask))
    }

    func testTripleAsteriskStillBoldItalic() {
        let storage = applyAndGetStorage("***both***")

        XCTAssertTrue(hasTrait(storage, location: 4, trait: .boldFontMask))
        XCTAssertTrue(hasTrait(storage, location: 4, trait: .italicFontMask))
    }

    func testPlainBoldStillNotItalic() {
        let storage = applyAndGetStorage("**text**")

        XCTAssertTrue(hasTrait(storage, location: 3, trait: .boldFontMask))
        XCTAssertFalse(hasTrait(storage, location: 3, trait: .italicFontMask))
    }

    func testPathologicalNestedEmphasisStylesQuickly() {
        // Many almost-matching emphasis spans; the nesting-aware patterns
        // must stay linear (same property as the table patterns in #122)
        let line = String(repeating: "**a *b ", count: 200) + "x"
        let start = Date()

        _ = applyAndGetStorage(line)

        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0,
                          "emphasis styling must be linear in line length")
    }

    // MARK: - Regex denial of service (#122)
    //
    // The old table patterns used nested quantifiers ((.+\|)+), which
    // backtrack exponentially on pipe-heavy lines that almost match --
    // a crafted ~40-cell line hung the app for hours. These inputs must
    // style instantly. If a nested quantifier ever comes back, these
    // tests hang CI rather than fail politely, which is the point.

    func testPathologicalTableRowStylesQuickly() {
        // Almost a table row: many cells but no trailing pipe
        let line = "|" + String(repeating: "aaa|", count: 60) + "x"
        let start = Date()

        _ = applyAndGetStorage(line)

        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0,
                          "table-row styling must be linear in line length")
    }

    func testPathologicalTableSeparatorStylesQuickly() {
        // Almost a separator row: many aligned cells but a broken tail
        let line = "|" + String(repeating: ":---:|", count: 60) + "x"
        let start = Date()

        _ = applyAndGetStorage(line)

        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0,
                          "separator styling must be linear in line length")
    }

    // MARK: - Bold underscore single character

    func testBoldUnderscoreSingleChar() {
        let storage = applyAndGetStorage("__x__")

        // "x" at position 2 should be bold
        XCTAssertTrue(hasTrait(storage, location: 2, trait: .boldFontMask))
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

    // MARK: - Edge cases

    func testEmptyStringDoesNotCrash() {
        let storage = applyAndGetStorage("")
        XCTAssertEqual(storage.length, 0)
    }

    func testBoldItalicComboAppliesBothTraits() {
        let storage = applyAndGetStorage("***bold italic***")

        // "b" at position 3 (after "***") should have both bold and italic
        XCTAssertTrue(hasTrait(storage, location: 3, trait: .boldFontMask))
        XCTAssertTrue(hasTrait(storage, location: 3, trait: .italicFontMask))
    }

    func testBoldItalicSymbolsAreSecondaryColor() {
        let storage = applyAndGetStorage("***bold italic***")

        // "***" at positions 0-2 should be secondary color
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
        // "***" at positions 14-16 should be secondary color
        XCTAssertEqual(colorAt(storage, location: 14), NSColor.secondaryLabelColor)
    }

    func testBoldRegexDoesNotMatchInsideTripleAsterisk() {
        let storage = applyAndGetStorage("***combo***")

        // "c" at position 3 should have both bold AND italic (from the
        // bold-italic regex), not just bold (from the bold regex stealing
        // a partial match inside the triple asterisks).
        XCTAssertTrue(hasTrait(storage, location: 3, trait: .boldFontMask))
        XCTAssertTrue(hasTrait(storage, location: 3, trait: .italicFontMask))
    }

    func testSpacesInsideBoldUnderscoresNotBold() {
        let storage = applyAndGetStorage("__ x __")

        // "x" at position 3 should NOT be bold (spaces inside delimiters)
        XCTAssertFalse(hasTrait(storage, location: 3, trait: .boldFontMask))
    }

    func testEmptyBoldDelimitersNotStyled() {
        let storage = applyAndGetStorage("****")

        // Should not crash, should not apply bold styling to surrounding text
        XCTAssertFalse(hasTrait(storage, location: 0, trait: .boldFontMask))
    }

    func testEmptyStrikethroughNotStyled() {
        let storage = applyAndGetStorage("~~~~")

        let strike = storage.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        // Empty strikethrough delimiters should not produce strikethrough
        XCTAssertNil(strike)
    }

    func testH7NotAHeading() {
        let storage = applyAndGetStorage("####### Not a heading")

        // H7 does not exist in markdown -- should not be bold
        XCTAssertFalse(hasTrait(storage, location: 8, trait: .boldFontMask))
    }

    func testCodeBlockWithLanguage() {
        let storage = applyAndGetStorage("```swift\nlet x = 1\n```")

        // "l" at position 9 should have background
        let bg = storage.attribute(.backgroundColor, at: 9, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(bg)
    }

    func testMultiDigitOrderedList() {
        let storage = applyAndGetStorage("10. Tenth item")

        // "1" at position 0 should be secondary color
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.secondaryLabelColor)
    }

    func testBlockquoteWithoutSpace() {
        let storage = applyAndGetStorage(">no space")

        // Should still be styled as blockquote -- ">" at 0
        XCTAssertEqual(colorAt(storage, location: 0), NSColor.tertiaryLabelColor)
    }

    func testBoldInsideHeading() {
        let storage = applyAndGetStorage("# **Bold heading**")

        // "B" at position 5 should be bold
        XCTAssertTrue(hasTrait(storage, location: 5, trait: .boldFontMask))
    }

    func testMultiLineDocument() {
        let markdown = "# Title\n\nSome **bold** and *italic* text.\n\n- List item\n\n> A quote"

        let storage = applyAndGetStorage(markdown)

        // "T" at position 2 (after "# ") should be bold
        XCTAssertTrue(hasTrait(storage, location: 2, trait: .boldFontMask))
        // "b" at position 16 (inside **bold**, after "# Title\n\nSome **") should be bold
        XCTAssertTrue(hasTrait(storage, location: 16, trait: .boldFontMask))
    }

    // MARK: - Mode switching (#37)

    // MARK: - Ranged passes stay bounded (#123)

    func testRangedPassInsideCodeBlockKeepsBackground() {
        let markdown = "```\ncode line\n```"
        _ = applyAndGetStorage(markdown)
        // Restyle just the "code line" line, as a keystroke inside it would
        let lineRange = (markdown as NSString).range(of: "code line")
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font, range: lineRange)

        XCTAssertNotNil(textView.textStorage!.attribute(.backgroundColor, at: 5, effectiveRange: nil),
                        "a bounded pass inside a fenced block must re-apply the block background")
    }

    func testRangedPassLeavesDistantStylingAlone() {
        let markdown = "**bold**\n\n```\ncode\n```"
        _ = applyAndGetStorage(markdown)
        // Restyle only the first line; the code block further down must keep
        // its background even though the pass never touched it
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font, range: NSRange(location: 0, length: 8))

        let codeLocation = (markdown as NSString).range(of: "code\n").location
        XCTAssertNotNil(textView.textStorage!.attribute(.backgroundColor, at: codeLocation, effectiveRange: nil),
                        "a pass over line 1 must not strip the code background further down")
        XCTAssertTrue(hasTrait(textView.textStorage!, location: 2, trait: .boldFontMask))
    }

    func testRangedPassExpandsToWholeLine() {
        textView.string = "# Heading line"
        // Deliberately mid-line: two characters inside the heading text
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font, range: NSRange(location: 5, length: 2))

        XCTAssertTrue(hasTrait(textView.textStorage!, location: 3, trait: .boldFontMask),
                      "the pass must expand to line boundaries so line-anchored patterns match")
    }

    func testSwitchToMarkdownAppliesStyling() {
        textView.string = "# Heading"
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)

        // After switching to markdown, heading text should be bold
        XCTAssertTrue(hasTrait(textView.textStorage!, location: 2, trait: .boldFontMask))
    }

    func testSwitchToPlainTextRemovesStyling() {
        // Apply markdown styling first
        textView.string = "**bold** and ~~struck~~"
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)
        XCTAssertTrue(hasTrait(textView.textStorage!, location: 2, trait: .boldFontMask))

        // Remove styling (simulates switching to plain text)
        let storage = textView.textStorage!
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.font, range: fullRange)
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.removeAttribute(.backgroundColor, range: fullRange)
        storage.removeAttribute(.strikethroughStyle, range: fullRange)
        storage.removeAttribute(.underlineStyle, range: fullRange)
        storage.removeAttribute(.link, range: fullRange)
        storage.addAttribute(.font, value: font!, range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        storage.endEditing()

        // Bold should be gone
        XCTAssertFalse(hasTrait(storage, location: 2, trait: .boldFontMask))
        // Strikethrough should be gone
        let strike = storage.attribute(.strikethroughStyle, at: 11, effectiveRange: nil) as? Int
        XCTAssertNil(strike)
        // Background should be gone
        let bg = storage.attribute(.backgroundColor, at: 2, effectiveRange: nil) as? NSColor
        XCTAssertNil(bg)
    }

    func testPlainTextUsesSemanticTextColor() {
        // After removing markdown styling, foreground should be NSColor.textColor
        // (not hardcoded black/white), so dark mode works correctly
        textView.string = "**bold**"
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)

        let storage = textView.textStorage!
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        storage.endEditing()

        let color = colorAt(storage, location: 2)
        XCTAssertEqual(color, NSColor.textColor)
    }

    func testModeRoundTripPreservesContent() {
        let original = "# Title\n\nSome **bold** text."
        textView.string = original

        // Switch to markdown
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)

        // Switch back to plain text
        let storage = textView.textStorage!
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.font, range: fullRange)
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.removeAttribute(.backgroundColor, range: fullRange)
        storage.removeAttribute(.strikethroughStyle, range: fullRange)
        storage.removeAttribute(.underlineStyle, range: fullRange)
        storage.removeAttribute(.link, range: fullRange)
        storage.addAttribute(.font, value: font!, range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        storage.endEditing()

        // Text content should be unchanged
        XCTAssertEqual(textView.string, original)
    }

    func testModeSwitchEmptyDocument() {
        textView.string = ""

        // Should not crash on empty document
        MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)
        XCTAssertEqual(textView.textStorage!.length, 0)

        // Remove styling on empty document should also not crash
        let storage = textView.textStorage!
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.font, range: fullRange)
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.removeAttribute(.backgroundColor, range: fullRange)
        storage.addAttribute(.font, value: font!, range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        storage.endEditing()

        XCTAssertEqual(textView.string, "")
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

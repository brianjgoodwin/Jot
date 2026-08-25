//
//  FormatMenuCommandTests.swift
//  JotTests
//
//  Tests for the Format menu markdown commands added in #96:
//  strikethrough/highlight/inline-code wrappers, link insertion, and
//  the line commands (blockquote, ordered/unordered list) as they run
//  through a real editor. The pure line transforms are covered in
//  BlockFormatTests; these check the text-view glue — replacement
//  ranges, caret placement, and selection after the edit.
//

import XCTest
@testable import Jot

@MainActor
final class FormatMenuCommandTests: XCTestCase {

    private struct CommandResult {
        let text: String
        let selection: NSRange
    }

    // Each test builds its own document/editor pair: XCTest's setUp is
    // nonisolated under Swift 6, so stored main-actor fixtures fight the
    // compiler for no benefit (same pattern as EditorFormattingTests).
    private func run(_ text: String, select: NSRange,
                     _ command: (EditorViewController) -> Void) throws -> CommandResult {
        let document = Document()
        document.makeWindowControllers()
        defer { document.close() }

        let editor = try XCTUnwrap(
            document.windowControllers.first?.contentViewController as? EditorViewController
        )
        editor.textView.string = text
        editor.textView.setSelectedRange(select)
        command(editor)
        return CommandResult(text: editor.textView.string,
                             selection: editor.textView.selectedRange())
    }

    // MARK: - Symmetric wrappers

    func testStrikethroughWrapsSelection() throws {
        let result = try run("text", select: NSRange(location: 0, length: 4)) {
            $0.toggleStrikethroughMarkdown(self)
        }
        XCTAssertEqual(result.text, "~~text~~")
        XCTAssertEqual(result.selection, NSRange(location: 2, length: 4))
    }

    func testStrikethroughRemovesSurroundingMarkers() throws {
        let result = try run("~~text~~", select: NSRange(location: 2, length: 4)) {
            $0.toggleStrikethroughMarkdown(self)
        }
        XCTAssertEqual(result.text, "text")
        XCTAssertEqual(result.selection, NSRange(location: 0, length: 4))
    }

    func testStrikethroughNormalizesSelectionIncludingMarkers() throws {
        let result = try run("~~text~~", select: NSRange(location: 0, length: 8)) {
            $0.toggleStrikethroughMarkdown(self)
        }
        XCTAssertEqual(result.text, "text")
        XCTAssertEqual(result.selection, NSRange(location: 0, length: 4))
    }

    func testStrikethroughWithNoSelectionInsertsEmptyPair() throws {
        let result = try run("", select: NSRange(location: 0, length: 0)) {
            $0.toggleStrikethroughMarkdown(self)
        }
        XCTAssertEqual(result.text, "~~~~")
        XCTAssertEqual(result.selection, NSRange(location: 2, length: 0))
    }

    func testHighlightWrapsSelection() throws {
        let result = try run("text", select: NSRange(location: 0, length: 4)) {
            $0.toggleHighlightMarkdown(self)
        }
        XCTAssertEqual(result.text, "==text==")
    }

    func testInlineCodeWrapsSelection() throws {
        let result = try run("text", select: NSRange(location: 0, length: 4)) {
            $0.toggleInlineCodeMarkdown(self)
        }
        XCTAssertEqual(result.text, "`text`")
        XCTAssertEqual(result.selection, NSRange(location: 1, length: 4))
    }

    func testInlineCodeRemovesSurroundingBackticks() throws {
        let result = try run("`text`", select: NSRange(location: 1, length: 4)) {
            $0.toggleInlineCodeMarkdown(self)
        }
        XCTAssertEqual(result.text, "text")
    }

    // MARK: - Link

    func testLinkWrapsSelectionAndPutsCaretInParentheses() throws {
        let result = try run("Jot site", select: NSRange(location: 0, length: 3)) {
            $0.insertLinkMarkdown(self)
        }
        XCTAssertEqual(result.text, "[Jot]() site")
        XCTAssertEqual(result.selection, NSRange(location: 6, length: 0))
    }

    func testLinkWithNoSelectionPutsCaretInBrackets() throws {
        let result = try run("", select: NSRange(location: 0, length: 0)) {
            $0.insertLinkMarkdown(self)
        }
        XCTAssertEqual(result.text, "[]()")
        XCTAssertEqual(result.selection, NSRange(location: 1, length: 0))
    }

    // MARK: - Line commands

    func testBlockquoteQuotesAllSelectedLines() throws {
        let result = try run("one\ntwo\nthree", select: NSRange(location: 0, length: 13)) {
            $0.toggleBlockquote(self)
        }
        XCTAssertEqual(result.text, "> one\n> two\n> three")
        XCTAssertEqual(result.selection, NSRange(location: 0, length: 19))
    }

    func testBlockquoteToggleRoundTripsViaTheKeptSelection() throws {
        let document = Document()
        document.makeWindowControllers()
        defer { document.close() }
        let editor = try XCTUnwrap(
            document.windowControllers.first?.contentViewController as? EditorViewController
        )
        editor.textView.string = "one\ntwo"
        editor.textView.setSelectedRange(NSRange(location: 0, length: 7))

        editor.toggleBlockquote(self)
        editor.toggleBlockquote(self)
        XCTAssertEqual(editor.textView.string, "one\ntwo")
    }

    func testOrderedListActsOnCaretLineOnly() throws {
        let result = try run("first\nsecond\n", select: NSRange(location: 0, length: 0)) {
            $0.toggleOrderedList(self)
        }
        XCTAssertEqual(result.text, "1. first\nsecond\n")
    }

    func testOrderedListSelectionDoesNotSwallowTrailingNewline() throws {
        // Selecting through the newline after "two" must not pull the
        // line after the selection into a repeat of the command.
        let result = try run("one\ntwo\nthree", select: NSRange(location: 0, length: 8)) {
            $0.toggleOrderedList(self)
        }
        XCTAssertEqual(result.text, "1. one\n2. two\nthree")
        XCTAssertEqual(result.selection, NSRange(location: 0, length: 13))
    }

    func testUnorderedListBulletsSelectedLines() throws {
        let result = try run("one\ntwo", select: NSRange(location: 0, length: 7)) {
            $0.toggleUnorderedList(self)
        }
        XCTAssertEqual(result.text, "- one\n- two")
    }
}

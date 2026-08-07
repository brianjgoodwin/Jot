//
//  EditorFormattingTests.swift
//  JotTests
//
//  Tests for the bold/italic marker toggles (#127): the toggles must
//  compose -- bold + italic = ***text*** -- instead of corrupting each
//  other's markers.
//

import XCTest
@testable import Jot

@MainActor
final class EditorFormattingTests: XCTestCase {

    private struct ToggleResult {
        let text: String
        let selection: NSRange
    }

    // Each test builds its own document/editor pair: XCTest's setUp is
    // nonisolated under Swift 6, so stored main-actor fixtures fight the
    // compiler for no benefit
    private func runToggle(_ text: String, select: NSRange, italic: Bool) throws -> ToggleResult {
        let document = Document()
        document.makeWindowControllers()
        defer { document.close() }

        let editor = try XCTUnwrap(
            document.windowControllers.first?.contentViewController as? EditorViewController
        )
        editor.textView.string = text
        editor.textView.setSelectedRange(select)
        if italic {
            editor.toggleItalicMarkdown(self)
        } else {
            editor.toggleBoldMarkdown(self)
        }
        return ToggleResult(text: editor.textView.string, selection: editor.textView.selectedRange())
    }

    private func runBold(_ text: String, select: NSRange) throws -> String {
        try runToggle(text, select: select, italic: false).text
    }

    private func runItalic(_ text: String, select: NSRange) throws -> String {
        try runToggle(text, select: select, italic: true).text
    }

    // MARK: - Plain text

    func testBoldWrapsPlainSelection() throws {
        XCTAssertEqual(try runBold("text", select: NSRange(location: 0, length: 4)), "**text**")
    }

    func testItalicWrapsPlainSelection() throws {
        XCTAssertEqual(try runItalic("text", select: NSRange(location: 0, length: 4)), "*text*")
    }

    func testBoldRemovesExistingBold() throws {
        XCTAssertEqual(try runBold("**text**", select: NSRange(location: 2, length: 4)), "text")
    }

    func testItalicRemovesExistingItalic() throws {
        XCTAssertEqual(try runItalic("*text*", select: NSRange(location: 1, length: 4)), "text")
    }

    // MARK: - Composition (the #127 bugs)

    func testItalicOnBoldAddsThirdAsterisk() throws {
        // Was the corruption: **text** became *text*
        XCTAssertEqual(try runItalic("**text**", select: NSRange(location: 2, length: 4)), "***text***")
    }

    func testBoldOnItalicAddsBoldMarkers() throws {
        XCTAssertEqual(try runBold("*text*", select: NSRange(location: 1, length: 4)), "***text***")
    }

    func testItalicOnBoldItalicRemovesItalicKeepsBold() throws {
        XCTAssertEqual(try runItalic("***text***", select: NSRange(location: 3, length: 4)), "**text**")
    }

    func testBoldOnBoldItalicRemovesBoldKeepsItalic() throws {
        XCTAssertEqual(try runBold("***text***", select: NSRange(location: 3, length: 4)), "*text*")
    }

    // MARK: - Selection including the markers (was double-wrapped)

    func testBoldSelectionIncludingMarkersUnwraps() throws {
        XCTAssertEqual(try runBold("**text**", select: NSRange(location: 0, length: 8)), "text")
    }

    func testItalicSelectionIncludingMarkersUnwraps() throws {
        XCTAssertEqual(try runItalic("*text*", select: NSRange(location: 0, length: 6)), "text")
    }

    // MARK: - Mid-document selections

    func testBoldMidDocument() throws {
        XCTAssertEqual(try runBold("a **text** b", select: NSRange(location: 4, length: 4)), "a text b")
    }

    func testItalicMidDocumentOnBold() throws {
        XCTAssertEqual(try runItalic("a **text** b", select: NSRange(location: 4, length: 4)), "a ***text*** b")
    }

    // MARK: - Empty selection inserts a marker pair

    func testBoldEmptySelectionInsertsMarkers() throws {
        let result = try runToggle("", select: NSRange(location: 0, length: 0), italic: false)
        XCTAssertEqual(result.text, "****")
        XCTAssertEqual(result.selection, NSRange(location: 2, length: 0))
    }

    func testItalicEmptySelectionInsertsMarkers() throws {
        let result = try runToggle("", select: NSRange(location: 0, length: 0), italic: true)
        XCTAssertEqual(result.text, "**")
        XCTAssertEqual(result.selection, NSRange(location: 1, length: 0))
    }

    // MARK: - Selection lands on the inner text afterward

    func testSelectionCoversInnerTextAfterToggle() throws {
        let result = try runToggle("**text**", select: NSRange(location: 2, length: 4), italic: true)
        // "***text***" -- inner text starts after the three markers
        XCTAssertEqual(result.selection, NSRange(location: 3, length: 4))
    }

    // MARK: - Degenerate all-asterisk selection

    func testAllAsteriskSelectionIsTreatedAsText() throws {
        XCTAssertEqual(try runBold("***", select: NSRange(location: 0, length: 3)), "*******")
    }
}

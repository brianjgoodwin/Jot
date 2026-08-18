//
//  SnippetInsertionTests.swift
//  JotTests
//
//  Tests for Edit > Insert Snippet (#162): inserting a snippet file's
//  text into the editor at the selection, with cursor placement and
//  undo behavior.
//

import XCTest
@testable import Jot

@MainActor
final class SnippetInsertionTests: XCTestCase {

    private struct InsertResult {
        let text: String
        let selection: NSRange
    }

    /// Runs `body` with a fresh temp directory that is removed afterward.
    private func withTempFolder(_ body: (URL) throws -> Void) throws {
        let tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFolder) }
        try body(tempFolder)
    }

    // Each test builds its own document/editor pair: XCTest's setUp is
    // nonisolated under Swift 6, so stored main-actor fixtures fight the
    // compiler for no benefit
    private func runInsert(snippet: String, into text: String, select: NSRange) throws -> InsertResult {
        var result = InsertResult(text: "", selection: NSRange())
        try withTempFolder { folder in
            let snippetURL = folder.appendingPathComponent("Snippet.txt")
            try snippet.write(to: snippetURL, atomically: true, encoding: .utf8)

            let document = Document()
            document.makeWindowControllers()
            defer { document.close() }

            let editor = try XCTUnwrap(
                document.windowControllers.first?.contentViewController as? EditorViewController
            )
            editor.textView.string = text
            editor.textView.setSelectedRange(select)

            let item = NSMenuItem()
            item.representedObject = snippetURL
            editor.insertSnippet(item)

            result = InsertResult(text: editor.textView.string,
                                  selection: editor.textView.selectedRange())
        }
        return result
    }

    func testInsertsAtCaret() throws {
        let result = try runInsert(snippet: "XY", into: "ab", select: NSRange(location: 1, length: 0))

        XCTAssertEqual(result.text, "aXYb")
        XCTAssertEqual(result.selection, NSRange(location: 3, length: 0))
    }

    func testReplacesSelection() throws {
        let result = try runInsert(snippet: "new", into: "the old text",
                                   select: NSRange(location: 4, length: 3))

        XCTAssertEqual(result.text, "the new text")
    }

    func testCursorMarkerPlacesCaret() throws {
        let result = try runInsert(snippet: "Hi {{cursor}}!", into: "",
                                   select: NSRange(location: 0, length: 0))

        XCTAssertEqual(result.text, "Hi !")
        XCTAssertEqual(result.selection, NSRange(location: 3, length: 0))
    }

    func testCursorMarkerOffsetsFromInsertionPoint() throws {
        let result = try runInsert(snippet: "({{cursor}})", into: "ab",
                                   select: NSRange(location: 2, length: 0))

        XCTAssertEqual(result.text, "ab()")
        XCTAssertEqual(result.selection, NSRange(location: 3, length: 0))
    }

    func testWithoutMarkerCaretLandsAfterInsertion() throws {
        let result = try runInsert(snippet: "XYZ", into: "ab", select: NSRange(location: 0, length: 0))

        XCTAssertEqual(result.selection, NSRange(location: 3, length: 0))
    }

    func testCRLFSnippetIsNormalizedToLF() throws {
        let result = try runInsert(snippet: "one\r\ntwo", into: "", select: NSRange(location: 0, length: 0))

        XCTAssertEqual(result.text, "one\ntwo")
    }

    func testOneUndoRevertsInsertion() throws {
        try withTempFolder { folder in
            let snippetURL = folder.appendingPathComponent("Snippet.txt")
            try "inserted ".write(to: snippetURL, atomically: true, encoding: .utf8)

            let document = Document()
            document.makeWindowControllers()
            defer { document.close() }

            let editor = try XCTUnwrap(
                document.windowControllers.first?.contentViewController as? EditorViewController
            )
            editor.textView.string = "before after"
            editor.textView.setSelectedRange(NSRange(location: 7, length: 0))

            let item = NSMenuItem()
            item.representedObject = snippetURL
            editor.insertSnippet(item)
            XCTAssertEqual(editor.textView.string, "before inserted after")

            editor.textView.undoManager?.undo()

            XCTAssertEqual(editor.textView.string, "before after")
        }
    }
}

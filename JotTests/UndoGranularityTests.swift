//
//  UndoGranularityTests.swift
//  JotTests
//
//  Tests that insert-style commands stay out of the typing undo
//  coalescing (#241). NSTextView grows one "Typing" undo action across
//  events, and a bare programmatic insertText joins it — so in the
//  real app a single undo after a menu command also reverted the
//  typing before it. The fix brackets every command's edit with
//  breakUndoCoalescing.
//
//  These tests assert on NSTextView.isCoalescingUndo, not on undo()
//  round trips: NSUndoManager's per-event grouping is driven by the
//  application event cycle, which XCTest never runs — the whole test
//  shares one undo group, and emulating event boundaries with manual
//  begin/endUndoGrouping posts checkpoints that break the coalescing
//  by themselves, hiding exactly the bug under test. The coalescing
//  flag is the mechanism itself: after typing it must be running, and
//  after a command it must not be, or the command's edit has fused
//  with the typing's undo step. (Verified against the unfixed code:
//  every command left the flag true.)
//
//  Each shared choke point is covered once: the asterisk toggle
//  (bold/italic), the symmetric-marker toggle (strikethrough,
//  highlight, inline code), Link, the line commands (blockquote,
//  ordered/unordered list), snippet insertion, the checklist toggle,
//  and Tab/Backtab line indenting. Paste-as-markdown-link (#145)
//  shares the fix but isn't tested: driving it needs the real general
//  pasteboard, and tests must not clobber the user's clipboard.
//

import XCTest
@testable import Jot

@MainActor
final class UndoGranularityTests: XCTestCase {

    private func makeEditor() throws -> (document: Document, editor: EditorViewController) {
        let document = Document()
        document.makeWindowControllers()
        let editor = try XCTUnwrap(
            document.windowControllers.first?.contentViewController as? EditorViewController
        )
        return (document, editor)
    }

    /// Simulated typing: the same primitive keystrokes funnel into.
    private func type(_ text: String, in editor: EditorViewController) {
        let caret = editor.textView.selectedRange()
        editor.textView.insertText(text, replacementRange: caret)
    }

    // MARK: - Sanity

    func testTypingCoalesces() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        type("ab", in: editor)
        type("cd", in: editor)
        XCTAssertTrue(editor.textView.isCoalescingUndo,
                      "sanity: plain typing must coalesce, or every test here is meaningless")
    }

    // MARK: - Commands end the typing coalescing

    func testBoldEndsTypingCoalescing() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        type("zz", in: editor)
        editor.textView.setSelectedRange(NSRange(location: 0, length: 2))
        editor.toggleBoldMarkdown(self)

        XCTAssertEqual(editor.textView.string, "**zz**")
        XCTAssertFalse(editor.textView.isCoalescingUndo)
    }

    func testStrikethroughEndsTypingCoalescing() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        type("zz", in: editor)
        editor.textView.setSelectedRange(NSRange(location: 0, length: 2))
        editor.toggleStrikethroughMarkdown(self)

        XCTAssertEqual(editor.textView.string, "~~zz~~")
        XCTAssertFalse(editor.textView.isCoalescingUndo)
    }

    func testLinkEndsTypingCoalescing() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        type("zz", in: editor)
        editor.textView.setSelectedRange(NSRange(location: 0, length: 2))
        editor.insertLinkMarkdown(self)

        XCTAssertEqual(editor.textView.string, "[zz]()")
        XCTAssertFalse(editor.textView.isCoalescingUndo)
    }

    func testBlockquoteEndsTypingCoalescing() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        type("one", in: editor)
        editor.toggleBlockquote(self)

        XCTAssertEqual(editor.textView.string, "> one")
        XCTAssertFalse(editor.textView.isCoalescingUndo)
    }

    func testChecklistToggleEndsTypingCoalescing() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        type("task", in: editor)
        editor.toggleChecklistItem(self)

        XCTAssertEqual(editor.textView.string, "- [ ] task")
        XCTAssertFalse(editor.textView.isCoalescingUndo)
    }

    func testSnippetEndsTypingCoalescing() throws {
        let tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFolder) }
        let snippetURL = tempFolder.appendingPathComponent("Snippet.txt")
        try " snip".write(to: snippetURL, atomically: true, encoding: .utf8)

        let (document, editor) = try makeEditor()
        defer { document.close() }

        type("zz", in: editor)
        let item = NSMenuItem()
        item.representedObject = snippetURL
        editor.insertSnippet(item)

        XCTAssertEqual(editor.textView.string, "zz snip")
        XCTAssertFalse(editor.textView.isCoalescingUndo)
    }

    func testOutdentEndsTypingCoalescing() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        editor.textView.string = "\tone\n\ttwo"
        type("x", in: editor)
        XCTAssertTrue(editor.textView.isCoalescingUndo)

        editor.textView.setSelectedRange(NSRange(location: 0, length: 10))
        editor.textView.doCommand(by: #selector(NSResponder.insertBacktab(_:)))

        XCTAssertEqual(editor.textView.string, "one\ntwox")
        XCTAssertFalse(editor.textView.isCoalescingUndo)
    }

    // MARK: - Keystrokes stay in the typing stream

    // A bare Tab at the caret and Return's list continuation are
    // typing, not commands: they must keep coalescing, or every tab
    // and list line would fracture the typing undo stream.

    func testBareTabStaysInTypingStream() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        type("ab", in: editor)
        editor.textView.doCommand(by: #selector(NSResponder.insertTab(_:)))

        XCTAssertEqual(editor.textView.string, "ab\t")
        XCTAssertTrue(editor.textView.isCoalescingUndo)
    }

    func testListContinuationStaysInTypingStream() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        editor.applyInitialMode(.markdown)
        type("- one", in: editor)
        editor.textView.doCommand(by: #selector(NSResponder.insertNewline(_:)))

        XCTAssertEqual(editor.textView.string, "- one\n- ")
        XCTAssertTrue(editor.textView.isCoalescingUndo)
    }
}

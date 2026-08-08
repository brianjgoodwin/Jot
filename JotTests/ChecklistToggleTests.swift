//
//  ChecklistToggleTests.swift
//  JotTests
//
//  End-to-end tests for Format > Toggle Checklist (#146): flipping
//  existing checkboxes, and adding checkboxes when the selection has
//  none. Uses the same live document/editor harness as
//  EditorFormattingTests.
//

import XCTest
@testable import Jot

@MainActor
final class ChecklistToggleTests: XCTestCase {

	private struct ToggleResult {
		let text: String
		let selection: NSRange
	}

	// Each test builds its own document/editor pair: XCTest's setUp is
	// nonisolated under Swift 6, so stored main-actor fixtures fight the
	// compiler for no benefit
	private func runToggle(_ text: String, select: NSRange) throws -> ToggleResult {
		let document = Document()
		document.makeWindowControllers()
		defer { document.close() }

		let editor = try XCTUnwrap(
			document.windowControllers.first?.contentViewController as? EditorViewController
		)
		editor.textView.string = text
		editor.textView.setSelectedRange(select)
		editor.toggleChecklistItem(self)
		return ToggleResult(text: editor.textView.string, selection: editor.textView.selectedRange())
	}

	// MARK: - Flipping

	func testChecksSingleItem() throws {
		XCTAssertEqual(try runToggle("- [ ] task", select: NSRange(location: 8, length: 0)).text,
					   "- [x] task")
	}

	func testUnchecksSingleItem() throws {
		XCTAssertEqual(try runToggle("- [x] task", select: NSRange(location: 8, length: 0)).text,
					   "- [ ] task")
	}

	func testFlipsEverySelectedChecklistLineIndividually() throws {
		// Mixed states flip independently; when the selection has any
		// checkboxes, lines without one are left alone
		let result = try runToggle("- [ ] a\n- [x] b\nplain",
								   select: NSRange(location: 0, length: 21))
		XCTAssertEqual(result.text, "- [x] a\n- [ ] b\nplain")
	}

	func testFlipPreservesSelection() throws {
		let result = try runToggle("- [ ] a\n- [ ] b", select: NSRange(location: 0, length: 15))
		XCTAssertEqual(result.selection, NSRange(location: 0, length: 15))
	}

	// MARK: - Adding

	func testAddsCheckboxToPlainLine() throws {
		let result = try runToggle("note", select: NSRange(location: 4, length: 0))
		XCTAssertEqual(result.text, "- [ ] note")
		// Caret shifted past the inserted marker
		XCTAssertEqual(result.selection, NSRange(location: 10, length: 0))
	}

	func testAddsCheckboxAfterExistingBullet() throws {
		XCTAssertEqual(try runToggle("- item", select: NSRange(location: 3, length: 0)).text,
					   "- [ ] item")
	}

	func testKeepsIndentWhenAddingCheckbox() throws {
		XCTAssertEqual(try runToggle("\tnote", select: NSRange(location: 2, length: 0)).text,
					   "\t- [ ] note")
	}

	func testAddsCheckboxesToAllSelectedPlainLines() throws {
		let result = try runToggle("one\ntwo", select: NSRange(location: 0, length: 7))
		XCTAssertEqual(result.text, "- [ ] one\n- [ ] two")
		// Selection still spans from the first content to the end
		XCTAssertEqual(result.selection, NSRange(location: 6, length: 13))
	}

	func testEmptyDocumentStartsChecklist() throws {
		let result = try runToggle("", select: NSRange(location: 0, length: 0))
		XCTAssertEqual(result.text, "- [ ] ")
		XCTAssertEqual(result.selection, NSRange(location: 6, length: 0))
	}

	func testEmptyLastLineStartsChecklistItem() throws {
		let result = try runToggle("note\n", select: NSRange(location: 5, length: 0))
		XCTAssertEqual(result.text, "note\n- [ ] ")
	}

	func testNumberedLinesAreLeftAlone() throws {
		// "1. [ ]" is not a checklist Jot styles or continues, so the
		// command must not manufacture one
		let result = try runToggle("1. a\n2. b", select: NSRange(location: 0, length: 9))
		XCTAssertEqual(result.text, "1. a\n2. b")
	}

	// MARK: - Undo

	func testOneUndoRevertsMultiLineFlip() throws {
		let document = Document()
		document.makeWindowControllers()
		defer { document.close() }

		let editor = try XCTUnwrap(
			document.windowControllers.first?.contentViewController as? EditorViewController
		)
		editor.textView.string = "- [ ] a\n- [ ] b"
		editor.textView.setSelectedRange(NSRange(location: 0, length: 15))
		editor.toggleChecklistItem(self)
		XCTAssertEqual(editor.textView.string, "- [x] a\n- [x] b")

		editor.textView.undoManager?.undo()
		XCTAssertEqual(editor.textView.string, "- [ ] a\n- [ ] b")
	}
}

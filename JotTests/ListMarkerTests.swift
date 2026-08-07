//
//  ListMarkerTests.swift
//  JotTests
//
//  Tests for ListMarker parsing and the Return-key list continuation (#143).
//

import XCTest
@testable import Jot

final class ListMarkerTests: XCTestCase {

	// MARK: - Parsing

	func testParsesBulletMarkers() {
		for bullet in ["-", "*", "+"] {
			let marker = ListMarker(line: "\(bullet) item")
			XCTAssertNotNil(marker, "\(bullet) should parse")
			XCTAssertEqual(marker?.indent, "")
			XCTAssertEqual(marker?.text, "\(bullet) ")
			XCTAssertNil(marker?.number)
			XCTAssertEqual(marker?.isCheckbox, false)
		}
	}

	func testParsesOrderedMarker() {
		let marker = ListMarker(line: "3. item")
		XCTAssertEqual(marker?.text, "3. ")
		XCTAssertEqual(marker?.number, 3)
		XCTAssertEqual(marker?.isCheckbox, false)
	}

	func testParsesIndentedMarker() {
		let marker = ListMarker(line: "\t- nested")
		XCTAssertEqual(marker?.indent, "\t")
		XCTAssertEqual(marker?.text, "- ")
		XCTAssertEqual(marker?.prefixLength, 3)
	}

	func testParsesUncheckedCheckbox() {
		let marker = ListMarker(line: "- [ ] task")
		XCTAssertEqual(marker?.text, "- [ ] ")
		XCTAssertEqual(marker?.isCheckbox, true)
		XCTAssertEqual(marker?.checkboxStateOffset, 3)
	}

	func testParsesCheckedCheckbox() {
		let marker = ListMarker(line: "  - [x] done")
		XCTAssertEqual(marker?.indent, "  ")
		XCTAssertEqual(marker?.text, "- [x] ")
		XCTAssertEqual(marker?.isCheckbox, true)
		// Offset is from the line start: 2 indent + "- [" = 5
		XCTAssertEqual(marker?.checkboxStateOffset, 5)
	}

	func testCheckboxRequiresBullet() {
		// "1. [ ]" is not GitHub checkbox syntax Jot recognizes; the bracket
		// text is ordinary content.
		let marker = ListMarker(line: "1. [ ] task")
		XCTAssertEqual(marker?.number, 1)
		XCTAssertEqual(marker?.isCheckbox, false)
	}

	func testNonListLinesDoNotParse() {
		for line in ["text", "-no space", "1.no space", "", "  ", "--", "1) item"] {
			XCTAssertNil(ListMarker(line: line), "\"\(line)\" should not parse as a list marker")
		}
	}

	func testCheckboxWithoutTrailingSpaceFallsBackToBullet() {
		// "- [ ]x" has no space after the brackets, so the brackets are
		// content, not a checkbox.
		let marker = ListMarker(line: "- [ ]x")
		XCTAssertEqual(marker?.text, "- ")
		XCTAssertEqual(marker?.isCheckbox, false)
	}

	// MARK: - Continuation prefixes

	func testBulletContinuationKeepsMarker() {
		XCTAssertEqual(ListMarker(line: "* item")?.continuationPrefix, "* ")
		XCTAssertEqual(ListMarker(line: "\t- item")?.continuationPrefix, "\t- ")
	}

	func testOrderedContinuationIncrements() {
		XCTAssertEqual(ListMarker(line: "1. item")?.continuationPrefix, "2. ")
		XCTAssertEqual(ListMarker(line: "  9. item")?.continuationPrefix, "  10. ")
	}

	func testCheckboxContinuationResetsToUnchecked() {
		XCTAssertEqual(ListMarker(line: "- [x] done")?.continuationPrefix, "- [ ] ")
		XCTAssertEqual(ListMarker(line: "- [ ] open")?.continuationPrefix, "- [ ] ")
	}

	// MARK: - Return action

	private func caretAtEnd(of text: String) -> Int {
		return (text as NSString).length
	}

	func testReturnContinuesBulletList() {
		let text = "- item"
		let action = ListMarker.returnAction(in: text, caret: caretAtEnd(of: text))
		XCTAssertEqual(action, .continueList(insert: "\n- "))
	}

	func testReturnContinuesOrderedList() {
		let text = "1. first"
		let action = ListMarker.returnAction(in: text, caret: caretAtEnd(of: text))
		XCTAssertEqual(action, .continueList(insert: "\n2. "))
	}

	func testReturnContinuesChecklistUnchecked() {
		let text = "- [x] done"
		let action = ListMarker.returnAction(in: text, caret: caretAtEnd(of: text))
		XCTAssertEqual(action, .continueList(insert: "\n- [ ] "))
	}

	func testReturnMidContentStillContinues() {
		// Caret between "it" and "em": splitting a list item continues the
		// list, matching Bear/Obsidian behavior.
		let action = ListMarker.returnAction(in: "- item", caret: 4)
		XCTAssertEqual(action, .continueList(insert: "\n- "))
	}

	func testReturnOnEmptyItemEndsList() {
		let text = "- first\n- "
		let action = ListMarker.returnAction(in: text, caret: caretAtEnd(of: text))
		XCTAssertEqual(action, .endList(remove: NSRange(location: 8, length: 2)))
	}

	func testReturnOnEmptyCheckboxEndsList() {
		let text = "- [ ] "
		let action = ListMarker.returnAction(in: text, caret: caretAtEnd(of: text))
		XCTAssertEqual(action, .endList(remove: NSRange(location: 0, length: 6)))
	}

	func testReturnBeforeMarkerDoesNothing() {
		// Caret at the line start: Return should push the item down, not
		// spawn a marker.
		XCTAssertEqual(ListMarker.returnAction(in: "- item", caret: 0), .none)
		// Caret inside the marker itself.
		XCTAssertEqual(ListMarker.returnAction(in: "- item", caret: 1), .none)
	}

	func testReturnOnPlainLineDoesNothing() {
		let text = "just prose"
		XCTAssertEqual(ListMarker.returnAction(in: text, caret: caretAtEnd(of: text)), .none)
	}

	func testReturnOnMiddleLineOfListUsesThatLine() {
		// Caret at the end of the *first* line; the second line must not
		// influence the action.
		let text = "1. first\n2. second"
		let action = ListMarker.returnAction(in: text, caret: 8)
		XCTAssertEqual(action, .continueList(insert: "\n2. "))
	}
}

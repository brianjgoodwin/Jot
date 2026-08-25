//
//  BlockFormatTests.swift
//  JotTests
//
//  Tests for the pure line transforms behind Format > Blockquote and
//  the list commands (#96).
//

import XCTest
@testable import Jot

final class BlockFormatTests: XCTestCase {

    // MARK: - Blockquote

    func testBlockquoteAddsPrefixToPlainLines() {
        XCTAssertEqual(BlockFormat.toggleBlockquote(["one", "two"]),
                       ["> one", "> two"])
    }

    func testBlockquoteRemovesPrefixWhenAllLinesQuoted() {
        XCTAssertEqual(BlockFormat.toggleBlockquote(["> one", "> two"]),
                       ["one", "two"])
    }

    func testBlockquoteRemovesBarePrefixWithoutSpace() {
        XCTAssertEqual(BlockFormat.toggleBlockquote([">one", ">"]),
                       ["one", ""])
    }

    func testBlockquoteMixedSelectionQuotesEverything() {
        XCTAssertEqual(BlockFormat.toggleBlockquote(["> one", "two"]),
                       ["> > one", "> two"])
    }

    func testBlockquoteBlankLineGetsBareMarkerSoTheQuoteStaysContiguous() {
        XCTAssertEqual(BlockFormat.toggleBlockquote(["one", "", "two"]),
                       ["> one", ">", "> two"])
    }

    func testBlockquoteRoundTripsThroughBlankLines() {
        let quoted = BlockFormat.toggleBlockquote(["one", "", "two"])
        XCTAssertEqual(BlockFormat.toggleBlockquote(quoted), ["one", "", "two"])
    }

    // MARK: - Ordered list

    func testOrderedListNumbersPlainLines() {
        XCTAssertEqual(BlockFormat.toggleOrderedList(["a", "b", "c"]),
                       ["1. a", "2. b", "3. c"])
    }

    func testOrderedListSkipsBlankLinesWithoutConsumingNumbers() {
        XCTAssertEqual(BlockFormat.toggleOrderedList(["a", "", "b"]),
                       ["1. a", "", "2. b"])
    }

    func testOrderedListConvertsBulletsKeepingIndent() {
        XCTAssertEqual(BlockFormat.toggleOrderedList(["- a", "  - b"]),
                       ["1. a", "  2. b"])
    }

    func testOrderedListConvertsChecklistDroppingCheckbox() {
        XCTAssertEqual(BlockFormat.toggleOrderedList(["- [ ] task"]),
                       ["1. task"])
    }

    func testOrderedListRemovesMarkersWhenAllLinesNumbered() {
        XCTAssertEqual(BlockFormat.toggleOrderedList(["1. a", "2. b"]),
                       ["a", "b"])
    }

    func testOrderedListRenumbersMixedSelection() {
        XCTAssertEqual(BlockFormat.toggleOrderedList(["1. a", "plain"]),
                       ["1. a", "2. plain"])
    }

    // MARK: - Unordered list

    func testUnorderedListBulletsPlainLines() {
        XCTAssertEqual(BlockFormat.toggleUnorderedList(["a", "b"]),
                       ["- a", "- b"])
    }

    func testUnorderedListRemovesBulletsWhenAllLinesBulleted() {
        XCTAssertEqual(BlockFormat.toggleUnorderedList(["- a", "* b"]),
                       ["a", "b"])
    }

    func testUnorderedListConvertsNumbersKeepingIndent() {
        XCTAssertEqual(BlockFormat.toggleUnorderedList(["1. a", "  2. b"]),
                       ["- a", "  - b"])
    }

    func testUnorderedListDemotesChecklistToPlainBullets() {
        XCTAssertEqual(BlockFormat.toggleUnorderedList(["- [ ] task", "- [x] done"]),
                       ["- task", "- done"])
    }

    func testUnorderedListLeavesBlankLinesAlone() {
        XCTAssertEqual(BlockFormat.toggleUnorderedList(["a", "", "b"]),
                       ["- a", "", "- b"])
    }

    // MARK: - Degenerate input

    // Blockquote on an empty line starts a quote (the caret is where
    // the user wants to write); the list commands have nothing to
    // number or bullet, so they do nothing.
    func testBlankOnlySelection() {
        XCTAssertEqual(BlockFormat.toggleBlockquote([""]), [">"])
        XCTAssertEqual(BlockFormat.toggleOrderedList([""]), [""])
        XCTAssertEqual(BlockFormat.toggleUnorderedList([""]), [""])
    }
}

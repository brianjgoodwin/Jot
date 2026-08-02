//
//  TextStatisticsTests.swift
//  JotTests
//
//  Tests for the TextStatistics struct.
//

import XCTest
@testable import Jot

final class TextStatisticsTests: XCTestCase {

    // MARK: - Word count

    func testWordCountSimple() {
        let stats = TextStatistics(text: "one two three")
        XCTAssertEqual(stats.wordCount, 3)
    }

    func testWordCountEmpty() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.wordCount, 0)
    }

    func testWordCountWhitespaceOnly() {
        let stats = TextStatistics(text: "   \n\n\t  ")
        XCTAssertEqual(stats.wordCount, 0)
    }

    func testWordCountExtraSpaces() {
        let stats = TextStatistics(text: "  one   two   three  ")
        XCTAssertEqual(stats.wordCount, 3)
    }

    func testWordCountWithNewlines() {
        let stats = TextStatistics(text: "one\ntwo\nthree")
        XCTAssertEqual(stats.wordCount, 3)
    }

    // MARK: - Line count

    func testLineCountSimple() {
        let stats = TextStatistics(text: "First line\n\nSecond line")
        XCTAssertEqual(stats.lineCount, 2)
    }

    func testLineCountEmpty() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.lineCount, 0)
    }

    func testLineCountSingleLine() {
        let stats = TextStatistics(text: "Just one line")
        XCTAssertEqual(stats.lineCount, 1)
    }

    func testLineCountTrailingNewline() {
        let stats = TextStatistics(text: "Line one\nLine two\n")
        XCTAssertEqual(stats.lineCount, 2)
    }

    // MARK: - File size

    func testFileSizeEmpty() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.fileSizeString, "Zero bytes")
    }

    func testFileSizeNonEmpty() {
        let stats = TextStatistics(text: "Hello")
        // "Hello" is 5 bytes in UTF-8
        XCTAssertTrue(stats.fileSizeString.contains("5"))
    }
}

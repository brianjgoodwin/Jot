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

    func testWordCountWithTabs() {
        let stats = TextStatistics(text: "one\ttwo\tthree")
        XCTAssertEqual(stats.wordCount, 3)
    }

    func testWordCountPunctuationTokens() {
        let stats = TextStatistics(text: "hello, world! -- yes")
        XCTAssertEqual(stats.wordCount, 4)
    }

    func testWordCountSingleWord() {
        let stats = TextStatistics(text: "hello")
        XCTAssertEqual(stats.wordCount, 1)
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

    func testLineCountCRLF() {
        let stats = TextStatistics(text: "Line one\r\nLine two\r\nLine three")
        XCTAssertEqual(stats.lineCount, 3)
    }

    func testLineCountBlankLines() {
        let stats = TextStatistics(text: "first\n\n\nfourth")
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

    func testFileSizeUnicode() {
        let stats = TextStatistics(text: "\u{1F600}")
        // Emoji is 4 bytes in UTF-8
        XCTAssertTrue(stats.fileSizeString.contains("4"))
    }
}

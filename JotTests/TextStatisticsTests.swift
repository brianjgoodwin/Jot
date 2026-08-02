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

    // MARK: - Character count

    func testCharacterCountSimple() {
        let stats = TextStatistics(text: "Hello")
        XCTAssertEqual(stats.characterCount, 5)
    }

    func testCharacterCountEmpty() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.characterCount, 0)
    }

    func testCharacterCountIncludesSpaces() {
        let stats = TextStatistics(text: "one two three")
        XCTAssertEqual(stats.characterCount, 13)
    }

    func testCharacterCountNoSpacesSimple() {
        let stats = TextStatistics(text: "one two three")
        XCTAssertEqual(stats.characterCountNoSpaces, 11)
    }

    func testCharacterCountNoSpacesEmpty() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.characterCountNoSpaces, 0)
    }

    func testCharacterCountNoSpacesExcludesNewlines() {
        let stats = TextStatistics(text: "one\ntwo")
        XCTAssertEqual(stats.characterCountNoSpaces, 6)
    }

    func testCharacterCountNoSpacesExcludesTabs() {
        let stats = TextStatistics(text: "one\ttwo")
        XCTAssertEqual(stats.characterCountNoSpaces, 6)
    }

    // MARK: - Paragraph count

    func testParagraphCountEmpty() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.paragraphCount, 0)
    }

    func testParagraphCountSingle() {
        let stats = TextStatistics(text: "Just one paragraph.")
        XCTAssertEqual(stats.paragraphCount, 1)
    }

    func testParagraphCountMultiple() {
        let stats = TextStatistics(text: "First paragraph.\n\nSecond paragraph.")
        XCTAssertEqual(stats.paragraphCount, 2)
    }

    func testParagraphCountSingleNewlineIsNotParagraphBreak() {
        let stats = TextStatistics(text: "Line one\nLine two")
        XCTAssertEqual(stats.paragraphCount, 1)
    }

    func testParagraphCountTripleNewline() {
        let stats = TextStatistics(text: "First\n\n\nSecond")
        XCTAssertEqual(stats.paragraphCount, 2)
    }

    func testParagraphCountQuadNewline() {
        let stats = TextStatistics(text: "A\n\n\n\nB")
        XCTAssertEqual(stats.paragraphCount, 2)
    }

    func testParagraphCountWhitespaceOnly() {
        let stats = TextStatistics(text: "   \n\n\t  ")
        XCTAssertEqual(stats.paragraphCount, 0)
    }

    // MARK: - Reading time

    func testReadingTimeEmpty() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.readingTimeSeconds, 0)
        XCTAssertEqual(stats.readingTimeString, "0 min")
    }

    func testReadingTimeSingleWord() {
        let stats = TextStatistics(text: "hello")
        XCTAssertEqual(stats.readingTimeSeconds, 1)
        XCTAssertEqual(stats.readingTimeString, "< 1 min")
    }

    func testReadingTime250Words() {
        let words = Array(repeating: "word", count: 250).joined(separator: " ")
        let stats = TextStatistics(text: words)
        XCTAssertEqual(stats.readingTimeSeconds, 60)
        XCTAssertEqual(stats.readingTimeString, "1 min")
    }

    func testReadingTime500Words() {
        let words = Array(repeating: "word", count: 500).joined(separator: " ")
        let stats = TextStatistics(text: words)
        XCTAssertEqual(stats.readingTimeSeconds, 120)
        XCTAssertEqual(stats.readingTimeString, "2 min")
    }

    // MARK: - File size

    func testFileSizeEmpty() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.fileSizeString, "Zero bytes")
    }

    func testFileSizeNonEmpty() {
        let stats = TextStatistics(text: "Hello")
        // "Hello" is 5 bytes in UTF-8
        XCTAssertEqual(stats.fileSizeString, "5 bytes")
    }

    func testFileSizeUnicode() {
        let stats = TextStatistics(text: "\u{1F600}")
        // Emoji is 4 bytes in UTF-8
        XCTAssertEqual(stats.fileSizeString, "4 bytes")
    }
}

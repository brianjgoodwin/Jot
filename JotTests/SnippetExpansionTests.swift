//
//  SnippetExpansionTests.swift
//  JotTests
//
//  Tests for snippet variable expansion (#162): {{date}}, {{time}},
//  and the {{cursor}} marker.
//

import XCTest
@testable import Jot

final class SnippetExpansionTests: XCTestCase {

    // Noon UTC, 2026-08-17 — a fixed instant so formatted output is stable
    private let fixedDate = Date(timeIntervalSince1970: 1_786_968_000)
    private let locale = Locale(identifier: "en_US")
    private let timeZone = TimeZone(identifier: "UTC")!

    private func expand(_ text: String) -> (text: String, cursorOffsetUTF16: Int?) {
        SnippetExpansion.expand(text, date: fixedDate, locale: locale, timeZone: timeZone)
    }

    // MARK: - Variables

    func testDateSubstitution() {
        XCTAssertEqual(expand("Due: {{date}}").text, "Due: Aug 17, 2026")
    }

    func testTimeSubstitution() {
        // Expected value comes from an identically-configured formatter
        // rather than a literal: newer ICU separates time and AM/PM with
        // a narrow no-break space, and local vs CI Xcode versions differ
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = locale
        formatter.timeZone = timeZone

        XCTAssertEqual(expand("At {{time}}").text, "At \(formatter.string(from: fixedDate))")
    }

    func testAllOccurrencesOfAVariableAreReplaced() {
        XCTAssertEqual(expand("{{date}} and {{date}}").text, "Aug 17, 2026 and Aug 17, 2026")
    }

    func testUnknownVariableLeftLiteral() {
        let result = expand("Hello {{name}}")

        XCTAssertEqual(result.text, "Hello {{name}}")
        XCTAssertNil(result.cursorOffsetUTF16)
    }

    // MARK: - Cursor marker

    func testNoCursorReturnsNilOffset() {
        XCTAssertNil(expand("plain text").cursorOffsetUTF16)
    }

    func testCursorStrippedAndOffsetComputed() {
        let result = expand("ab{{cursor}}cd")

        XCTAssertEqual(result.text, "abcd")
        XCTAssertEqual(result.cursorOffsetUTF16, 2)
    }

    func testCursorAtStart() {
        let result = expand("{{cursor}}text")

        XCTAssertEqual(result.text, "text")
        XCTAssertEqual(result.cursorOffsetUTF16, 0)
    }

    func testCursorAtEnd() {
        let result = expand("text{{cursor}}")

        XCTAssertEqual(result.text, "text")
        XCTAssertEqual(result.cursorOffsetUTF16, 4)
    }

    func testOnlyFirstCursorStripped() {
        let result = expand("a{{cursor}}b{{cursor}}c")

        XCTAssertEqual(result.text, "ab{{cursor}}c")
        XCTAssertEqual(result.cursorOffsetUTF16, 1)
    }

    func testCursorOffsetIsUTF16WithMultibyteTextBeforeMarker() {
        // The thumbs-up emoji is one Character but two UTF-16 units;
        // the offset feeds an NSRange, so it must count the latter
        let result = expand("\u{1F44D}{{cursor}}x")

        XCTAssertEqual(result.text, "\u{1F44D}x")
        XCTAssertEqual(result.cursorOffsetUTF16, 2)
    }

    func testCursorOffsetAccountsForExpandedVariableBeforeIt() {
        let result = expand("{{date}} {{cursor}}end")

        XCTAssertEqual(result.text, "Aug 17, 2026 end")
        XCTAssertEqual(result.cursorOffsetUTF16, ("Aug 17, 2026 " as NSString).length)
    }
}

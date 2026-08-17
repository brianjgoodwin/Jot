//
//  LineEndingTests.swift
//  JotTests
//
//  Detection, normalization, and restoration of file line-ending
//  conventions (#194, #195).
//

import XCTest
@testable import Jot

final class LineEndingTests: XCTestCase {

    func testDetectsFirstConvention() {
        XCTAssertEqual(LineEnding.detect(in: "a\nb"), .lf)
        XCTAssertEqual(LineEnding.detect(in: "a\r\nb"), .crlf)
        XCTAssertEqual(LineEnding.detect(in: "a\rb"), .cr)
        XCTAssertNil(LineEnding.detect(in: "no breaks"))
        XCTAssertNil(LineEnding.detect(in: ""))
    }

    func testMixedEndingsFirstOccurrenceWins() {
        XCTAssertEqual(LineEnding.detect(in: "a\r\nb\nc\rd"), .crlf)
        XCTAssertEqual(LineEnding.detect(in: "a\nb\r\nc"), .lf)
    }

    func testUnicodeSeparatorsAreIgnored() {
        // U+2028 line separator is not a file convention (#194)
        XCTAssertEqual(LineEnding.detect(in: "a\u{2028}b\nc"), .lf)
        XCTAssertNil(LineEnding.detect(in: "a\u{2028}b"))
    }

    func testNormalizeToLF() {
        XCTAssertEqual(LineEnding.normalizeToLF("a\r\nb\rc\nd"), "a\nb\nc\nd")
    }

    func testRestoreConvention() {
        XCTAssertEqual(LineEnding.crlf.restore(in: "a\nb\nc"), "a\r\nb\r\nc")
        XCTAssertEqual(LineEnding.cr.restore(in: "a\nb"), "a\rb")
        XCTAssertEqual(LineEnding.lf.restore(in: "a\nb"), "a\nb")
    }

    func testNormalizeThenRestoreRoundTrips() {
        let original = "one\r\ntwo\r\nthree\r\n"
        let normalized = LineEnding.normalizeToLF(original)
        XCTAssertEqual(LineEnding.crlf.restore(in: normalized), original)
    }
}

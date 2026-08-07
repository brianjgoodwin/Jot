//
//  PerformanceTests.swift
//  JotTests
//
//  Measurement harness for the hot paths (#142): text statistics and
//  markdown styling over generated fixtures at three sizes.
//
//  These tests record metrics; they only fail against a baseline, and
//  baselines are per-machine (set them in Xcode's Report navigator after a
//  run — see docs/PERFORMANCE.md). In CI they just record, never fail.
//

import XCTest
@testable import Jot

@MainActor
final class PerformanceTests: XCTestCase {

    // MARK: - Fixtures (deterministic, generated per test)

    static let tenKB = 10 * 1024
    static let hundredKB = 100 * 1024
    static let oneMB = 1024 * 1024

    /// Plain prose: repeated lorem paragraphs up to roughly `bytes`.
    static func plainFixture(_ bytes: Int) -> String {
        let paragraph = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do \
        eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim \
        ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut \
        aliquip ex ea commodo consequat.


        """
        return String(repeating: paragraph, count: max(1, bytes / paragraph.utf8.count))
    }

    /// Markdown with realistic syntax density: headings, emphasis, lists,
    /// links, a table, a code fence, and a blockquote in every block.
    static func markdownFixture(_ bytes: Int) -> String {
        let block = """
        ## Section heading

        Lorem **ipsum** dolor *sit amet*, consectetur ***adipiscing*** elit.
        Sed do `eiusmod tempor` incididunt ut [labore](https://example.com)
        et dolore ~~magna~~ aliqua.

        - Ut enim ad minim veniam
        - Quis nostrud *exercitation* ullamco
        - Laboris nisi ut **aliquip**

        | Column | Value |
        |--------|-------|
        | lorem  | ipsum |
        | dolor  | sit   |

        ```swift
        let amet = "consectetur"
        ```

        > Duis aute irure dolor in reprehenderit in voluptate velit.


        """
        return String(repeating: block, count: max(1, bytes / block.utf8.count))
    }

    /// An offscreen text view with a full text system, loaded with `text`.
    private func makeTextView(text: String) -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        textView.string = text
        return textView
    }

    private let fixedFont = NSFont.systemFont(ofSize: 13)

    // MARK: - TextStatistics (#138)

    func testStatistics10KB() {
        let text = Self.plainFixture(Self.tenKB)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = TextStatistics(text: text)
        }
    }

    func testStatistics100KB() {
        let text = Self.plainFixture(Self.hundredKB)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = TextStatistics(text: text)
        }
    }

    func testStatistics1MB() {
        let text = Self.plainFixture(Self.oneMB)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = TextStatistics(text: text)
        }
    }

    // The word-count label path: one number, not seven statistics
    func testWordCountOnly1MB() {
        let text = Self.plainFixture(Self.oneMB)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = TextStatistics.wordCount(of: text)
        }
    }

    // MARK: - Full markdown styling pass (#141, #139)

    // No 1 MB full-pass test: markdown mode's usable envelope is a few
    // hundred KB today, and five measured iterations of a 1 MB pass would
    // dominate the suite's runtime for no extra signal.

    func testMarkdownFullPass10KB() {
        let textView = makeTextView(text: Self.markdownFixture(Self.tenKB))
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            MarkdownProcessor.applyMarkdownStyling(to: textView, using: fixedFont)
        }
    }

    func testMarkdownFullPass100KB() {
        let textView = makeTextView(text: Self.markdownFixture(Self.hundredKB))
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            MarkdownProcessor.applyMarkdownStyling(to: textView, using: fixedFont)
        }
    }

    // MARK: - Per-keystroke pass (#123)

    // Typing in markdown mode styles only the current line, but the pass
    // still does full-document work (background strip, code-fence scans).
    // This is the number #123 exists to shrink: it should track the line
    // length, not the document length. A mid-document line, so the range
    // holds real markdown content — the fixture's last line is blank,
    // which would understate the per-line cost.
    func testMarkdownCurrentLinePassOn1MBDocument() {
        let text = Self.markdownFixture(Self.oneMB)
        let textView = makeTextView(text: text)
        let midLineRange = (text as NSString).lineRange(
            for: NSRange(location: (text as NSString).length / 2, length: 0))
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            MarkdownProcessor.applyMarkdownStyling(to: textView, using: fixedFont, range: midLineRange)
        }
    }

    // MARK: - Fixture sanity

    // If a fixture generator drifts (size collapses, syntax stripped), the
    // measurements silently stop meaning anything. Pin the basics.
    func testFixturesAreRoughlyTheRequestedSize() {
        for size in [Self.tenKB, Self.hundredKB, Self.oneMB] {
            let plain = Self.plainFixture(size).utf8.count
            let markdown = Self.markdownFixture(size).utf8.count
            XCTAssertGreaterThan(plain, size / 2)
            XCTAssertLessThan(plain, size * 2)
            XCTAssertGreaterThan(markdown, size / 2)
            XCTAssertLessThan(markdown, size * 2)
        }
    }

    func testMarkdownFixtureExercisesTheStyler() {
        let fixture = Self.markdownFixture(Self.tenKB)
        for token in ["## ", "**", "`", "](", "|---", "```", "> ", "- ", "~~"] {
            XCTAssertTrue(fixture.contains(token), "fixture lost its \(token) syntax")
        }
    }
}

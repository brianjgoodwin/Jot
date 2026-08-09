//
//  LineNumberGutterTests.swift
//  JotTests
//
//  Tests for the line number gutter (#42): the LineIndex line-start cache
//  (#103), the wrapped-line and trailing-line cases the first gutter
//  branch got wrong (#102, #105), the width digit boundaries, and the
//  showLineNumbers preference (#106, #108).
//

import XCTest
@testable import Jot

@MainActor
final class LineNumberGutterTests: XCTestCase {

    // MARK: - LineIndex: building

    func testEmptyStringIsOneLine() {
        let index = LineIndex(string: "")
        XCTAssertEqual(index.lineStarts, [0])
        XCTAssertEqual(index.lineCount, 1)
    }

    func testSingleLineWithoutTerminator() {
        let index = LineIndex(string: "hello")
        XCTAssertEqual(index.lineStarts, [0])
        XCTAssertEqual(index.lineCount, 1)
    }

    func testTrailingNewlineAddsTheEmptyLastLine() {
        // The caret can sit after the final newline; that position is a
        // line and gets a number (#105)
        let index = LineIndex(string: "hello\n")
        XCTAssertEqual(index.lineStarts, [0, 6])
        XCTAssertEqual(index.lineCount, 2)
    }

    func testMultipleLines() {
        let index = LineIndex(string: "a\nbb\nccc")
        XCTAssertEqual(index.lineStarts, [0, 2, 5])
        XCTAssertEqual(index.lineCount, 3)
    }

    func testCRLFCountsAsOneTerminator() {
        // CRLF is supported input (see DocumentTests); the pair is one
        // line break, not two
        let index = LineIndex(string: "a\r\nb")
        XCTAssertEqual(index.lineStarts, [0, 3])
        XCTAssertEqual(index.lineCount, 2)
    }

    func testLoneCarriageReturnIsATerminator() {
        let index = LineIndex(string: "a\rb")
        XCTAssertEqual(index.lineStarts, [0, 2])
        XCTAssertEqual(index.lineCount, 2)
    }

    func testUnicodeLineSeparatorIsATerminator() {
        let index = LineIndex(string: "a\u{2028}b")
        XCTAssertEqual(index.lineStarts, [0, 2])
        XCTAssertEqual(index.lineCount, 2)
    }

    // MARK: - LineIndex: lookups

    func testLineNumberForCharacter() {
        let index = LineIndex(string: "a\nbb\nccc")
        XCTAssertEqual(index.lineNumber(forCharacterAt: 0), 1)
        XCTAssertEqual(index.lineNumber(forCharacterAt: 1), 1)
        XCTAssertEqual(index.lineNumber(forCharacterAt: 2), 2)
        XCTAssertEqual(index.lineNumber(forCharacterAt: 4), 2)
        XCTAssertEqual(index.lineNumber(forCharacterAt: 5), 3)
        XCTAssertEqual(index.lineNumber(forCharacterAt: 8), 3)
    }

    func testCaretAfterTrailingNewlineIsOnTheLastLine() {
        let index = LineIndex(string: "a\n")
        XCTAssertEqual(index.lineNumber(forCharacterAt: 2), 2)
    }

    func testIsLineStart() {
        let index = LineIndex(string: "a\nbb\nccc")
        XCTAssertTrue(index.isLineStart(0))
        XCTAssertFalse(index.isLineStart(1))
        XCTAssertTrue(index.isLineStart(2))
        XCTAssertFalse(index.isLineStart(3))
        XCTAssertTrue(index.isLineStart(5))
        XCTAssertFalse(index.isLineStart(8))
    }

    // MARK: - LineIndex: incremental updates

    /// Applies one edit to both a working string and an incrementally
    /// updated index, then asserts the incremental result matches a fresh
    /// rebuild — the ground truth the incremental path must never drift
    /// from.
    private func applyAndCheck(_ edit: (range: NSRange, replacement: String),
                               to text: NSMutableString,
                               index: inout LineIndex,
                               line: UInt = #line) {
        let delta = (edit.replacement as NSString).length - edit.range.length
        text.replaceCharacters(in: edit.range, with: edit.replacement)
        index.applyEdit(in: text,
                        editedRange: NSRange(location: edit.range.location,
                                             length: (edit.replacement as NSString).length),
                        changeInLength: delta)
        XCTAssertEqual(index.lineStarts, LineIndex(string: text).lineStarts,
                       "incremental index diverged after editing to: \(text)", line: line)
    }

    func testIncrementalEditsMatchFullRebuild() {
        let text = NSMutableString(string: "")
        var index = LineIndex(string: text)

        // Type into an empty document
        applyAndCheck((NSRange(location: 0, length: 0), "hello"), to: text, index: &index)
        // Newline at the end
        applyAndCheck((NSRange(location: 5, length: 0), "\n"), to: text, index: &index)
        // Type on the trailing empty line
        applyAndCheck((NSRange(location: 6, length: 0), "world"), to: text, index: &index)
        // Multi-line paste in the middle
        applyAndCheck((NSRange(location: 2, length: 0), "x\ny\nz"), to: text, index: &index)
        // Delete a range spanning several lines
        applyAndCheck((NSRange(location: 1, length: 8), ""), to: text, index: &index)
        // Replace everything
        applyAndCheck((NSRange(location: 0, length: text.length), "one\ntwo\nthree\n"), to: text, index: &index)
        // Delete the final trailing newline
        applyAndCheck((NSRange(location: text.length - 1, length: 1), ""), to: text, index: &index)
        // Delete all
        applyAndCheck((NSRange(location: 0, length: text.length), ""), to: text, index: &index)
    }

    func testIncrementalEditsAroundCRLFBoundaries() {
        // The dangerous cases: an edit that splits or forms a CRLF pair
        // moves a line start without touching the surrounding lines
        let text = NSMutableString(string: "aa\r\nbb")
        var index = LineIndex(string: text)

        // Split the pair: delete the \n, leaving a lone \r terminator
        applyAndCheck((NSRange(location: 3, length: 1), ""), to: text, index: &index)
        // Re-form the pair: insert \n after the \r
        applyAndCheck((NSRange(location: 3, length: 0), "\n"), to: text, index: &index)
        // Insert a \r immediately before an existing \n, forming a pair
        // out of two previously separate characters
        applyAndCheck((NSRange(location: 0, length: text.length), "aa\nbb"), to: text, index: &index)
        applyAndCheck((NSRange(location: 2, length: 0), "\r"), to: text, index: &index)
        // Break that pair by typing between \r and \n
        applyAndCheck((NSRange(location: 3, length: 0), "x"), to: text, index: &index)
    }

    func testIncrementalEditAtTheVeryEnd() {
        let text = NSMutableString(string: "a\nb")
        var index = LineIndex(string: text)
        applyAndCheck((NSRange(location: 3, length: 0), "\n"), to: text, index: &index)
        applyAndCheck((NSRange(location: 4, length: 0), "c"), to: text, index: &index)
    }

    // MARK: - Gutter width

    func testThicknessGrowsAtDigitBoundaries() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let twoDigits = LineNumberGutterView.requiredThickness(forLineCount: 99, font: font)
        let threeDigits = LineNumberGutterView.requiredThickness(forLineCount: 100, font: font)
        let fourDigits = LineNumberGutterView.requiredThickness(forLineCount: 1000, font: font)
        XCTAssertLessThanOrEqual(twoDigits, threeDigits)
        XCTAssertLessThan(threeDigits, fourDigits)
    }

    func testThicknessHasAFloor() {
        // A one-line document still gets a usable gutter, and 9 → 10
        // stays inside the two-digit reservation instead of jittering
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let one = LineNumberGutterView.requiredThickness(forLineCount: 1, font: font)
        let nine = LineNumberGutterView.requiredThickness(forLineCount: 9, font: font)
        let ten = LineNumberGutterView.requiredThickness(forLineCount: 10, font: font)
        XCTAssertEqual(one, nine)
        XCTAssertEqual(nine, ten)
    }

    // MARK: - Mapping (real layout)

    /// A scroll view + text view + gutter with real TextKit layout, sized
    /// so tests can force soft wrapping with a narrow width.
    private func makeGutter(text: String, width: CGFloat = 400)
        -> (scrollView: NSScrollView, textView: NSTextView, gutter: LineNumberGutterView) {
        let frame = NSRect(x: 0, y: 0, width: width, height: 300)
        let scrollView = NSScrollView(frame: frame)
        let textView = NSTextView(frame: frame)
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        textView.string = text

        let gutter = LineNumberGutterView(scrollView: scrollView, textView: textView)
        scrollView.verticalRulerView = gutter
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        return (scrollView, textView, gutter)
    }

    private func fullRect(of textView: NSTextView) -> NSRect {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return .zero }
        layoutManager.ensureLayout(for: textContainer)
        return NSRect(origin: .zero,
                      size: NSSize(width: textView.frame.width,
                                   height: max(layoutManager.usedRect(for: textContainer).maxY + 100, 300)))
    }

    func testOneNumberPerLogicalLine() {
        let (_, textView, gutter) = makeGutter(text: "one\ntwo\nthree")
        let numbers = gutter.lineNumberPositions(in: fullRect(of: textView)).map(\.number)
        XCTAssertEqual(numbers, [1, 2, 3])
    }

    func testWrappedLineGetsOneNumber() {
        // A soft-wrapped line spans several fragments but is one line;
        // only its first fragment is numbered
        let (_, textView, gutter) = makeGutter(
            text: String(repeating: "wrap ", count: 60) + "\nsecond",
            width: 120
        )
        let positions = gutter.lineNumberPositions(in: fullRect(of: textView))
        XCTAssertEqual(positions.map(\.number), [1, 2])
        // Sanity-check that wrapping actually happened, or this test
        // proves nothing: line 2 must start well below line 1's height
        XCTAssertGreaterThan(positions[1].yInTextView, positions[0].height * 3)
    }

    func testViewportStartingMidWrappedLineNumbersCorrectly() {
        // The first branch counted the wrapped line's continuation as a
        // full line and drew every visible number one too high (#102).
        // A viewport that starts inside line 1's soft wrap must label the
        // next line "2".
        let (_, textView, gutter) = makeGutter(
            text: String(repeating: "wrap ", count: 60) + "\nsecond",
            width: 120
        )
        let all = gutter.lineNumberPositions(in: fullRect(of: textView))
        XCTAssertEqual(all.count, 2)

        // A rect from one point inside line 1's second fragment down past
        // line 2's top — the old prefix counter would have labeled line 2
        // as "3" here
        let midWrapY = all[0].yInTextView + all[0].height + 1
        let midRect = NSRect(x: 0, y: midWrapY,
                             width: 120, height: all[1].yInTextView - midWrapY + 30)
        let numbers = gutter.lineNumberPositions(in: midRect).map(\.number)
        XCTAssertEqual(numbers, [2])

        // And a rect over continuation fragments only: no line starts, no
        // numbers — continuation fragments are never labeled
        let continuationRect = NSRect(x: 0, y: midWrapY, width: 120, height: all[0].height)
        XCTAssertEqual(gutter.lineNumberPositions(in: continuationRect).map(\.number), [])
    }

    func testEmptyDocumentShowsLineOne() {
        // The old glyph walk drew nothing for an empty document (#105)
        let (_, textView, gutter) = makeGutter(text: "")
        let numbers = gutter.lineNumberPositions(in: fullRect(of: textView)).map(\.number)
        XCTAssertEqual(numbers, [1])
    }

    func testTrailingEmptyLineIsNumbered() {
        // "a\n" is two lines; the second has no glyphs, only the extra
        // line fragment where the caret sits (#105)
        let (_, textView, gutter) = makeGutter(text: "a\n")
        let numbers = gutter.lineNumberPositions(in: fullRect(of: textView)).map(\.number)
        XCTAssertEqual(numbers, [1, 2])
    }

    func testIndexTracksLiveEdits() {
        // The gutter is the text storage delegate; typing must keep the
        // index current without a rebuild call from anyone
        let (_, textView, gutter) = makeGutter(text: "one")
        textView.textStorage?.replaceCharacters(in: NSRange(location: 3, length: 0), with: "\ntwo\nthree")
        let numbers = gutter.lineNumberPositions(in: fullRect(of: textView)).map(\.number)
        XCTAssertEqual(numbers, [1, 2, 3])
    }

    // MARK: - Preference (#106)

    /// Same save/restore pattern as the font tests; #174 tracks moving
    /// all preference tests onto an injected throwaway UserDefaults.
    private func withSavedLineNumbersPreference(_ body: () throws -> Void) rethrows {
        let saved = PreferencesManager.shared.showLineNumbers
        defer { PreferencesManager.shared.showLineNumbers = saved }
        try body()
    }

    func testShowLineNumbersDefaultsToOn() {
        withSavedLineNumbersPreference {
            UserDefaults.standard.removeObject(forKey: "showLineNumbers")
            XCTAssertTrue(PreferencesManager.shared.showLineNumbers)
        }
    }

    func testShowLineNumbersPersists() {
        withSavedLineNumbersPreference {
            PreferencesManager.shared.showLineNumbers = false
            XCTAssertFalse(PreferencesManager.shared.showLineNumbers)
            XCTAssertFalse(UserDefaults.standard.bool(forKey: "showLineNumbers"))
        }
    }

    /// Mutable notification counter that block observers can capture under
    /// strict concurrency. The posts under test are synchronous on the
    /// main thread, so the unchecked marker is honest.
    private final class Counter: @unchecked Sendable {
        var value = 0
    }

    func testChangingThePreferencePostsExactlyOneNotification() {
        withSavedLineNumbersPreference {
            PreferencesManager.shared.showLineNumbers = true

            let received = Counter()
            let token = NotificationCenter.default.addObserver(
                forName: PreferencesManager.showLineNumbersDidChangeNotification,
                object: nil, queue: nil) { _ in received.value += 1 }
            defer { NotificationCenter.default.removeObserver(token) }

            PreferencesManager.shared.showLineNumbers = false
            XCTAssertEqual(received.value, 1)
        }
    }

    func testWritingTheSameValuePostsNothing() {
        // Every editor window re-lays-out on this notification; a no-op
        // write must not fan out as a change
        withSavedLineNumbersPreference {
            PreferencesManager.shared.showLineNumbers = true

            let received = Counter()
            let token = NotificationCenter.default.addObserver(
                forName: PreferencesManager.showLineNumbersDidChangeNotification,
                object: nil, queue: nil) { _ in received.value += 1 }
            defer { NotificationCenter.default.removeObserver(token) }

            PreferencesManager.shared.showLineNumbers = true
            XCTAssertEqual(received.value, 0)
        }
    }
}

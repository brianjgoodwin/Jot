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

    func testThicknessNeverShrinksAsDigitsGrow() {
        // Not strict growth everywhere: at small fonts the 32 pt minimum
        // swallows the 2 → 3 digit step, so 99 → 100 may hold width.
        // What must hold is monotonicity, and strict growth once the digit
        // width clears the floor.
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let twoDigits = LineNumberGutterView.thickness(forLineCount: 99, font: font)
        let threeDigits = LineNumberGutterView.thickness(forLineCount: 100, font: font)
        let fourDigits = LineNumberGutterView.thickness(forLineCount: 1000, font: font)
        XCTAssertLessThanOrEqual(twoDigits, threeDigits)
        XCTAssertLessThan(threeDigits, fourDigits)
    }

    func testThicknessHasAFloor() {
        // A one-line document still gets a usable gutter, and 9 → 10
        // stays inside the two-digit reservation instead of jittering
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let one = LineNumberGutterView.thickness(forLineCount: 1, font: font)
        let nine = LineNumberGutterView.thickness(forLineCount: 9, font: font)
        let ten = LineNumberGutterView.thickness(forLineCount: 10, font: font)
        XCTAssertEqual(one, nine)
        XCTAssertEqual(nine, ten)
    }

    // MARK: - Mapping (real layout)

    /// A scroll view + text view + gutter with real TextKit layout, sized
    /// so tests can force soft wrapping with a narrow width. Uses the real
    /// GutterScrollView/GutterClipView so the geometry layer — the part
    /// resting on empirically-observed AppKit behavior — is what gets
    /// exercised, not a plain NSScrollView stand-in (#178).
    private func makeGutter(text: String, width: CGFloat = 400)
        -> (scrollView: GutterScrollView, textView: NSTextView, gutter: LineNumberGutterView) {
        let frame = NSRect(x: 0, y: 0, width: width, height: 300)
        let scrollView = GutterScrollView(frame: frame)
        let clipView = GutterClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        let textView = NSTextView(frame: frame)
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width, .height]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        textView.string = text

        let gutter = LineNumberGutterView(scrollView: scrollView, textView: textView)
        scrollView.addSubview(gutter)
        scrollView.gutterView = gutter
        scrollView.tile()
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

    // MARK: - Scroll view geometry (#178)

    func testTileReservesTheGutterStrip() {
        let (scrollView, textView, gutter) = makeGutter(text: "one\ntwo")
        let clip = scrollView.contentView
        // The clip starts one gutter-width in, the ruler fills that strip,
        // and the wrap width follows the shrunken clip.
        XCTAssertEqual(clip.frame.minX, gutter.requiredThickness)
        XCTAssertEqual(gutter.frame.width, gutter.requiredThickness)
        XCTAssertEqual(textView.frame.width, clip.bounds.width)
    }

    func testRedundantTileDoesNotInvalidateLayout() {
        // The #178 performance bug: every tile() bounced the clip to full
        // width and back, which invalidated layout for the whole document
        // through widthTracksTextView. On a large file that made typing
        // near the bottom (contiguous layout re-lays everything above the
        // caret) and live resizes pay a full-document re-layout per event.
        let (scrollView, textView, _) = makeGutter(
            text: String(repeating: "a line of ordinary text\n", count: 3000))
        guard let layoutManager = textView.layoutManager,
              let container = textView.textContainer else {
            return XCTFail("text view lost its text system")
        }
        layoutManager.ensureLayout(for: container)
        let length = (textView.string as NSString).length
        XCTAssertEqual(layoutManager.firstUnlaidCharacterIndex(), length,
                       "sanity: the whole document is laid out")

        scrollView.tile()
        XCTAssertEqual(layoutManager.firstUnlaidCharacterIndex(), length,
                       "a geometry-neutral tile() must not throw away layout")

        // The live-resize path retiles on every frame; an unchanged size
        // must also be layout-neutral.
        scrollView.setFrameSize(scrollView.frame.size)
        XCTAssertEqual(layoutManager.firstUnlaidCharacterIndex(), length,
                       "a same-size setFrameSize must not throw away layout")
    }

    func testClipNeverFlapsToFullWidth() {
        // The #178 root cause: super.tile() sets the clip to full scroll
        // view width, and the old override shrunk it back — the oscillation
        // invalidated layout. With the clip-view-interception pattern the
        // clip never accepts the wrong frame in the first place.
        let (scrollView, _, gutter) = makeGutter(text: "one\ntwo")
        let clip = scrollView.contentView
        let expectedClipWidth = scrollView.bounds.width - gutter.requiredThickness

        // Repeated tiles must leave the clip at the inset width.
        for _ in 0..<5 {
            scrollView.tile()
            XCTAssertEqual(clip.frame.width, expectedClipWidth)
            XCTAssertEqual(clip.frame.minX, gutter.requiredThickness)
        }
    }

    func testNoAutomaticContentInsets() {
        // The OS's overlay-ruler accommodation adds a left content inset
        // that creates real horizontal scroll range. tile() reserves the
        // ruler's strip deterministically, so the automatic one is declined.
        let (scrollView, textView, _) = makeGutter(text: "one\ntwo")
        XCTAssertFalse(scrollView.automaticallyAdjustsContentInsets)
        XCTAssertEqual(scrollView.contentInsets.left, 0)
        XCTAssertEqual(textView.frame.width, scrollView.contentView.bounds.width)
    }

    func testTileLeavesWrapOffWidthAlone() {
        // With word wrap off the text view's width is content-driven, not
        // clip-driven. tile() must neither reconcile it to the clip nor
        // let the clip-sync erode it (#178 follow-up: the first fix
        // clobbered it, which killed horizontal scrolling in wrap-off).
        let (scrollView, textView, _) = makeGutter(text: "a rather long line of text\nshort")
        // Configure exactly what Format > Toggle Word Wrap does.
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        scrollView.hasHorizontalScroller = true
        let wrapOffWidth = scrollView.frame.width * 2
        textView.setFrameSize(CGSize(width: wrapOffWidth, height: textView.frame.height))

        scrollView.tile()
        XCTAssertEqual(textView.frame.width, wrapOffWidth)
        XCTAssertEqual(textView.textContainer?.size.width, CGFloat.greatestFiniteMagnitude)
        XCTAssertFalse(textView.textContainer?.widthTracksTextView ?? true)

        scrollView.setFrameSize(scrollView.frame.size)
        XCTAssertEqual(textView.frame.width, wrapOffWidth)
    }

    func testLegacyScrollersKeepTheClipClearOfTheScroller() {
        // Overlay scrollers float above the content; legacy scrollers
        // ("Show scroll bars: Always", or any plugged-in mouse) consume
        // layout space on the trailing edge. The clip width is derived
        // from the scroll view's bounds, so it must subtract a visible
        // legacy scroller too — or the text runs underneath it (#178).
        let (scrollView, textView, gutter) = makeGutter(text: "one\ntwo")
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.tile()

        guard let scroller = scrollView.verticalScroller, !scroller.isHidden else {
            return XCTFail("sanity: a non-autohiding legacy scroller must be visible")
        }
        XCTAssertGreaterThan(scroller.frame.width, 0,
                             "sanity: a legacy scroller consumes real width")
        let clip = scrollView.contentView
        XCTAssertEqual(clip.frame.width,
                       scrollView.bounds.width - gutter.requiredThickness - scroller.frame.width)
        XCTAssertEqual(clip.frame.minX, gutter.requiredThickness)
        XCTAssertEqual(textView.frame.width, clip.bounds.width)
    }

    func testNoPhantomLeftwardScrollRange() {
        // Installing the gutter via verticalRulerView made NSClipView's
        // constrainBoundsRect report -rulerThickness of leftward scroll
        // range (the overlay accommodation), and the elastic scroll
        // machinery cached it before any override could clamp — the
        // horizontal rubber-band with wrap on (#178). As a plain
        // subview, the accommodation never engages: a leftward proposal
        // must constrain to zero with no clamp of our own.
        let (scrollView, _, _) = makeGutter(text: "one\ntwo")
        let clip = scrollView.contentView
        let proposed = NSRect(x: -50, y: 0,
                              width: clip.bounds.width, height: clip.bounds.height)
        XCTAssertEqual(clip.constrainBoundsRect(proposed).origin.x, 0)
    }

    func testResizeStillReflowsTheText() {
        // The flip side of the no-op guard: a real width change must still
        // reach the text container, once, or wrap width goes stale.
        let (scrollView, textView, _) = makeGutter(text: "one\ntwo", width: 400)
        scrollView.setFrameSize(NSSize(width: 250, height: 300))
        let clip = scrollView.contentView
        XCTAssertEqual(textView.frame.width, clip.bounds.width)
        XCTAssertEqual(textView.textContainer?.size.width,
                       textView.frame.width - 2 * textView.textContainerInset.width)

        scrollView.setFrameSize(NSSize(width: 500, height: 300))
        XCTAssertEqual(textView.frame.width, scrollView.contentView.bounds.width)
    }

    // MARK: - Delegate lifecycle (#178)
    //
    // NSTextStorage.delegate is assign, not weak. These pin the three
    // teardown guarantees: an owner clears its slot, a stale gutter
    // leaves a replacement's slot alone, and deinit backstops the paths
    // that skip tearDown — the failure modes are a silent freeze and a
    // use-after-free, neither of which any other test would catch.

    func testTearDownClearsOwnedDelegates() {
        let (_, textView, gutter) = makeGutter(text: "one\ntwo")
        XCTAssertTrue(textView.textStorage?.delegate === gutter,
                      "sanity: the gutter owns the storage delegate slot after install")
        XCTAssertTrue(textView.layoutManager?.delegate === gutter,
                      "sanity: the gutter owns the layout delegate slot after install")
        gutter.tearDown()
        XCTAssertNil(textView.textStorage?.delegate)
        XCTAssertNil(textView.layoutManager?.delegate)
    }

    func testStaleTearDownLeavesTheLiveDelegateAlone() {
        // Install/remove/reinstall is the sequence that bites: if a stale
        // gutter's tearDown clears a slot a replacement now owns, the
        // live gutter silently stops receiving edits — line numbers
        // freeze, nothing crashes, no test fails.
        let (scrollView, textView, staleGutter) = makeGutter(text: "one\ntwo")
        let liveGutter = LineNumberGutterView(scrollView: scrollView, textView: textView)
        scrollView.addSubview(liveGutter)
        scrollView.gutterView = liveGutter
        XCTAssertTrue(textView.textStorage?.delegate === liveGutter,
                      "sanity: the replacement claimed the slot on init")

        staleGutter.tearDown()
        XCTAssertTrue(textView.textStorage?.delegate === liveGutter,
                      "a stale gutter must not unregister the live one")
        XCTAssertTrue(textView.layoutManager?.delegate === liveGutter,
                      "a stale gutter must not unregister the live layout delegate either")

        // And the live gutter really is still tracking edits.
        textView.textStorage?.replaceCharacters(in: NSRange(location: 0, length: 0),
                                                with: "zero\n")
        let numbers = liveGutter.lineNumberPositions(in: fullRect(of: textView)).map(\.number)
        XCTAssertEqual(numbers, [1, 2, 3])
    }

    func testDeinitClearsTheDelegateWhenTearDownWasSkipped() {
        // A gutter freed while still registered leaves the storage
        // pointing at freed memory; the next edit is a use-after-free.
        // The text view is kept alive across the pool drain so deinit
        // still has a path to the storage.
        var keepTextView: NSTextView?
        weak var deallocatedGutter: LineNumberGutterView?
        autoreleasepool {
            let (scrollView, textView, gutter) = makeGutter(text: "one\ntwo")
            keepTextView = textView
            deallocatedGutter = gutter
            gutter.removeFromSuperview()
        }
        XCTAssertNil(deallocatedGutter,
                     "sanity: nothing retains the gutter once the ruler slot is cleared")
        XCTAssertNil(keepTextView?.textStorage?.delegate,
                     "deinit must clear a delegate slot it still owns")
        XCTAssertNil(keepTextView?.layoutManager?.delegate,
                     "deinit must clear the layout delegate slot too")
    }

    func testLayoutCompletionInvalidatesTheGutter() {
        // The launch-paint bug: a restored window's first draw can run
        // before TextKit lays out the restored scroll position, so the
        // glyph query is empty and the strip paints bare. The text view
        // repaints itself when background layout catches up; the gutter
        // must get the same signal or it stays blank until first input.
        let (scrollView, textView, gutter) = makeGutter(
            text: String(repeating: "a line of ordinary text\n", count: 3000))
        guard let layoutManager = textView.layoutManager,
              let container = textView.textContainer else {
            return XCTFail("text view lost its text system")
        }

        // needsDisplay is only tracked for views in a window; the launch
        // bug is a windowed scenario, so give the gutter one.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scrollView

        // Setup already laid everything out, so throw that layout away
        // first — the launch scenario is exactly "layout not done yet."
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
        gutter.needsDisplay = false

        layoutManager.ensureLayout(for: container)

        XCTAssertTrue(gutter.needsDisplay,
                      "completing layout must invalidate the gutter")
    }

    func testSameLineCaretMovesDoNotRepaintTheGutter() {
        // Nothing the gutter draws depends on the caret beyond which
        // number is bold, so a caret move within one line — the
        // overwhelmingly common selection change — must not repaint;
        // crossing to another line must. Pinned at the decision method
        // rather than needsDisplay: in a headless window AppKit's dirty
        // tracking is unobservable (layerless windows share one dirty
        // region across siblings, and layer-backed readback is
        // unreliable), so the observer is detached and the decision
        // driven directly.
        let (_, textView, gutter) = makeGutter(text: "one line\nsecond")
        NotificationCenter.default.removeObserver(gutter)

        textView.setSelectedRange(NSRange(location: 0, length: 0))
        _ = gutter.noteSelectionChanged()

        textView.setSelectedRange(NSRange(location: 3, length: 0))
        XCTAssertFalse(gutter.noteSelectionChanged(),
                       "a caret move within line 1 repaints nothing")

        textView.setSelectedRange(NSRange(location: 10, length: 0))
        XCTAssertTrue(gutter.noteSelectionChanged(),
                      "moving the caret to line 2 must rebold the numbers")
        XCTAssertFalse(gutter.noteSelectionChanged(),
                       "a second look at the same selection is a no-op")
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

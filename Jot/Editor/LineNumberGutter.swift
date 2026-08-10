//
//  LineNumberGutter.swift
//  Jot
//
//  Created on 8/9/26.
//
//  Line number gutter for the editor (#42), rebuilt on NSRulerView.
//
//  The first attempt (feature/42-line-number-gutter) drew numbers in the
//  text view's background behind a textContainerOrigin offset, which meant
//  hand-synchronizing the container width with the inset on every toggle,
//  resize, and wrap change — and it got that wrong in ways that clipped
//  text (#104). Here the geometry lives in exactly one place —
//  GutterScrollView.tile() below — and everything else follows from the
//  clip view's frame, which the text system already tracks. Invalidating
//  the gutter also no longer redraws the text (#103).
//

import Cocoa
import os.signpost

// MARK: - Scroll view geometry
//
// Current macOS treats vertical rulers as an overlay and applies its own
// accommodation — but lazily and only partially in this configuration:
// nothing happens until the first live resize (ruler overlaps the text at
// launch), and after one it shifts the content's rest position without
// narrowing the tracked text width (right edge wraps out of view). All of
// this was established empirically with on-screen windows; none of it is
// something to rely on. So both halves of the geometry are owned here,
// deterministically: GutterScrollView.tile() reserves the ruler's strip by
// shrinking the clip view — the arrangement widthTracksTextView already
// understands, so wrap width follows for free (#104) — and GutterClipView
// refuses the OS's overlay rest-position shift, which would otherwise open
// a dead gutter-width gap between the numbers and the text.
//
// One more empirically-established behavior matters here: NSTextView
// resyncs its own frame to clip frame changes through a private
// notification handler, bypassing autoresizing masks entirely. tile()
// works around the layout cost of that resync — see the comment there
// (#178).

/// The editor's scroll view (set as a custom class in the storyboard).
final class GutterScrollView: NSScrollView {

    // During a live drag AppKit defers tiling to the end of the resize.
    // Without the gutter that didn't matter — the clip tracked the frame
    // and text reflowed continuously. With the clip's placement owned by
    // tile(), deferred tiling means text that only reflows on mouse-up.
    // Retiling here restores the continuous reflow; a no-op tile() no
    // longer touches the text container (see tile() below), so the
    // redundant calls outside live resize are fine.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if rulersVisible {
            tile()
        }
    }

    override func tile() {
        guard rulersVisible, verticalRulerView != nil else {
            super.tile()
            return
        }

        // super.tile() re-lays the clip at full width on every call, and
        // retileBesideRuler() re-shrinks it. Each clip frame write reaches
        // the text view — not through autoresizing, but through NSTextView's
        // private clip-frame-notification handler, which resizes the text
        // view directly (and, on some paths, to the wrong width: clip minus
        // ruler thickness a second time). With widthTracksTextView on, every
        // one of those resizes pushes a new container width, and each new
        // width invalidates layout for the WHOLE document — a ~250 ms
        // re-layout on a 1 MB file, paid per keystroke near the bottom
        // (contiguous layout re-lays everything above the caret) and per
        // live-resize frame (#178).
        //
        // So: suspend width tracking while the frames dance, then apply the
        // net result exactly once — the text view flaps harmlessly (frame
        // changes without a container update cost no layout), and the
        // container sees either no change (redundant tile: zero
        // invalidations) or one change (real resize: one invalidation,
        // the same as a gutterless scroll view).
        let textView = documentView as? NSTextView
        let container = textView?.textContainer
        let restoreTracking = container?.widthTracksTextView ?? false
        container?.widthTracksTextView = false

        super.tile()
        retileBesideRuler()

        var wrapWidthChanged = false
        if let textView {
            let targetWidth = contentView.bounds.width
            if textView.frame.width != targetWidth {
                textView.setFrameSize(NSSize(width: targetWidth,
                                             height: textView.frame.height))
            }
            if restoreTracking, let container {
                container.widthTracksTextView = true
                // The width a tracking container derives from this frame
                // (lineFragmentPadding lives inside the container).
                let targetContainerWidth = max(targetWidth - 2 * textView.textContainerInset.width, 0)
                if container.size.width != targetContainerWidth {
                    wrapWidthChanged = true
                    container.size = NSSize(width: targetContainerWidth,
                                            height: container.size.height)
                }
            }
        }
        os_signpost(.event, log: PerformanceLog.log, name: "Gutter Tile",
                    "wrapWidthChanged: %d", wrapWidthChanged ? 1 : 0)
    }

    private func retileBesideRuler() {
        guard let ruler = verticalRulerView else { return }

        let clipFrame = contentView.frame
        let inset = min(ruler.requiredThickness, clipFrame.maxX)

        // If a future macOS reserves ruler space in tile() again, the
        // clip arrives already offset — normalize the ruler beside it
        // and don't shrink a second time.
        if clipFrame.minX >= inset {
            ruler.frame = NSRect(x: clipFrame.minX - inset, y: clipFrame.minY,
                                 width: inset, height: clipFrame.height)
            return
        }

        ruler.frame = NSRect(x: 0, y: clipFrame.minY,
                             width: inset, height: clipFrame.height)
        contentView.frame = NSRect(x: inset, y: clipFrame.minY,
                                   width: clipFrame.maxX - inset,
                                   height: clipFrame.height)
    }
}

/// The editor's clip view (set as a custom class in the storyboard).
final class GutterClipView: NSClipView {

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var bounds = super.constrainBoundsRect(proposedBounds)
        // The OS proposes a rest position one ruler-width into negative x
        // to slide content out from under an overlay ruler. tile() above
        // already moved the clip itself, so accepting the shift too would
        // indent the text a second gutter-width.
        if let scrollView = enclosingScrollView, scrollView.rulersVisible {
            bounds.origin.x = max(bounds.origin.x, 0)
        }
        return bounds
    }
}

// MARK: - LineIndex

/// Sorted character offsets of every line start in a string, kept current
/// across edits. This exists so the gutter can answer "what line number is
/// this character on?" with a binary search instead of scanning the
/// document from character zero on every draw — the scan made gutter cost
/// O(document) per frame and miscounted by one when the viewport started
/// mid wrapped line (#102, #103).
///
/// Model: line 1 starts at offset 0; a new line starts after every line
/// terminator, including one at the very end of the string. So "a\n" has
/// starts [0, 2] — the trailing empty line is a real line (it is where the
/// caret sits after Return, and the gutter must number it, #105) — and the
/// empty string has starts [0]: one line.
struct LineIndex {

    private(set) var lineStarts: [Int] = [0]

    var lineCount: Int { lineStarts.count }

    init() {}

    init(string: NSString) {
        rebuild(from: string)
    }

    mutating func rebuild(from string: NSString) {
        lineStarts = [0]
        lineStarts.append(contentsOf: starts(in: string, from: 0, upTo: string.length))
    }

    /// Update the index for one edit, touching only the affected lines.
    /// `editedRange` and `delta` are exactly what
    /// `NSTextStorageDelegate.textStorage(_:didProcessEditing:...)` provides:
    /// the range in the post-edit string and the length change.
    ///
    /// The shape: keep starts before the edited line untouched, rescan just
    /// the lines the edit could have altered, and shift the rest by the
    /// length change. The rescan region is widened to whole lines so that a
    /// CRLF pair formed or split at an edit boundary is re-read as a unit —
    /// the case a character-range rescan gets wrong.
    mutating func applyEdit(in string: NSString, editedRange: NSRange, changeInLength delta: Int) {
        let length = string.length
        let editStart = min(editedRange.location, length)
        let editEnd = min(NSMaxRange(editedRange), length)

        // Whole-line bounds of the edit, in the new string.
        let rescanStart = string.lineRange(for: NSRange(location: editStart, length: 0)).location
        let rescanEnd = NSMaxRange(string.lineRange(for: NSRange(location: editEnd, length: 0)))

        // Starts strictly before the rescanned region: their terminators
        // are in untouched text, so they are still valid as-is.
        var updated = Array(lineStarts.prefix(while: { $0 < rescanStart }))

        // rescanStart is a line start in the new string by construction
        // (it came from lineRange), and it is not in the kept prefix.
        updated.append(rescanStart)
        updated.append(contentsOf: starts(in: string, from: rescanStart, upTo: rescanEnd))

        // Starts strictly after the rescanned region existed before the
        // edit at (position - delta), and their terminators are in
        // untouched text — shift them instead of re-reading them.
        let oldBoundary = rescanEnd - delta
        let firstShifted = firstIndex(in: lineStarts, greaterThan: oldBoundary)
        for i in firstShifted..<lineStarts.count {
            updated.append(lineStarts[i] + delta)
        }

        lineStarts = updated
    }

    /// 1-based line number of the line containing `location`. A location at
    /// the very end of a terminator-final string lands on the trailing
    /// empty line, which is what the caret does too.
    func lineNumber(forCharacterAt location: Int) -> Int {
        return firstIndex(in: lineStarts, greaterThan: location)
    }

    func isLineStart(_ location: Int) -> Bool {
        let index = firstIndex(in: lineStarts, greaterThan: location)
        return index > 0 && lineStarts[index - 1] == location
    }

    /// Line starts after each terminated line in [from, upTo), where `from`
    /// must itself be a line start. A terminator ending exactly at `upTo`
    /// contributes a start there — that is the trailing empty line when
    /// `upTo` is the string length.
    private func starts(in string: NSString, from: Int, upTo limit: Int) -> [Int] {
        var found: [Int] = []
        var index = from
        while index < limit {
            var lineEnd = 0
            var contentsEnd = 0
            string.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd,
                                for: NSRange(location: index, length: 0))
            // contentsEnd != lineEnd means the line ended with a terminator,
            // so a new line starts at lineEnd.
            if contentsEnd != lineEnd {
                found.append(lineEnd)
            }
            index = lineEnd
        }
        return found
    }

    /// Index of the first element greater than `value` (upper bound).
    /// `sorted` must be ascending.
    private func firstIndex(in sorted: [Int], greaterThan value: Int) -> Int {
        var low = 0
        var high = sorted.count
        while low < high {
            let mid = (low + high) / 2
            if sorted[mid] <= value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}

// MARK: - LineNumberGutterView

/// The vertical ruler that draws line numbers beside the editor.
///
/// Aesthetics carried over from the first gutter branch: monospaced-digit
/// numbers one point smaller than the editor font, bold on the caret's
/// line, right-aligned against a hairline separator. Colors are semantic
/// (#107) — the hardcoded appearance-branching grays regressed the #49
/// semantic-color work and ignored the Increase Contrast variants.
final class LineNumberGutterView: NSRulerView {

    private weak var textView: NSTextView?
    private var lineIndex = LineIndex()

    private static let horizontalPadding: CGFloat = 5
    private static let minimumThickness: CGFloat = 32

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView

        // Since macOS 14, views do NOT clip their drawing to their bounds
        // by default, and the dirtyRect handed to draw(_:) can span far
        // beyond this view. Without this, the background fill below paints
        // controlBackgroundColor across the entire window — over the text
        // — which renders every document apparently empty.
        clipsToBounds = true

        lineIndex.rebuild(from: textView.string as NSString)
        updateThickness()

        // The gutter owns the text storage delegate slot; nothing else in
        // the app uses it. If that ever changes, the edits must be fanned
        // out, or the index here goes silently stale.
        textView.textStorage?.delegate = self

        // Only the gutter redraws on caret movement — invalidating the
        // whole text view for a bold number forced a full glyph redraw per
        // keystroke on the old branch (#103).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        // Belt and suspenders for scroll sync: ruler views normally track
        // their scroll view, but layer-backed scroll views have a history
        // of leaving rulers a frame behind. The clip view already posts
        // bounds changes for the styling debounce.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    required init(coder: NSCoder) {
        fatalError("LineNumberGutterView is created in code")
    }

    /// Called by the editor before the gutter is removed from its scroll
    /// view, so a text edit arriving afterward doesn't message a ruler
    /// that is mid-teardown.
    func tearDown() {
        textView?.textStorage?.delegate = nil
        NotificationCenter.default.removeObserver(self)
    }

    deinit {
        // Backstop for paths that skip tearDown. Matches the pattern in
        // EditorViewController and WordCountPanelController.
        NotificationCenter.default.removeObserver(self)
    }

    // The text view is flipped; declaring the gutter flipped too keeps
    // every converted y coordinate in the same top-down space.
    override var isFlipped: Bool { true }

    @objc private func selectionDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        needsDisplay = true
    }

    // MARK: Geometry

    /// Everything the gutter will draw for `visibleRect` (text view
    /// coordinates): one entry per line whose first fragment is visible,
    /// plus the trailing empty line when its fragment is. Separated from
    /// draw(_:) so tests can drive it with arbitrary rects — including the
    /// mid-wrapped-line viewport that broke the old prefix counter (#102).
    struct LinePosition: Equatable {
        /// Top of the line's first fragment, text view coordinates.
        var yInTextView: CGFloat
        var height: CGFloat
        var number: Int
    }

    func lineNumberPositions(in visibleRect: NSRect) -> [LinePosition] {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return [] }

        let containerOrigin = textView.textContainerOrigin
        var rectInContainer = visibleRect
        rectInContainer.origin.x -= containerOrigin.x
        rectInContainer.origin.y -= containerOrigin.y

        // Empty documents lay out nothing, so nothing forces the extra
        // line fragment (the caret's line) into existence. Ensuring layout
        // here is O(1) — there is no text.
        if (textView.string as NSString).length == 0 {
            layoutManager.ensureLayout(for: textContainer)
        }

        var positions: [LinePosition] = []

        let glyphRange = layoutManager.glyphRange(forBoundingRect: rectInContainer, in: textContainer)
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var fragmentGlyphRange = NSRange(location: NSNotFound, length: 0)
            let fragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &fragmentGlyphRange
            )
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            // Continuation fragments of a soft-wrapped line don't start a
            // line, so they get no number — and no counter to misplace: the
            // number is looked up from the index, not accumulated (#102).
            if lineIndex.isLineStart(characterIndex) {
                positions.append(LinePosition(
                    yInTextView: fragmentRect.minY + containerOrigin.y,
                    height: fragmentRect.height,
                    number: lineIndex.lineNumber(forCharacterAt: characterIndex)
                ))
            }

            let nextGlyphIndex = NSMaxRange(fragmentGlyphRange)
            if nextGlyphIndex <= glyphIndex { break }
            glyphIndex = nextGlyphIndex
        }

        // The line after a trailing newline — and the only line of an empty
        // document — has no glyphs, only the extra line fragment. Every
        // standard gutter numbers it; leaving it blank while the caret
        // sits there reads as a glitch (#105).
        if layoutManager.extraLineFragmentTextContainer != nil {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.intersects(rectInContainer) || (textView.string as NSString).length == 0 {
                positions.append(LinePosition(
                    yInTextView: extraRect.minY + containerOrigin.y,
                    height: extraRect.height,
                    number: lineIndex.lineCount
                ))
            }
        }

        return positions
    }

    // MARK: Width

    /// Width needed to show `lineCount`'s digits in `font`, padded. Pure so
    /// the digit-boundary behavior (9 → 10, 99 → 100) is directly testable.
    static func requiredThickness(forLineCount lineCount: Int, font: NSFont) -> CGFloat {
        let digits = max(String(lineCount).count, 2)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = sample.size(withAttributes: [.font: font]).width
        return max(ceil(width) + horizontalPadding * 2, minimumThickness)
    }

    /// Re-derives the ruler width. Called when the digit count of the total
    /// changes and on font changes — not per draw, and never as a function
    /// of a full-document line scan (#103).
    func updateThickness() {
        let needed = Self.requiredThickness(
            forLineCount: lineIndex.lineCount,
            font: numberFont(bold: false)
        )
        if abs(needed - ruleThickness) > 0.5 {
            ruleThickness = needed
            // GutterScrollView.tile() is what actually moves the clip view
            // for the new width; a thickness change must not wait for the
            // next resize to take effect
            scrollView?.tile()
        }
    }

    private func numberFont(bold: Bool) -> NSFont {
        let editorSize = textView?.font?.pointSize ?? NSFont.systemFontSize
        let size = max(editorSize - 1, 9)
        return .monospacedDigitSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    // MARK: Drawing

    // The gutter owns its entire surface — no markers, no hash marks — so
    // draw(_:) replaces NSRulerView's default drawing outright instead of
    // hooking drawHashMarksAndLabels(in:).
    override func draw(_ dirtyRect: NSRect) {
        // Belt and suspenders with clipsToBounds: never paint outside the
        // gutter even if the clipping arrangement changes again
        let gutterRect = bounds.intersection(dirtyRect)
        guard !gutterRect.isNull else { return }

        NSColor.controlBackgroundColor.setFill()
        gutterRect.fill()

        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: gutterRect.minY, width: 1, height: gutterRect.height).fill()

        guard let textView = textView else { return }

        let currentLine = lineIndex.lineNumber(forCharacterAt: textView.selectedRange().location)

        for position in lineNumberPositions(in: textView.visibleRect) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: numberFont(bold: position.number == currentLine),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            let numberString = String(position.number) as NSString
            let size = numberString.size(withAttributes: attributes)
            let y = convert(NSPoint(x: 0, y: position.yInTextView), from: textView).y
            let drawPoint = NSPoint(
                x: ruleThickness - size.width - Self.horizontalPadding,
                y: y + (position.height - size.height) / 2
            )
            numberString.draw(at: drawPoint, withAttributes: attributes)
        }
    }
}

// MARK: - Text storage delegate

// @preconcurrency: the delegate protocol is nonisolated, but every edit to
// an NSTextView's storage happens on the main thread; the conformance
// asserts that at runtime instead of infecting the class with nonisolated
// members.
extension LineNumberGutterView: @preconcurrency NSTextStorageDelegate {
    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange,
                     changeInLength delta: Int) {
        // Markdown styling passes edit attributes constantly; only
        // character edits can move line starts.
        guard editedMask.contains(.editedCharacters) else { return }

        let digitsBefore = String(lineIndex.lineCount).count
        lineIndex.applyEdit(in: textStorage.string as NSString,
                            editedRange: editedRange,
                            changeInLength: delta)
        if String(lineIndex.lineCount).count != digitsBefore {
            updateThickness()
        }
        needsDisplay = true
    }
}

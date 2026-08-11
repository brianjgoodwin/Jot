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
//  text (#104). Here the geometry is owned by GutterClipView, which
//  intercepts every frame change and enforces the ruler inset — the clip
//  never accepts a wrong width, so widthTracksTextView and the text
//  system follow for free. Invalidating the gutter does not redraw the
//  text (#103).
//

import Cocoa

// MARK: - Scroll view geometry
//
// NSScrollView.tile() lays the clip view at full scroll-view width on
// every call, then expects subclasses to carve out ruler space. But
// NSTextView tracks clip-frame changes through a private notification
// handler (_superviewClipViewFrameChanged:), so the brief full-width
// frame reaches the text view and — with widthTracksTextView — pushes
// a new container width, invalidating layout for the entire document.
// On a 1 MB file that costs ~250 ms per tile(), paid per keystroke
// near the bottom (contiguous layout re-lays everything above the
// caret) and per live-resize frame (#178).
//
// CotEditor (coteditor/CotEditor, FB23993752) solved the same problem
// by making the clip view the geometry owner: it overrides setFrameSize
// and setFrameOrigin to substitute the correct inset frame, so the
// clip never accepts the wrong geometry and nothing downstream needs
// guarding. Jot adopts the same pattern: GutterScrollView.tile() tells
// GutterClipView how much space the ruler needs before calling
// super.tile(), and the clip view enforces that inset on every frame
// change — the oscillation never starts.
//
// The gutter is a plain subview of the scroll view, NOT registered as
// verticalRulerView. Registering a ruler triggers a second AppKit
// accommodation: NSClipView.constrainBoundsRect reports a phantom
// -rulerThickness leftward scroll range (assuming an overlay ruler),
// and the elastic scroll machinery caches that range before an
// override can clamp it — a horizontal rubber-band with wrap on.
// The class still subclasses NSRulerView for its thickness plumbing,
// but AppKit never knows it exists (#178).

/// The editor's scroll view (set as a custom class in the storyboard).
final class GutterScrollView: NSScrollView {

    /// The line number strip, installed as a plain subview — deliberately
    /// NOT via verticalRulerView. Registering a ruler makes NSClipView's
    /// constrainBoundsRect report a phantom -rulerThickness leftward
    /// scroll range (the overlay accommodation), and the elastic scroll
    /// machinery caches that range before any override can clamp it —
    /// the source of the horizontal rubber-band with wrap on (#178).
    /// As a plain subview the accommodation never engages.
    weak var gutterView: LineNumberGutterView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureScrollingBehavior()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureScrollingBehavior()
    }

    private func configureScrollingBehavior() {
        // The OS's overlay-ruler accommodation adds a left content inset
        // that creates real horizontal scroll range. tile() reserves the
        // ruler's strip deterministically, so decline the automatic one.
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsetsZero
        // Jot soft-wraps by default — no legitimate horizontal scrolling.
        // With .automatic elasticity, diagonal swipes rubber-band the text
        // sideways even with zero real range (only observable when a ruler
        // is installed; without one AppKit's scroll thread doesn't try).
        // toggleWordWrap flips to .automatic when wrap is off.
        horizontalScrollElasticity = .none
    }

    // During a live drag AppKit defers tiling to the end of the resize.
    // Without the gutter that didn't matter — the clip tracked the frame
    // and text reflowed continuously. With the clip's placement owned by
    // tile(), deferred tiling means text that only reflows on mouse-up.
    // Retiling here restores the continuous reflow.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if gutterView != nil {
            tile()
        }
    }

    override func tile() {
        let gutterClip = contentView as? GutterClipView

        guard let ruler = gutterView else {
            gutterClip?.rulerInset = 0
            super.tile()
            return
        }

        let inset = ruler.requiredThickness
        gutterClip?.rulerInset = inset

        // super.tile() will call setFrameOrigin/setFrameSize on the
        // clip view, proposing full-width geometry. The clip view's
        // overrides intercept those calls and substitute the inset
        // frame, so the clip never flaps to full width and
        // widthTracksTextView never sees a wrong value (#178).
        //
        // For the interception to fire, the clip must differ from what
        // super.tile() will propose — otherwise NSView's no-op
        // optimization skips the calls entirely. Ensuring the clip is
        // at the inset frame (not full-width) guarantees super.tile()
        // always calls through.
        let target = NSRect(x: inset, y: contentView.frame.minY,
                            width: bounds.width - inset,
                            height: contentView.frame.height)
        if contentView.frame != target {
            contentView.frame = target
        }

        super.tile()

        // With autohiding legacy scrollers, super.tile() can decide the
        // scroller's visibility after it proposed the clip's frame — the
        // interception then computed the width from a stale scroller
        // state. Poke the clip once more now that everything is settled:
        // the override recomputes from the live scroller and no-ops when
        // the width was already right.
        contentView.setFrameSize(contentView.frame.size)

        // With no ruler registered, NSTextView's clip-frame handler
        // sizes the text view to the clip width with no ruler-thickness
        // subtraction — this reconcile should be a no-op. Kept as a
        // self-healing guard: if any path leaves the tracked text view
        // narrower or wider than its clip, wrap width goes visibly
        // wrong. Only when widthTracksTextView is on (soft wrap); a
        // wrap-off text view's width is content-driven and untouchable.
        if let textView = documentView as? NSTextView,
           textView.textContainer?.widthTracksTextView == true {
            let clipWidth = contentView.bounds.width
            if textView.frame.width != clipWidth {
                textView.setFrameSize(NSSize(width: clipWidth,
                                             height: textView.frame.height))
            }
        }

        // Position the gutter strip beside the (now-stable) clip.
        ruler.frame = NSRect(x: 0, y: contentView.frame.minY,
                             width: inset, height: contentView.frame.height)
    }
}

/// The editor's clip view (set as a custom class in the storyboard).
///
/// Owns the inset geometry that reserves space for the vertical ruler.
/// Every frame change proposed by super.tile() is intercepted and
/// replaced with the correct inset frame, so the clip never flaps to
/// full width and NSTextView's private clip-frame handler never sees a
/// width change it shouldn't (#178).
final class GutterClipView: NSClipView {

    /// How much horizontal space to reserve for the ruler, set by
    /// GutterScrollView.tile() before calling super.tile(). Zero when
    /// no ruler is visible.
    var rulerInset: CGFloat = 0

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        if rulerInset > 0 {
            super.setFrameOrigin(NSPoint(x: rulerInset, y: newOrigin.y))
        } else {
            super.setFrameOrigin(newOrigin)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        if rulerInset > 0, let scrollView = superview as? NSScrollView {
            var available = scrollView.bounds.width
            // Overlay scrollers float above the content; legacy scrollers
            // ("Show scroll bars: Always", or any plugged-in mouse) consume
            // layout space on the trailing edge. Deriving the width from
            // the scroll view's bounds alone would run the clip — and the
            // text — underneath a legacy scroller (#178). Height needs no
            // such correction: it passes through from super.tile()'s
            // proposal, which already accounts for a horizontal scroller.
            if scrollView.scrollerStyle == .legacy,
               let scroller = scrollView.verticalScroller,
               !scroller.isHidden {
                available -= scroller.frame.width
            }
            super.setFrameSize(NSSize(width: available - rulerInset, height: newSize.height))
        } else {
            super.setFrameSize(newSize)
        }
    }

    // No constrainBoundsRect override: with the gutter installed as a
    // plain subview instead of verticalRulerView, super never reports
    // the phantom -rulerThickness leftward range that the elastic
    // scroll thread rubber-banded into (#178). Pinned by
    // testNoPhantomLeftwardScrollRange.
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
    ///
    /// The update mutates `lineStarts` in place: the kept prefix is never
    /// copied, and the typical typing edit replaces a same-sized middle
    /// slice, so the array is not reallocated per keystroke.
    mutating func applyEdit(in string: NSString, editedRange: NSRange, changeInLength delta: Int) {
        let length = string.length
        let editStart = min(editedRange.location, length)
        let editEnd = min(NSMaxRange(editedRange), length)

        // Whole-line bounds of the edit, in the new string.
        let rescanStart = string.lineRange(for: NSRange(location: editStart, length: 0)).location
        let rescanEnd = NSMaxRange(string.lineRange(for: NSRange(location: editEnd, length: 0)))

        // Starts strictly before the rescanned region keep their values:
        // their terminators are in untouched text. firstIndex is an upper
        // bound, so "greater than rescanStart - 1" means ">= rescanStart".
        let keptCount = firstIndex(in: lineStarts, greaterThan: rescanStart - 1)

        // Starts strictly after the rescanned region existed before the
        // edit at (position - delta), and their terminators are in
        // untouched text — shift them in place instead of re-reading them.
        let oldBoundary = rescanEnd - delta
        let firstShifted = firstIndex(in: lineStarts, greaterThan: oldBoundary)
        if delta != 0 {
            for i in firstShifted..<lineStarts.count {
                lineStarts[i] += delta
            }
        }

        // rescanStart is a line start in the new string by construction
        // (it came from lineRange), and it is not in the kept prefix.
        var rescanned = [rescanStart]
        rescanned.append(contentsOf: starts(in: string, from: rescanStart, upTo: rescanEnd))
        lineStarts.replaceSubrange(keptCount..<firstShifted, with: rescanned)
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

    /// The caret's line as of the last selection change, so caret moves
    /// within one line — the overwhelmingly common selection change —
    /// skip the repaint: nothing the gutter draws depends on the caret
    /// beyond which number is bold.
    private var currentLine = 1

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

        // Decorative for VoiceOver: the numbers duplicate position info the
        // text view already provides, and NSRulerView otherwise exposes an
        // empty, unlabeled AXRuler element in every editor window.
        setAccessibilityElement(false)

        lineIndex.rebuild(from: textView.string as NSString)
        currentLine = lineIndex.lineNumber(forCharacterAt: textView.selectedRange().location)
        updateThickness()

        // The gutter owns the text storage delegate slot; nothing else in
        // the app uses it. If that ever changes, the edits must be fanned
        // out, or the index here goes silently stale.
        textView.textStorage?.delegate = self

        // The gutter also owns the layout manager delegate slot (equally
        // unused elsewhere), for one callback: didCompleteLayout. On a
        // restored window the first draw can run before TextKit has laid
        // out the restored scroll position — the glyph query comes back
        // empty and the strip paints bare. The text view repaints itself
        // when background layout catches up; this is the only hook that
        // tells the gutter to do the same (#178).
        textView.layoutManager?.delegate = self

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
        // of leaving rulers a frame behind. The styling debounce also
        // enables this flag, but the gutter must not depend on an
        // unrelated feature for its repaints — set it here too.
        scrollView.contentView.postsBoundsChangedNotifications = true
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
    ///
    /// Only clears the delegate slot if this gutter still owns it: a
    /// stale gutter torn down after a replacement has claimed the slot
    /// must not unregister the live one — that failure mode is silent
    /// (numbers freeze, nothing crashes, no test fails) (#178).
    func tearDown() {
        if let storage = textView?.textStorage, storage.delegate === self {
            storage.delegate = nil
        }
        if let layoutManager = textView?.layoutManager, layoutManager.delegate === self {
            layoutManager.delegate = nil
        }
        NotificationCenter.default.removeObserver(self)
    }

    deinit {
        // Backstop for paths that skip tearDown. Both delegate slots are
        // assign, not weak — if either still points here after
        // deallocation, the next edit or layout pass is a use-after-free,
        // so clearing them is the part of teardown that cannot be
        // skipped (#178). Rulers deallocate on the main thread;
        // assumeIsolated asserts that rather than trusting it.
        NotificationCenter.default.removeObserver(self)
        MainActor.assumeIsolated {
            if let storage = textView?.textStorage, storage.delegate === self {
                storage.delegate = nil
            }
            if let layoutManager = textView?.layoutManager, layoutManager.delegate === self {
                layoutManager.delegate = nil
            }
        }
    }

    // The text view is flipped; declaring the gutter flipped too keeps
    // every converted y coordinate in the same top-down space.
    override var isFlipped: Bool { true }

    @objc private func selectionDidChange(_ notification: Notification) {
        if noteSelectionChanged() {
            needsDisplay = true
        }
    }

    /// Whether the latest selection change moved the caret to another
    /// line — the only selection change the gutter draws differently
    /// (the bold number). Internal so tests can pin the skip without
    /// going through needsDisplay, whose readback is unreliable in a
    /// headless window.
    func noteSelectionChanged() -> Bool {
        guard let textView = textView else { return false }
        let line = lineIndex.lineNumber(forCharacterAt: textView.selectedRange().location)
        if line == currentLine {
            return false
        }
        currentLine = line
        return true
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
    /// Named to stay clear of NSRulerView's `requiredThickness` property,
    /// which tile() reads for the live strip width.
    static func thickness(forLineCount lineCount: Int, font: NSFont) -> CGFloat {
        let digits = max(String(lineCount).count, 2)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = sample.size(withAttributes: [.font: font]).width
        return max(ceil(width) + horizontalPadding * 2, minimumThickness)
    }

    /// Re-derives the ruler width. Called when the digit count of the total
    /// changes and on font changes — not per draw, and never as a function
    /// of a full-document line scan (#103).
    func updateThickness() {
        let needed = Self.thickness(
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

        // Recomputed at paint time rather than trusting the cached
        // currentLine — draw is the source of truth for what's bold.
        let caretLine = lineIndex.lineNumber(forCharacterAt: textView.selectedRange().location)
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont(bold: false),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont(bold: true),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        for position in lineNumberPositions(in: textView.visibleRect) {
            let attributes = position.number == caretLine ? boldAttributes : regularAttributes
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

// MARK: - Layout manager delegate

// The conformance is isolated to the main actor (SE-0470): layout for an
// NSTextView happens on the main thread, and an isolated conformance
// states that statically instead of asserting it at runtime the way the
// previous @preconcurrency conformance did.
extension LineNumberGutterView: @MainActor NSLayoutManagerDelegate {
    // The one callback this delegate exists for: a restored window can
    // draw before layout reaches the restored scroll position, and the
    // glyph query in lineNumberPositions comes back empty. Each layout
    // chunk that completes gets the gutter another look; needsDisplay
    // coalesces, so a fully laid-out document costs nothing extra.
    func layoutManager(_ layoutManager: NSLayoutManager,
                       didCompleteLayoutFor textContainer: NSTextContainer?,
                       atEnd layoutFinishedFlag: Bool) {
        needsDisplay = true
    }
}

// MARK: - Text storage delegate

// Isolated conformance for the same reason as NSLayoutManagerDelegate
// above: every edit to an NSTextView's storage happens on the main thread.
extension LineNumberGutterView: @MainActor NSTextStorageDelegate {
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

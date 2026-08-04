//
//  LineNumberDrawing.swift
//  Jot
//
//  Line number drawing logic, used by EditorTextView to paint
//  line numbers in the gutter area created by textContainerInset.
//

import Cocoa

struct LineNumberDrawing {

    var lineNumberFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    var boldLineNumberFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)

    let gutterPadding: CGFloat = 8
    let minimumGutterWidth: CGFloat = 32

    var gutterBackgroundColor: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(white: 0.15, alpha: 1.0)
                } else {
                    return NSColor(white: 0.95, alpha: 1.0)
                }
            }
        } else {
            return NSColor(white: 0.95, alpha: 1.0)
        }
    }

    var lineNumberColor: NSColor {
        return .secondaryLabelColor
    }

    // MARK: - Font

    mutating func updateFont(_ editorFont: NSFont) {
        let gutterSize = max(editorFont.pointSize - 1, 9)
        lineNumberFont = NSFont.monospacedDigitSystemFont(ofSize: gutterSize, weight: .regular)
        boldLineNumberFont = NSFont.monospacedDigitSystemFont(ofSize: gutterSize, weight: .bold)
    }

    // MARK: - Width

    func gutterWidth(for text: NSString) -> CGFloat {
        let totalLines = max(countLines(in: text), 1)
        let digitCount = "\(totalLines)".count

        let sampleString = String(repeating: "8", count: digitCount) as NSString
        let size = sampleString.size(withAttributes: [.font: lineNumberFont])
        return max(size.width + gutterPadding * 2, minimumGutterWidth)
    }

    // MARK: - Drawing

    func draw(in textView: NSTextView, dirtyRect: NSRect) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let gutterWidth: CGFloat
        if let editorTextView = textView as? EditorTextView {
            gutterWidth = editorTextView.gutterInset
        } else {
            gutterWidth = textView.textContainerInset.width
        }

        // Only draw if there's a gutter to draw in
        guard gutterWidth > 0 else { return }

        // Fill only the gutter column, not the full dirty rect
        let gutterRect = NSRect(
            x: 0,
            y: dirtyRect.origin.y,
            width: gutterWidth,
            height: dirtyRect.height
        )
        let clippedGutter = gutterRect.intersection(dirtyRect)
        if !clippedGutter.isNull {
            gutterBackgroundColor.setFill()
            clippedGutter.fill()
        }

        // Draw right border of gutter
        NSColor.separatorColor.setStroke()
        let borderPath = NSBezierPath()
        borderPath.move(to: NSPoint(x: gutterWidth - 0.5, y: dirtyRect.minY))
        borderPath.line(to: NSPoint(x: gutterWidth - 0.5, y: dirtyRect.maxY))
        borderPath.lineWidth = 1.0
        borderPath.stroke()

        let string = textView.string as NSString
        let textLength = string.length

        // Current line for bold
        let selectedRange = textView.selectedRange()
        let currentLineRange = selectedRange.location <= textLength
            ? string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            : NSRange(location: 0, length: 0)

        // Calculate the visible range using the dirty rect
        // The dirty rect is in text view coordinates
        let containerOrigin = textView.textContainerOrigin
        let dirtyInContainer = NSRect(
            x: dirtyRect.origin.x - containerOrigin.x,
            y: dirtyRect.origin.y - containerOrigin.y,
            width: dirtyRect.width,
            height: dirtyRect.height
        )

        let glyphRange = layoutManager.glyphRange(forBoundingRect: dirtyInContainer, in: textContainer)
        if glyphRange.location == NSNotFound { return }

        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Count line number at start of visible range
        var lineNumber = 1
        var searchIndex = 0
        while searchIndex < charRange.location && searchIndex < textLength {
            let lineRange = string.lineRange(for: NSRange(location: searchIndex, length: 0))
            lineNumber += 1
            searchIndex = NSMaxRange(lineRange)
        }

        // Walk visible glyphs and draw numbers
        var glyphIndex = glyphRange.location
        let glyphEnd = NSMaxRange(glyphRange)

        while glyphIndex < glyphEnd {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let lineRange = string.lineRange(for: NSRange(location: charIndex, length: 0))

            let lineFragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: nil
            )

            // Line fragment rect is in text container coords; offset by container origin
            let yPosition = lineFragmentRect.minY + containerOrigin.y

            let isFirstFragment = (charIndex == lineRange.location)
            if isFirstFragment {
                let isCurrentLine = NSIntersectionRange(lineRange, currentLineRange).length > 0
                    || (lineRange.location == currentLineRange.location)

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: isCurrentLine ? boldLineNumberFont : lineNumberFont,
                    .foregroundColor: lineNumberColor,
                ]

                let numberString = "\(lineNumber)" as NSString
                let size = numberString.size(withAttributes: attrs)

                let drawPoint = NSPoint(
                    x: gutterWidth - size.width - gutterPadding,
                    y: yPosition + (lineFragmentRect.height - size.height) / 2.0
                )

                numberString.draw(at: drawPoint, withAttributes: attrs)
            }

            // Advance to next line fragment
            var nextGlyphRange = NSRange(location: NSNotFound, length: 0)
            layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &nextGlyphRange
            )

            let nextGlyphIndex = NSMaxRange(nextGlyphRange)
            if nextGlyphIndex <= glyphIndex {
                break
            }

            if nextGlyphIndex > 0, layoutManager.numberOfGlyphs > 0 {
                let nextCharIndex = layoutManager.characterIndexForGlyph(
                    at: min(nextGlyphIndex, layoutManager.numberOfGlyphs - 1)
                )
                if nextCharIndex >= NSMaxRange(lineRange) {
                    lineNumber += 1
                }
            }

            glyphIndex = nextGlyphIndex
        }
    }

    // MARK: - Helpers

    private func countLines(in string: NSString) -> Int {
        if string.length == 0 { return 1 }

        var count = 0
        var index = 0
        while index < string.length {
            let lineRange = string.lineRange(for: NSRange(location: index, length: 0))
            count += 1
            index = NSMaxRange(lineRange)
        }
        return count
    }
}

//
//  LineNumberRulerView.swift
//  Jot
//
//  Created by Brian on 1/13/24.
//

import Cocoa

class LineNumberRulerView: NSRulerView {
	var textView: NSTextView? {
		return clientView as? NSTextView
	}
	
	override func drawHashMarksAndLabels(in rect: NSRect) {
		guard let textView = textView,
			  let layoutManager = textView.layoutManager else { return }
		
		let relativePoint = convert(NSZeroPoint, from: textView)
		let lineNumberAttributes = [NSAttributedString.Key.font: textView.font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
									NSAttributedString.Key.foregroundColor: NSColor.gray] as [NSAttributedString.Key : Any]

		let drawLineNumber = { (lineNumberString: String, y: CGFloat) -> Void in
			let attributedString = NSAttributedString(string: lineNumberString, attributes: lineNumberAttributes)
			attributedString.draw(at: NSPoint(x: 0, y: relativePoint.y + y))
		}
		
		let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textView.textContainer!)
		let firstVisibleGlyphCharacterIndex = layoutManager.characterIndexForGlyph(at: visibleGlyphRange.location)
		
		var lineNumber = (textView.string as NSString).substring(to: firstVisibleGlyphCharacterIndex).components(separatedBy: "\n").count
		
		var glyphIndexForStringLine = visibleGlyphRange.location
		
		// Go through each line in the string.
		while glyphIndexForStringLine < NSMaxRange(visibleGlyphRange) {
			// Range of current line in the string.
			let characterRangeForStringLine = (textView.string as NSString).lineRange(for: NSRange(location: layoutManager.characterIndexForGlyph(at: glyphIndexForStringLine), length: 0))
			let glyphRangeForStringLine = layoutManager.glyphRange(forCharacterRange: characterRangeForStringLine, actualCharacterRange: nil)
			
			var glyphIndexForGlyphLine = glyphIndexForStringLine
			var glyphLineCount = 0
			
			while glyphIndexForGlyphLine < NSMaxRange(glyphRangeForStringLine) {
				// See if the current line in the string spread across several lines of glyphs
				var effectiveRange = NSMakeRange(0, 0)
				// Range of current "line of glyphs". If a line is wrapped, then it might be represented by multiple "lines of glyphs"
				let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndexForGlyphLine, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
				
				if glyphLineCount > 0 {
					drawLineNumber("•", lineRect.minY)
				} else {
					drawLineNumber("\(lineNumber)", lineRect.minY)
				}
				
				// Move to next glyph line
				glyphLineCount += 1
				glyphIndexForGlyphLine = NSMaxRange(effectiveRange)
			}
			
			glyphIndexForStringLine = NSMaxRange(glyphRangeForStringLine)
			lineNumber += 1
		}
	}
}

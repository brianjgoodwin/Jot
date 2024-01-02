//
//  MarkdownFormatter.swift
//  Jot
//
//  Created by Brian on 12/24/23.
//

import Cocoa

class MarkdownFormatter {
	// Properties related to formatting
//	var baseFontSize: CGFloat
	
	// Initialization
	init() {
//		self.baseFontSize = baseFontSize
	}
	
	// MARK: - Markdown Formatting
	func applyMarkdownFormatting(to textStorage: NSTextStorage, baseFont: NSFont) {
		let entireRange = NSRange(location: 0, length: textStorage.length)
		
		// Define regular expressions for Markdown patterns
		let header1Regex = try? NSRegularExpression(pattern: "^# .*$", options: .anchorsMatchLines)
		
		// Calculate the font size for header1
		let headerFont = NSFont(descriptor: baseFont.fontDescriptor, size: baseFont.pointSize * 1.5) ?? baseFont
		
		if let header1Regex = header1Regex {
			applyStyle(with: header1Regex, to: textStorage, using: headerFont, range: entireRange)
		}
	}
	
	func applyHeaderStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, using font: NSFont, range: NSRange) {
		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			if let matchRange = match?.range {
				textStorage.addAttribute(.font, value: font, range: matchRange)
			}
		}
	}
	
	func applyStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, using font: NSFont, range: NSRange, backgroundColor: NSColor? = nil) {
		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			if let matchRange = match?.range {
				textStorage.addAttribute(.font, value: font, range: matchRange)
				if let bgColor = backgroundColor {
					textStorage.addAttribute(.backgroundColor, value: bgColor, range: matchRange)
				}
			}
		}
	}
	
	func removeMarkdownFormatting(from textStorage: NSTextStorage, baseFont: NSFont) {
		let entireRange = NSRange(location: 0, length: textStorage.length)
		textStorage.removeAttribute(.font, range: entireRange)
		textStorage.addAttribute(.font, value: baseFont, range: entireRange)
	}

	
	// Utility Functions
	func font(forName fontName: String, size: Float) -> NSFont {
		// Use the provided size instead of the system default size
		let fontSize = CGFloat(size)
		switch fontName {
		case "SystemMono":
			return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
		case "Serif":
			return NSFont(name: "New York", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
		default:
			return NSFont.systemFont(ofSize: fontSize)
		}
	}
}

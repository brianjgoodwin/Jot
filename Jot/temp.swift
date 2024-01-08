////
////  temp.swift
////  Jot
////
////  Created by Brian on 1/1/24.
////
//
//// note to self - this is the current state of `MarkdownFormatter` on 1/1/24
//
////
////  MarkdownFormatter.swift
////  Jot
////
////  Created by Brian on 12/24/23.
////
//
//import Cocoa
//
//class MarkdownFormatter {
//	// Properties related to formatting
//	var currentZoomLevel: CGFloat // zoom level - delete
//	var baseFontSize: CGFloat
//
//	// Initialization
//	init(zoomLevel: CGFloat, baseFontSize: CGFloat) {
//		self.currentZoomLevel = zoomLevel
//		self.baseFontSize = baseFontSize
//	}
//
//	// MARK: - Markdown Formatting
//	/// move to formatting -  applyMarkdownFormatting()
//	func applyMarkdownFormatting(to textStorage: NSTextStorage, zoomLevel: CGFloat) {
//		let entireRange = NSRange(location: 0, length: textStorage.length)
//		let baseFont = FontManager.shared.currentFont() // Get the current font based on user preferences
////		let entireRange = NSRange(location: 0, length: textStorage.length)
//		
//		// MARK: - Revisit this | Remove formatting
//		//		At one point, this removed markdown formatting when switching back to plain text. It caused conflicts with user-selectable fonts. Removed and it seems to be functioning as desired. Marking this for review later in case it introduces problems down the line.
//		// Remove any previous formatting
//		//		textStorage.removeAttribute(.font, range: entireRange)
//		//		textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: entireRange)
//		
//		// Define regular expressions for Markdown patterns
//		let header1Regex = try! NSRegularExpression(pattern: "^# .*$", options: .anchorsMatchLines)
//		let header2Regex = try! NSRegularExpression(pattern: "^## .*$", options: .anchorsMatchLines)
//		let header3Regex = try! NSRegularExpression(pattern: "^### .*$", options: .anchorsMatchLines)
//		let header4Regex = try! NSRegularExpression(pattern: "^#### .*$", options: .anchorsMatchLines)
//		let boldRegex = try! NSRegularExpression(pattern: "\\*\\*.*?\\*\\*", options: [])
//		let italicRegex = try! NSRegularExpression(pattern: "(\\*|_)(.*?)(\\1)", options: [])
//		let linkRegex = try! NSRegularExpression(pattern: "\\[([^\\[]+)\\]\\(([^\\)]+)\\)", options: [])
//		//let codeInlineRegex = try! NSRegularExpression(pattern: "`(.*?)`", options: [])
//		let codeBlockRegex = try! NSRegularExpression(pattern: "```\\s*([^`]+)\\s*```", options: [])
//		let unorderedListRegex = try! NSRegularExpression(pattern: "^[\\*\\+\\-]\\s", options: .anchorsMatchLines)
//		let orderedListRegex = try! NSRegularExpression(pattern: "^\\d+\\.\\s", options: .anchorsMatchLines)
//		let horizontalDividerRegex = try! NSRegularExpression(pattern: "^(---|\\*\\*\\*|___)$", options: .anchorsMatchLines)
//		let blockQuoteRegex = try! NSRegularExpression(pattern: "^>\\s", options: .anchorsMatchLines)
//		
//		// Apply header style
//		//		let headerFontSize = baseFontSize * 2 * currentZoomLevel // Example calculation
//		//		applyStyle(with: headerRegex, to: textStorage, using: NSFont.boldSystemFont(ofSize: headerFontSize), range: entireRange)
//		
//		let headerFont = NSFont(descriptor: baseFont.fontDescriptor, size: baseFont.pointSize * 1.5) ?? baseFont
//		let header2Font = NSFont(descriptor: baseFont.fontDescriptor, size: baseFont.pointSize * 1.4) ?? baseFont
//		let header3Font = NSFont(descriptor: baseFont.fontDescriptor, size: baseFont.pointSize * 1.3) ?? baseFont
//
//		applyStyle(with: header1Regex, to: textStorage, using: headerFont, range: entireRange)
//		applyStyle(with: header2Regex, to: textStorage, using: header2Font, range: entireRange)
//		applyStyle(with: header3Regex, to: textStorage, using: header3Font, range: entireRange)
//		
//		// Apply header styles
////		applyHeaderStyle(with: header1Regex, to: textStorage, using: NSFont.boldSystemFont(ofSize: 24 * currentZoomLevel), range: entireRange)
////		applyHeaderStyle(with: header2Regex, to: textStorage, using: NSFont.boldSystemFont(ofSize: 20 * currentZoomLevel), range: entireRange)
////		applyHeaderStyle(with: header3Regex, to: textStorage, using: NSFont.boldSystemFont(ofSize: 18 * currentZoomLevel), range: entireRange)
//		applyHeaderStyle(with: header4Regex, to: textStorage, using: NSFont.boldSystemFont(ofSize: 16 * currentZoomLevel), range: entireRange)
//		
//		// Apply bold style
//		applyStyle(with: boldRegex, to: textStorage, using: NSFont.boldSystemFont(ofSize: 12), range: entireRange)
//		
//		// Apply italic style
//		applyStyle(with: italicRegex, to: textStorage, using: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 12), toHaveTrait: .italicFontMask), range: entireRange)
//		
//		// Apply link style (this example just changes color, but you might want to do more)
//		applyLinkStyle(with: linkRegex, to: textStorage, range: entireRange)
//		
//		// Apply inline code style
//		//		applyStyle(with: codeInlineRegex, to: textStorage, using: NSFont.userFixedPitchFont(ofSize: 12) ?? NSFont.systemFont(ofSize: 12), range: entireRange, backgroundColor: NSColor.systemGray)
//		
//		// Apply code block style
//		applyStyle(with: codeBlockRegex, to: textStorage, using: NSFont.userFixedPitchFont(ofSize: 12) ?? NSFont.systemFont(ofSize: 12), range: entireRange, backgroundColor: NSColor.systemGray)
//		
//		// Apply unordered list style
//		applyListStyle(with: unorderedListRegex, to: textStorage, range: entireRange)
//		
//		// Apply ordered list style
//		applyListStyle(with: orderedListRegex, to: textStorage, range: entireRange)
//		
//		// Apply horizontal divider style
//		applyDividerStyle(with: horizontalDividerRegex, to: textStorage, range: entireRange)
//		
//		// Apply block quote style
//		applyBlockQuoteStyle(with: blockQuoteRegex, to: textStorage, range: entireRange)
//		
//		// Apply code block style
//		applyCodeBlockStyle(with: codeBlockRegex, to: textStorage, range: entireRange)
//	} /// move to formatting -  applyMarkdownFormatting()
//	
//	/// move to formatting -  applyHeaderStyle()
//	func applyHeaderStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, using font: NSFont, range: NSRange) {
//		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
//			if let matchRange = match?.range {
//				textStorage.addAttribute(.font, value: font, range: matchRange)
//			}
//		}
//	}/// move to formatting -  applyHeaderStyle()
//	
//	/// move to formatting -  applyStyle()
//	func applyStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, using font: NSFont, range: NSRange, backgroundColor: NSColor? = nil) {
//		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
//			if let matchRange = match?.range {
//				textStorage.addAttribute(.font, value: font, range: matchRange)
//				if let bgColor = backgroundColor {
//					textStorage.addAttribute(.backgroundColor, value: bgColor, range: matchRange)
//				}
//			}
//		}
//	}/// move to formatting -  applyStyle()
//	
//	/// move to formatting -  applyListStyle()
//	// Example of a helper function for list style
//	func applyListStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, range: NSRange) {
//		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
//			if let matchRange = match?.range {
//				textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: baseFontSize * currentZoomLevel), range: matchRange)
//				// Add additional styling like bullets or numbers if necessary
//			}
//		}
//	}/// move to formatting -  applyListStyle()
//	
//	/// move to formatting -  applyLinkStyle()
//	func applyLinkStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, range: NSRange) {
//		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
//			if let matchRange = match?.range(at: 1) { // Change to range(at: 2) to style the URL instead
//				textStorage.addAttribute(.foregroundColor, value: NSColor.blue, range: matchRange)
//				textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
//			}
//		}
//	}/// move to formatting -  applyLinkStyle()
//	
//	/// move to formatting -  applyDividerStyle()
//	// Similar helper functions for divider, block quote, and code block styles...
//	func applyDividerStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, range: NSRange) {
//		// Apply horizontal divider style
//	}/// move to formatting -  applyDividerStyle()
//	
//	/// move to formatting -  applyBlockQuoteStyle()
//	func applyBlockQuoteStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, range: NSRange) {
//		// Apply block quote style
//	}/// move to formatting -  applyBlockQuoteStyle()
//	
//	/// move to formatting -  applyCodeBlockStyle()
//	func applyCodeBlockStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, range: NSRange) {
//		// Apply code block style
//	}/// move to formatting -  applyCodeBlockStyle()
//	
//	/// move to formatting -  removeMarkdownFormatting()
//	func removeMarkdownFormatting(from textStorage: NSTextStorage) {
//		let entireRange = NSRange(location: 0, length: textStorage.length)
//		// Remove any Markdown formatting
//		textStorage.removeAttribute(.font, range: entireRange)
//		// Reset to the default style based on user preferences or whatever you prefer
//		textStorage.addAttribute(.font, value: font(forName: "SystemDefault"), range: entireRange)
//	}/// move to formatting -  removeMarkdownFormatting()
//
//	// Additional functions (applyHeaderStyle, applyStyle, applyListStyle, etc.)
//	// ... (moved from ViewController)
//
//	// Utility Functions
//	/// move to formatting -  func font(forName fontName: String)
//	func font(forName fontName: String) -> NSFont {
//		let systemFontSize = NSFont.systemFontSize
//		switch fontName {
//		case "SystemMono":
//			return NSFont.monospacedSystemFont(ofSize: systemFontSize, weight: .regular)
//		case "Serif":
//			return NSFont(name: "New York", size: systemFontSize) ?? NSFont.systemFont(ofSize: systemFontSize)
//		default:
//			return NSFont.systemFont(ofSize: systemFontSize)
//		}
//	}/// move to formatting -  func font(forName fontName: String)
//}
//

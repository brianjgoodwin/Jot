//
//  MarkdownProcessor.swift
//  Jot
//
//  Created by Brian on 1/18/24.
//

import Cocoa

class MarkdownProcessor {

	static func applyMarkdownStyling(to textView: NSTextView, using selectedFont: NSFont, range: NSRange? = nil) {
		let stylingRange = range ?? NSRange(location: 0, length: textView.textStorage?.length ?? 0)
		
		applyHeadings(to: textView, using: selectedFont, range: stylingRange)
		applyItalic(to: textView, using: selectedFont, range: stylingRange)
		applyBold(to: textView, using: selectedFont, range: stylingRange)
		applyCode(to: textView)
		applyLinks(to: textView)
		applyStrikethrough(to: textView)
		applyListStyling(to: textView)

		// ... Add other markdown styling functions here
	}

	private static func applyHeadings(to textView: NSTextView, using selectedFont: NSFont, range: NSRange) {
		guard let textStorage = textView.textStorage else { return }

		let headerPattern = "^(#{1,6})\\s+(.*)$" // Pattern for headers 1 through 6
		let regex = try? NSRegularExpression(pattern: headerPattern, options: [.anchorsMatchLines])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range,
				  let headerSymbolRange = match?.range(at: 1),
				  let headerTextRange = match?.range(at: 2) else { return }

			// Apply gray color to '#'
			textStorage.addAttribute(.foregroundColor, value: NSColor.gray, range: headerSymbolRange)

			// Apply bold style to the header text
			let boldFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: .boldFontMask)
			textStorage.addAttribute(.font, value: boldFont, range: headerTextRange)
		}
	}

	private static func applyBold(to textView: NSTextView, using selectedFont: NSFont, range: NSRange) {
		let boldPatterns = ["\\*\\*(.+?)\\*\\*", "__(.+?)__"] // Bold ** and __
		for pattern in boldPatterns {
			applyStyle(with: pattern, trait: .boldFontMask, in: textView.textStorage, using: selectedFont, range: range)
		}
	}

	private static func applyItalic(to textView: NSTextView, using selectedFont: NSFont, range: NSRange) {
		let italicPatterns = ["\\*(.+?)\\*", "_(.+?)_"] // Italic * and _
		for pattern in italicPatterns {
			applyStyle(with: pattern, trait: .italicFontMask, in: textView.textStorage, using: selectedFont, range: range)
		}
	}
	
	private static func applyCode(to textView: NSTextView) {
			guard let textStorage = textView.textStorage else { return }

			// Inline code pattern
			let inlineCodePattern = "`([^`]+)`"
			applyCodeStyle(with: inlineCodePattern, isBlock: false, in: textStorage)

			// Code block pattern
			let blockCodePattern = "```\\s*\\n?(.*?)\\n?```"
			applyCodeStyle(with: blockCodePattern, isBlock: true, in: textStorage)
		}
	
	private static func applyCodeStyle(with pattern: String, isBlock: Bool, in textStorage: NSTextStorage) {
		let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
			guard let matchRange = match?.range else { return }

			// Style attributes for code
			let codeAttributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.darkGray,
				.backgroundColor: NSColor(white: 0.95, alpha: 1.0) // Light gray background
			]
			
			// Apply style to the entire match range for blocks
			if isBlock {
				textStorage.addAttributes(codeAttributes, range: matchRange)
			} else { // For inline code, apply only to the code content
				if let codeRange = match?.range(at: 1) {
					textStorage.addAttributes(codeAttributes, range: codeRange)
				}
			}
		}
	}

	private static func applyLinks(to textView: NSTextView) {
		guard let textStorage = textView.textStorage else { return }

		let linkPattern = "\\[([^\\]]+)\\]\\(([^\\)]+)\\)" // Pattern for Markdown links
		let regex = try? NSRegularExpression(pattern: linkPattern, options: [])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
			guard let matchRange = match?.range,
				  let linkTextRange = match?.range(at: 1),
				  let urlRange = match?.range(at: 2) else { return }

			// Style the link text
			let linkAttributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.blue,
				.underlineStyle: NSUnderlineStyle.single.rawValue
			]
			textStorage.addAttributes(linkAttributes, range: linkTextRange)

			// Optionally, handle the URL itself
//			if let urlString = (textStorage.string as NSString).substring(with: urlRange).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
//			   let url = URL(string: urlString) {
//				textStorage.addAttribute(.link, value: url, range: linkTextRange)
//			}
		}
	}
	
	private static func applyStrikethrough(to textView: NSTextView) {
		guard let textStorage = textView.textStorage else { return }

		let strikethroughPattern = "~~(.*?)~~" // Pattern for strikethrough
		let regex = try? NSRegularExpression(pattern: strikethroughPattern, options: [])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
			guard let matchRange = match?.range,
				  let textRange = match?.range(at: 1) else { return }

			// Apply strikethrough style
			let strikethroughAttributes: [NSAttributedString.Key: Any] = [
				.strikethroughStyle: NSUnderlineStyle.single.rawValue
			]
			textStorage.addAttributes(strikethroughAttributes, range: textRange)

			// Optional: Apply gray color to Markdown symbols
			let symbolRanges = [
				NSRange(location: matchRange.location, length: 2), // Opening ~~
				NSRange(location: NSMaxRange(matchRange) - 2, length: 2) // Closing ~~
			]
			for symbolRange in symbolRanges {
				textStorage.addAttribute(.foregroundColor, value: NSColor.gray, range: symbolRange)
			}
		}
	}
	
	static func applyListStyling(to textView: NSTextView) {
		guard let textStorage = textView.textStorage else { return }

		applyUnorderedListStyling(in: textStorage)
		applyOrderedListStyling(in: textStorage)
	}

	private static func applyUnorderedListStyling(in textStorage: NSTextStorage) {
		let unorderedListPattern = "^[-+*]\\s+"
		applyListStyle(with: unorderedListPattern, in: textStorage)
	}

	private static func applyOrderedListStyling(in textStorage: NSTextStorage) {
		let orderedListPattern = "^\\d+\\.\\s+"
		applyListStyle(with: orderedListPattern, in: textStorage)
	}

	private static func applyListStyle(with pattern: String, in textStorage: NSTextStorage) {
		let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
			guard let matchRange = match?.range else { return }

			// Styling for the list markers
			let attributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.gray, // Example: Gray color for list markers
				// Add any other styling you wish to apply to list markers
			]
			textStorage.addAttributes(attributes, range: matchRange)
		}
	}

	// ... Add other markdown styling functions like applyLists, applyBlockquotes, etc.

	private static func applyStyle(with pattern: String, trait: NSFontTraitMask, in textStorage: NSTextStorage?, using selectedFont: NSFont, range: NSRange) {
		guard let textStorage = textStorage else { return }
		let regex = try? NSRegularExpression(pattern: pattern, options: [])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range else { return }

			// Apply gray color to Markdown symbols
			let symbolLength = (trait == .boldFontMask) ? 2 : 1
			let symbolRanges = [
				NSRange(location: matchRange.location, length: symbolLength),
				NSRange(location: NSMaxRange(matchRange) - symbolLength, length: symbolLength)
			]
			for symbolRange in symbolRanges {
				textStorage.addAttribute(.foregroundColor, value: NSColor.gray, range: symbolRange)
			}

			// Apply font trait to the text
			let textRange = NSRange(location: matchRange.location + symbolLength, length: matchRange.length - symbolLength * 2)
			let modifiedFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: trait)
			textStorage.addAttribute(.font, value: modifiedFont, range: textRange)
		}
	}

	// ... Additional utility functions and private helpers as needed
}

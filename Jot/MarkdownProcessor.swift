//
//  MarkdownProcessor.swift
//  Jot
//
//  Created by Brian on 1/18/24.
//

import Cocoa

class MarkdownProcessor {

	static func applyMarkdownStyling(to textView: NSTextView, using selectedFont: NSFont) {
		applyHeadings(to: textView, using: selectedFont)
		applyParagraphs(to: textView)
		applyLineBreaks(to: textView)
		applyEmphasis(to: textView, using: selectedFont)
		applyBlockquotes(to: textView)
		applyLists(to: textView)
		applyCode(to: textView)
		applyHorizontalRules(to: textView)
		applyLinks(to: textView)
		applyImages(to: textView)
		applyEscapingCharacters(to: textView)
		applyStrikethrough(to: textView)
	}

	private static func applyHeadings(to textView: NSTextView, using selectedFont: NSFont) {
		guard let textStorage = textView.textStorage else { return }

		let headerPattern = "^(#{1,6})\\s+(.*)$" // Pattern for headers 1 through 6
		let regex = try? NSRegularExpression(pattern: headerPattern, options: [.anchorsMatchLines])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
			guard let matchRange = match?.range,
				  let headerSymbolRange = match?.range(at: 1),
				  let headerTextRange = match?.range(at: 2) else { return }

			// Apply gray color to '#'
			textStorage.addAttribute(.foregroundColor, value: NSColor.gray, range: headerSymbolRange)

			// Apply bold style to the header text
			let boldFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: .boldFontMask)
			textStorage.addAttribute(.font, value: boldFont, range: headerTextRange)

			// Optional: Adjust font size based on the header level
//			let headerLevel = headerSymbolRange.length // Number of '#' symbols
//			let fontSizeAdjustment = CGFloat(6 - headerLevel) * 2 // Example of size adjustment
//			let headerFontSize = max(selectedFont.pointSize + fontSizeAdjustment, selectedFont.pointSize)
//			let headerFont = NSFontManager.shared.convert(selectedFont, toSize: headerFontSize)
//			textStorage.addAttribute(.font, value: headerFont, range: headerTextRange)
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
	
	private static func applyParagraphs(to textView: NSTextView) {
		// Logic for styling paragraphs
	}

	private static func applyLineBreaks(to textView: NSTextView) {
		// Logic for styling line breaks
	}

	private static func applyEmphasis(to textView: NSTextView, using selectedFont: NSFont) {
		guard let textStorage = textView.textStorage else { return }

		// Patterns for bold and italic
		let emphasisPatterns = [
			("\\*\\*(.+?)\\*\\*", NSFontTraitMask.boldFontMask), // Bold **
			("__.+?__", .boldFontMask),                          // Bold __
			("\\*(.+?)\\*", .italicFontMask),                    // Italic *
			("_.+?_", .italicFontMask)                           // Italic _
		]

		for (pattern, trait) in emphasisPatterns {
			applyStyle(with: pattern, trait: trait, in: textStorage, using: selectedFont)
		}
	}
	
	private static func applyStyle(with pattern: String, trait: NSFontTraitMask, in textStorage: NSTextStorage, using selectedFont: NSFont) {
		let regex = try? NSRegularExpression(pattern: pattern, options: [])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
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

	private static func applyBlockquotes(to textView: NSTextView) {
			guard let textStorage = textView.textStorage else { return }

			let blockquotePattern = "^>\\s?(.*)" // Pattern for block quotes
			let regex = try? NSRegularExpression(pattern: blockquotePattern, options: [.anchorsMatchLines])

			regex?.enumerateMatches(in: textStorage.string, options: [], range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
				guard let matchRange = match?.range,
					  let quoteTextRange = match?.range(at: 1) else { return }

				// Apply blockquote style
				let blockquoteAttributes: [NSAttributedString.Key: Any] = [
					.foregroundColor: NSColor.darkGray, // Change color to dark gray
					.paragraphStyle: createBlockquoteParagraphStyle() // Apply paragraph styling
				]
				textStorage.addAttributes(blockquoteAttributes, range: quoteTextRange)
			}
		}

		private static func createBlockquoteParagraphStyle() -> NSParagraphStyle {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.firstLineHeadIndent = 20.0 // Indent for the first line
			paragraphStyle.headIndent = 20.0 // Indent for subsequent lines
			// Add any other styling you wish to apply to blockquotes
			return paragraphStyle
		}


	private static func applyLists(to textView: NSTextView) {
		// Logic for styling lists (ordered and unordered)
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
				guard let matchRange = match?.range,
					  let codeRange = isBlock ? match?.range(at: 1) : match?.range else { return }

				// Style attributes for code
				let codeAttributes: [NSAttributedString.Key: Any] = [
					.foregroundColor: NSColor.darkGray,
//					.font: NSFont.userFixedPitchFont(ofSize: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
					.backgroundColor: NSColor(white: 0.95, alpha: 1.0) // Light gray background
				]
				textStorage.addAttributes(codeAttributes, range: codeRange)
			}
		}


	private static func applyHorizontalRules(to textView: NSTextView) {
		guard let textStorage = textView.textStorage else { return }

		let horizontalRulePattern = "^(---|\\*\\*\\*|___)\\s*$" // Pattern for horizontal rules
		let regex = try? NSRegularExpression(pattern: horizontalRulePattern, options: [.anchorsMatchLines])

		regex?.enumerateMatches(in: textStorage.string, options: [], range: NSRange(location: 0, length: textStorage.length)) { match, _, _ in
			guard let matchRange = match?.range else { return }

			// Apply horizontal rule style
			let horizontalRuleAttributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.darkGray,
//				.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
//				.strikethroughColor: NSColor.separatorColor
			]
			textStorage.addAttributes(horizontalRuleAttributes, range: matchRange)

			// Replace the characters with a space or a special character to show the rule
//			textStorage.replaceCharacters(in: matchRange, with: "—") // Long dash as an example
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
			if let urlString = (textStorage.string as NSString).substring(with: urlRange).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
			   let url = URL(string: urlString) {
				textStorage.addAttribute(.link, value: url, range: linkTextRange)
			}
		}
	}

	private static func applyImages(to textView: NSTextView) {
		// Logic for styling image references
	}

	private static func applyEscapingCharacters(to textView: NSTextView) {
		// Logic for handling escaping characters
	}

	// Additional helper methods as needed...
}

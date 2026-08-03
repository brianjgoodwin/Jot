//
//  MarkdownProcessor.swift
//  Jot
//
//  Created by Brian on 1/18/24.
//

import Cocoa

// Caseless enum acts as a namespace — prevents instantiation.
@MainActor
enum MarkdownProcessor {

	// MARK: - Compiled Regexes (once per process lifetime)

	private static let headingRegex        = try! NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)$",               options: [.anchorsMatchLines])
	private static let boldItalicRegex      = try! NSRegularExpression(pattern: "\\*\\*\\*([^*\\n]+)\\*\\*\\*",    options: [])
	private static let boldAsteriskRegex   = try! NSRegularExpression(pattern: "(?<!\\*)\\*\\*([^*\\n]+)\\*\\*(?!\\*)", options: [])
	private static let boldUnderscoreRegex = try! NSRegularExpression(pattern: "__([^\\s_](?:[^_\\n]*[^\\s_])?)__", options: [])
	// Improved italic patterns: opening delimiter must not be preceded by *, closing must not be followed by *.
	// Content excludes * and newlines, preventing runaway matches across bold markers.
	private static let italicAsteriskRegex   = try! NSRegularExpression(pattern: "(?<![*])\\*([^*\\n]+)\\*(?![*])",  options: [])
	// Underscore italic: word-boundary aware so file_names_like_this don't trigger it.
	private static let italicUnderscoreRegex = try! NSRegularExpression(pattern: "(?<!\\w)_([^_\\n]+)_(?!\\w)",      options: [])
	private static let inlineCodeRegex     = try! NSRegularExpression(pattern: "`([^`\\n]+)`",                      options: [])
	private static let codeBlockRegex      = try! NSRegularExpression(pattern: "```[^`\\n]*\\n([\\s\\S]*?)\\n?```", options: [])
	private static let linkRegex           = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)",      options: [])
	private static let strikethroughRegex  = try! NSRegularExpression(pattern: "~~([^~\\n]+)~~",                    options: [])
	private static let unorderedListRegex  = try! NSRegularExpression(pattern: "^[-+*]\\s+",                        options: [.anchorsMatchLines])
	private static let orderedListRegex    = try! NSRegularExpression(pattern: "^\\d+\\.\\s+",                      options: [.anchorsMatchLines])
	private static let blockquoteRegex     = try! NSRegularExpression(pattern: "^(>[ \\t]*)(.+)$",                  options: [.anchorsMatchLines])
	private static let horizontalRuleRegex = try! NSRegularExpression(pattern: "^([-*_]{3,})[ \\t]*$",             options: [.anchorsMatchLines])
	// Table: lines containing pipe delimiters. Separator rows (|---|---|) get distinct styling.
	private static let tableRowRegex       = try! NSRegularExpression(pattern: "^\\|(.+\\|)+\\s*$",               options: [.anchorsMatchLines])
	private static let tablePipeRegex      = try! NSRegularExpression(pattern: "\\|",                              options: [])
	private static let tableSeparatorRegex = try! NSRegularExpression(pattern: "^\\|([\\s:]*-{3,}[\\s:]*\\|)+\\s*$", options: [.anchorsMatchLines])

	// MARK: - Adaptive code-block background

	private static let codeBackground = NSColor(name: nil) { appearance in
		appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
			? NSColor(white: 0.15, alpha: 1)
			: NSColor(white: 0.94, alpha: 1)
	}

	// MARK: - Public entry point

	static func applyMarkdownStyling(to textView: NSTextView, using selectedFont: NSFont, range: NSRange? = nil) {
		guard let textStorage = textView.textStorage else { return }
		let stylingRange = range ?? NSRange(location: 0, length: textStorage.length)

		textStorage.beginEditing()

		// Reset pass — removes stale attributes so deleted syntax doesn't leave
		// behind bold, colour, background, or strikethrough from a previous pass.
		// Background is always cleared on the full document because code blocks
		// can start before the dirty range.
		let fullRange = NSRange(location: 0, length: textStorage.length)
		textStorage.addAttribute(.font, value: selectedFont, range: stylingRange)
		textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: stylingRange)
		textStorage.removeAttribute(.backgroundColor, range: fullRange)
		textStorage.removeAttribute(.strikethroughStyle, range: stylingRange)
		textStorage.removeAttribute(.underlineStyle, range: stylingRange)
		textStorage.removeAttribute(.link, range: stylingRange)

		// Order matters:
		// - Bold+italic (***) first so the triple-asterisk delimiter is
		//   consumed before bold or italic patterns see it.
		// - Bold before italic so the italic pattern can safely exclude *
		//   without missing bold+italic combos.
		// - Horizontal rules AFTER bold/italic because `***` is valid
		//   bold-italic syntax. If horizontal rules ran first, `***text***`
		//   would be styled as a rule instead of bold-italic.
		applyHeadings(to: textStorage, using: selectedFont, range: stylingRange)
		applyBoldItalic(to: textStorage, using: selectedFont, range: stylingRange)
		applyBold(to: textStorage, using: selectedFont, range: stylingRange)
		applyItalic(to: textStorage, using: selectedFont, range: stylingRange)
		applyCode(to: textStorage, range: stylingRange)
		applyLinks(to: textStorage, range: stylingRange)
		applyStrikethrough(to: textStorage, range: stylingRange)
		applyListStyling(to: textStorage, range: stylingRange)
		applyBlockquotes(to: textStorage, range: stylingRange)
		applyHorizontalRules(to: textStorage, range: stylingRange)
		applyTables(to: textStorage, using: selectedFont, range: stylingRange)

		textStorage.endEditing()
	}

	// MARK: - Headings

	private static func applyHeadings(to textStorage: NSTextStorage, using selectedFont: NSFont, range: NSRange) {
		let boldFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: .boldFontMask)

		headingRegex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			guard let symbolRange = match?.range(at: 1),
				  let textRange   = match?.range(at: 2) else { return }

			textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: symbolRange)
			textStorage.addAttribute(.font, value: boldFont, range: textRange)
		}
	}

	// MARK: - Bold + Italic

	private static func applyBoldItalic(to textStorage: NSTextStorage, using selectedFont: NSFont, range: NSRange) {
		let boldItalicFont = NSFontManager.shared.convert(
			NSFontManager.shared.convert(selectedFont, toHaveTrait: .boldFontMask),
			toHaveTrait: .italicFontMask
		)
		applyInlineStyle(with: boldItalicRegex, font: boldItalicFont, symbolLength: 3, in: textStorage, range: range)
	}

	// MARK: - Bold

	private static func applyBold(to textStorage: NSTextStorage, using selectedFont: NSFont, range: NSRange) {
		let boldFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: .boldFontMask)
		applyInlineStyle(with: boldAsteriskRegex,   font: boldFont, symbolLength: 2, in: textStorage, range: range)
		applyInlineStyle(with: boldUnderscoreRegex, font: boldFont, symbolLength: 2, in: textStorage, range: range)
	}

	// MARK: - Italic

	private static func applyItalic(to textStorage: NSTextStorage, using selectedFont: NSFont, range: NSRange) {
		let italicFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: .italicFontMask)
		applyInlineStyle(with: italicAsteriskRegex,   font: italicFont, symbolLength: 1, in: textStorage, range: range)
		applyInlineStyle(with: italicUnderscoreRegex, font: italicFont, symbolLength: 1, in: textStorage, range: range)
	}

	// MARK: - Code

	private static func applyCode(to textStorage: NSTextStorage, range: NSRange) {
		let codeAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.secondaryLabelColor,
			.backgroundColor: codeBackground,
		]

		// Code blocks can start before the dirty range, so both inline and
		// block code scan the full document. Backgrounds are already cleared
		// in the reset pass above.
		let fullRange = NSRange(location: 0, length: textStorage.length)

		inlineCodeRegex.enumerateMatches(in: textStorage.string, options: [], range: fullRange) { match, _, _ in
			guard let codeRange = match?.range(at: 1) else { return }
			textStorage.addAttributes(codeAttributes, range: codeRange)
		}

		codeBlockRegex.enumerateMatches(in: textStorage.string, options: [], range: fullRange) { match, _, _ in
			guard let matchRange = match?.range else { return }
			textStorage.addAttributes(codeAttributes, range: matchRange)
		}
	}

	// MARK: - Links

	private static func applyLinks(to textStorage: NSTextStorage, range: NSRange) {
		linkRegex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			guard let matchRange    = match?.range,
				  let linkTextRange = match?.range(at: 1) else { return }

			let bracketsRange     = NSRange(location: matchRange.location,           length: linkTextRange.location - matchRange.location)
			let parenthesesRange  = NSRange(location: NSMaxRange(linkTextRange),     length: NSMaxRange(matchRange) - NSMaxRange(linkTextRange))

			textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: bracketsRange)
			textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: parenthesesRange)
			textStorage.addAttributes([
				.foregroundColor: NSColor.linkColor,
				.underlineStyle:  NSUnderlineStyle.single.rawValue,
			], range: linkTextRange)
		}
	}

	// MARK: - Strikethrough

	private static func applyStrikethrough(to textStorage: NSTextStorage, range: NSRange) {
		strikethroughRegex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range,
				  let textRange  = match?.range(at: 1) else { return }

			textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)

			for symbolRange in [
				NSRange(location: matchRange.location,            length: 2),
				NSRange(location: NSMaxRange(matchRange) - 2,     length: 2),
			] {
				textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: symbolRange)
			}
		}
	}

	// MARK: - Lists

	private static func applyListStyling(to textStorage: NSTextStorage, range: NSRange) {
		let markerAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.secondaryLabelColor]
		for regex in [unorderedListRegex, orderedListRegex] {
			regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
				guard let matchRange = match?.range else { return }
				textStorage.addAttributes(markerAttributes, range: matchRange)
			}
		}
	}

	// MARK: - Blockquotes (new)

	private static func applyBlockquotes(to textStorage: NSTextStorage, range: NSRange) {
		blockquoteRegex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			guard let prefixRange  = match?.range(at: 1),
				  let contentRange = match?.range(at: 2) else { return }

			textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: prefixRange)
			textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: contentRange)
		}
	}

	// MARK: - Horizontal rules (new)

	private static func applyHorizontalRules(to textStorage: NSTextStorage, range: NSRange) {
		horizontalRuleRegex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range else { return }
			textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: matchRange)
		}
	}

	// MARK: - Tables

	private static func applyTables(to textStorage: NSTextStorage, using selectedFont: NSFont, range: NSRange) {
		let boldFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: .boldFontMask)
		let string = textStorage.string

		// Find all table rows (lines with pipes)
		tableRowRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let rowRange = match?.range else { return }

			// Style pipe delimiters as secondary color
			tablePipeRegex.enumerateMatches(in: string, options: [], range: rowRange) { pipeMatch, _, _ in
				guard let pipeRange = pipeMatch?.range else { return }
				textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: pipeRange)
			}
		}

		// Style separator rows as tertiary color and bold the header row above
		tableSeparatorRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let sepRange = match?.range else { return }
			textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: sepRange)

			guard sepRange.location > 0 else { return }
			let headerLineRange = (string as NSString).lineRange(for: NSRange(location: sepRange.location - 1, length: 0))
			let headerContent = (string as NSString).substring(with: headerLineRange)
			if headerContent.contains("|") {
				textStorage.addAttribute(.font, value: boldFont, range: headerLineRange)
			}
		}
	}

	// MARK: - Shared helper

	private static func applyInlineStyle(
		with regex: NSRegularExpression,
		font: NSFont,
		symbolLength: Int,
		in textStorage: NSTextStorage,
		range: NSRange
	) {
		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range,
				  let textRange  = match?.range(at: 1) else { return }

			textStorage.addAttribute(.font, value: font, range: textRange)

			for symbolRange in [
				NSRange(location: matchRange.location,            length: symbolLength),
				NSRange(location: NSMaxRange(matchRange) - symbolLength, length: symbolLength),
			] {
				textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: symbolRange)
			}
		}
	}
}

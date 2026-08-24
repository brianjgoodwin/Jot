//
//  MarkdownProcessor.swift
//  Jot
//
//  Created by Brian on 1/18/24.
//

import Cocoa
import os.signpost

// Caseless enum acts as a namespace — prevents instantiation.
@MainActor
enum MarkdownProcessor {

	// MARK: - Compiled Regexes (once per process lifetime)

	private static let headingRegex        = try! NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)$",               options: [.anchorsMatchLines])
	private static let boldItalicRegex      = try! NSRegularExpression(pattern: "\\*\\*\\*([^*\\n]+)\\*\\*\\*",    options: [])
	// Bold/italic content admits the other marker so nested emphasis styles
	// (**a *b* c** and *a **b** c*). The alternation branches are mutually
	// exclusive at every position, so the patterns stay linear (see #122 for
	// why that property matters here).
	private static let boldAsteriskRegex   = try! NSRegularExpression(pattern: "(?<!\\*)\\*\\*((?:[^*\\n]|\\*(?!\\*))+)\\*\\*(?!\\*)", options: [])
	private static let boldUnderscoreRegex = try! NSRegularExpression(pattern: "__([^\\s_](?:[^_\\n]*[^\\s_])?)__", options: [])
	// Italic: opening delimiter must not be preceded by *, closing must not be followed by *.
	private static let italicAsteriskRegex   = try! NSRegularExpression(pattern: "(?<![*])\\*((?:[^*\\n]|\\*\\*)+)\\*(?![*])",  options: [])
	// Underscore italic: word-boundary aware so file_names_like_this don't trigger it.
	private static let italicUnderscoreRegex = try! NSRegularExpression(pattern: "(?<!\\w)_([^_\\n]+)_(?!\\w)",      options: [])
	private static let inlineCodeRegex     = try! NSRegularExpression(pattern: "`([^`\\n]+)`",                      options: [])
	private static let codeBlockRegex      = try! NSRegularExpression(pattern: "```[^`\\n]*\\n([\\s\\S]*?)\\n?```", options: [])
	private static let linkRegex           = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)",      options: [])
	private static let strikethroughRegex  = try! NSRegularExpression(pattern: "~~([^~\\n]+)~~",                    options: [])
	// Highlight (#270): same shape as the preview's pattern (#268) — the
	// first content character can't be `=`, and the lazy quantifier stops
	// at the first closing `==`, so a single `=` inside content is fine
	// (==a=b==). The lazy single-`.` quantifier stays linear (#122).
	private static let highlightRegex      = try! NSRegularExpression(pattern: "==([^=\\n].*?)==",                 options: [])
	private static let unorderedListRegex  = try! NSRegularExpression(pattern: "^[-+*]\\s+",                        options: [.anchorsMatchLines])
	private static let orderedListRegex    = try! NSRegularExpression(pattern: "^\\d+\\.\\s+",                      options: [.anchorsMatchLines])
	// Checklist (#146): group 1 marker, group 2 state character, group 3
	// content. Adjacent character classes are disjoint at every position,
	// so the pattern stays linear (see #122 for why that matters here).
	private static let checklistRegex      = try! NSRegularExpression(pattern: "^([ \\t]*[-+*] \\[([ xX])\\] )(.*)$", options: [.anchorsMatchLines])
	private static let blockquoteRegex     = try! NSRegularExpression(pattern: "^(>[ \\t]*)(.+)$",                  options: [.anchorsMatchLines])
	private static let horizontalRuleRegex = try! NSRegularExpression(pattern: "^([-*_]{3,})[ \\t]*$",             options: [.anchorsMatchLines])
	// Table: lines containing pipe delimiters. Separator rows (|---|---|) get distinct styling.
	// Both patterns must stay linear. The previous nested-quantifier versions
	// ((.+\|)+ etc.) let the engine try every partition of a pipe-heavy line,
	// so a crafted line that almost matched backtracked exponentially and hung
	// the app (#122). In the separator, adjacent character classes are disjoint,
	// so each position parses exactly one way.
	private static let tableRowRegex       = try! NSRegularExpression(pattern: "^\\|.*\\|[ \\t]*$",               options: [.anchorsMatchLines])
	private static let tablePipeRegex      = try! NSRegularExpression(pattern: "\\|",                              options: [])
	private static let tableSeparatorRegex = try! NSRegularExpression(pattern: "^\\|(?:[ \\t]*:?-{3,}:?[ \\t]*\\|)+[ \\t]*$", options: [.anchorsMatchLines])

	// MARK: - Adaptive code-block background

	private static let codeBackground = NSColor(name: nil) { appearance in
		appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
			? NSColor(white: 0.15, alpha: 1)
			: NSColor(white: 0.94, alpha: 1)
	}

	// MARK: - Adaptive highlight background

	// The preview's <mark> colors (PreviewTheme: #fff8c5 light, #4d3a0a
	// dark), so the editor hint and the rendered highlight read as the
	// same thing.
	private static let highlightBackground = NSColor(name: nil) { appearance in
		appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
			? NSColor(red: 0x4D / 255.0, green: 0x3A / 255.0, blue: 0x0A / 255.0, alpha: 1)
			: NSColor(red: 0xFF / 255.0, green: 0xF8 / 255.0, blue: 0xC5 / 255.0, alpha: 1)
	}

	// MARK: - Public entry point

	static func applyMarkdownStyling(to textView: NSTextView, using selectedFont: NSFont, range: NSRange? = nil) {
		guard let textStorage = textView.textStorage else { return }
		// One string snapshot for the whole pass. Bridging the mutable
		// backing store into Swift is an O(document) copy, so every
		// textStorage.string access in a helper was a full-document copy —
		// ~13 per pass (#141). The pass only mutates attributes, never
		// characters, so a single snapshot stays valid throughout.
		let string = textStorage.string
		let requestedRange = range ?? NSRange(location: 0, length: textStorage.length)
		// Expand to whole lines so line-anchored patterns (headings, lists)
		// and single-line spans (inline code) are never cut mid-match at the
		// range edges.
		let stylingRange = (string as NSString).lineRange(for: requestedRange)

		let signpostID = OSSignpostID(log: PerformanceLog.log)
		os_signpost(.begin, log: PerformanceLog.log, name: "Markdown Styling", signpostID: signpostID,
					"%d of %d chars", stylingRange.length, textStorage.length)
		defer { os_signpost(.end, log: PerformanceLog.log, name: "Markdown Styling", signpostID: signpostID) }

		textStorage.beginEditing()

		// Reset pass — removes stale attributes so deleted syntax doesn't leave
		// behind bold, colour, background, or strikethrough from a previous
		// pass. All resets are bounded to the styling range: per-keystroke
		// passes must not do document-sized attribute churn (#123).
		textStorage.addAttribute(.font, value: selectedFont, range: stylingRange)
		textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: stylingRange)
		textStorage.removeAttribute(.backgroundColor, range: stylingRange)
		textStorage.removeAttribute(.strikethroughStyle, range: stylingRange)
		textStorage.removeAttribute(.underlineStyle, range: stylingRange)
		textStorage.removeAttribute(.link, range: stylingRange)

		// Fence positions for the whole document (#166). Every pass skips
		// matches inside a fence, so a fenced shell snippet's `- item` stays
		// code instead of getting list styling. The scan is full-document
		// because a fence can open before the styling range and close after
		// it; applyCode already needed exactly this scan for the block
		// backgrounds, so sharing it adds no new document-scale cost
		// (caching it incrementally is #164).
		let fences = fencedBlockRanges(in: string, length: textStorage.length)

		// Order matters:
		// - Bold+italic (***) first so the triple-asterisk delimiter is
		//   consumed before bold or italic patterns see it.
		// - Bold before italic so the italic pattern can safely exclude *
		//   without missing bold+italic combos.
		// - Horizontal rules AFTER bold/italic because `***` is valid
		//   bold-italic syntax. If horizontal rules ran first, `***text***`
		//   would be styled as a rule instead of bold-italic.
		applyHeadings(to: textStorage, in: string, using: selectedFont, range: stylingRange, fences: fences)
		applyBoldItalic(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyBold(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyItalic(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyCode(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyLinks(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyStrikethrough(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyHighlights(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyListStyling(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyChecklists(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyBlockquotes(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyHorizontalRules(to: textStorage, in: string, range: stylingRange, fences: fences)
		applyTables(to: textStorage, in: string, using: selectedFont, range: stylingRange, fences: fences)

		textStorage.endEditing()
	}

	// MARK: - Fence awareness (#166)

	/// The range of every fenced code block in the document, delimiter
	/// lines included, in document order. An unclosed trailing fence has
	/// no range — text after it styles normally, matching the background
	/// behavior (no background until the fence closes).
	private static func fencedBlockRanges(in string: String, length: Int) -> [NSRange] {
		var fences: [NSRange] = []
		let fullRange = NSRange(location: 0, length: length)
		codeBlockRegex.enumerateMatches(in: string, options: [], range: fullRange) { match, _, _ in
			if let fence = match?.range {
				fences.append(fence)
			}
		}
		return fences
	}

	/// Whether a match overlaps any fenced block. Fences arrive in
	/// document order, so the loop can stop at the first fence that
	/// starts past the match.
	private static func intersectsFence(_ range: NSRange, _ fences: [NSRange]) -> Bool {
		for fence in fences {
			if fence.location >= NSMaxRange(range) { return false }
			if NSIntersectionRange(fence, range).length > 0 { return true }
		}
		return false
	}

	// MARK: - Headings

	private static func applyHeadings(to textStorage: NSTextStorage, in string: String, using selectedFont: NSFont, range: NSRange, fences: [NSRange]) {
		let boldFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: .boldFontMask)

		headingRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange  = match?.range, !intersectsFence(matchRange, fences),
				  let symbolRange = match?.range(at: 1),
				  let textRange   = match?.range(at: 2) else { return }

			textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: symbolRange)
			textStorage.addAttribute(.font, value: boldFont, range: textRange)
		}
	}

	// MARK: - Bold + Italic

	private static func applyBoldItalic(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		applyInlineStyle(with: boldItalicRegex, traits: [.boldFontMask, .italicFontMask], symbolLength: 3, in: textStorage, string: string, range: range, fences: fences)
	}

	// MARK: - Bold

	private static func applyBold(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		applyInlineStyle(with: boldAsteriskRegex,   traits: .boldFontMask, symbolLength: 2, in: textStorage, string: string, range: range, fences: fences)
		applyInlineStyle(with: boldUnderscoreRegex, traits: .boldFontMask, symbolLength: 2, in: textStorage, string: string, range: range, fences: fences)
	}

	// MARK: - Italic

	private static func applyItalic(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		applyInlineStyle(with: italicAsteriskRegex,   traits: .italicFontMask, symbolLength: 1, in: textStorage, string: string, range: range, fences: fences)
		applyInlineStyle(with: italicUnderscoreRegex, traits: .italicFontMask, symbolLength: 1, in: textStorage, string: string, range: range, fences: fences)
	}

	// MARK: - Code

	private static func applyCode(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		let codeAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.secondaryLabelColor,
			.backgroundColor: codeBackground,
		]

		// Inline code spans are single-line and `range` is line-aligned, so
		// the bounded scan cannot cut a span in half. Backtick spans inside
		// a fence are code content, not markdown (#166).
		inlineCodeRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range, !intersectsFence(matchRange, fences),
				  let codeRange = match?.range(at: 1) else { return }
			textStorage.addAttributes(codeAttributes, range: codeRange)
		}

		// Fenced-block backgrounds come from the precomputed full-document
		// scan (a fence can open before the styling range and close after
		// it). Attribute writes stay bounded to blocks that intersect the
		// styling range — backgrounds elsewhere are still valid from the
		// pass that styled them. The scan itself is the remaining
		// per-keystroke document-scale cost; caching it is #164. Known
		// limit: deleting a fence delimiter leaves the old background
		// outside the styling range until a wider pass (scroll, mode
		// toggle) covers it (#123).
		for fence in fences where NSIntersectionRange(fence, range).length > 0 {
			textStorage.addAttributes(codeAttributes, range: fence)
		}
	}

	// MARK: - Links

	private static func applyLinks(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		linkRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange    = match?.range, !intersectsFence(matchRange, fences),
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

	private static func applyStrikethrough(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		strikethroughRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range, !intersectsFence(matchRange, fences),
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

	// MARK: - Highlights (#270)

	private static func applyHighlights(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		highlightRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range, !intersectsFence(matchRange, fences),
				  let textRange  = match?.range(at: 1) else { return }

			textStorage.addAttribute(.backgroundColor, value: highlightBackground, range: textRange)

			for symbolRange in [
				NSRange(location: matchRange.location,            length: 2),
				NSRange(location: NSMaxRange(matchRange) - 2,     length: 2),
			] {
				textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: symbolRange)
			}
		}
	}

	// MARK: - Lists

	private static func applyListStyling(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		let markerAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.secondaryLabelColor]
		for regex in [unorderedListRegex, orderedListRegex] {
			regex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
				guard let matchRange = match?.range, !intersectsFence(matchRange, fences) else { return }
				textStorage.addAttributes(markerAttributes, range: matchRange)
			}
		}
	}

	// MARK: - Checklists

	private static func applyChecklists(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		checklistRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange   = match?.range, !intersectsFence(matchRange, fences),
				  let markerRange  = match?.range(at: 1),
				  let stateRange   = match?.range(at: 2),
				  let contentRange = match?.range(at: 3) else { return }

			textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: markerRange)

			// Checked items read as done: struck through and dimmed. Runs
			// after the inline passes, so the whole item — links, bold,
			// code included — dims to one color. Deliberate (matches
			// Reminders/Notes); the [x] characters still carry the state
			// for assistive tech, and .link clickability is untouched.
			let state = (string as NSString).substring(with: stateRange)
			if state != " " && contentRange.length > 0 {
				textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
				textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: contentRange)
			}
		}
	}

	// MARK: - Blockquotes (new)

	private static func applyBlockquotes(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		blockquoteRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange   = match?.range, !intersectsFence(matchRange, fences),
				  let prefixRange  = match?.range(at: 1),
				  let contentRange = match?.range(at: 2) else { return }

			textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: prefixRange)
			textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: contentRange)
		}
	}

	// MARK: - Horizontal rules (new)

	private static func applyHorizontalRules(to textStorage: NSTextStorage, in string: String, range: NSRange, fences: [NSRange]) {
		horizontalRuleRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range, !intersectsFence(matchRange, fences) else { return }
			textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: matchRange)
		}
	}

	// MARK: - Tables

	private static func applyTables(to textStorage: NSTextStorage, in string: String, using selectedFont: NSFont, range: NSRange, fences: [NSRange]) {
		let boldFont = NSFontManager.shared.convert(selectedFont, toHaveTrait: .boldFontMask)

		// Find all table rows (lines with pipes)
		tableRowRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let rowRange = match?.range, !intersectsFence(rowRange, fences) else { return }

			// Style pipe delimiters as secondary color
			tablePipeRegex.enumerateMatches(in: string, options: [], range: rowRange) { pipeMatch, _, _ in
				guard let pipeRange = pipeMatch?.range else { return }
				textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: pipeRange)
			}
		}

		// Style separator rows as tertiary color and bold the header row above
		tableSeparatorRegex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let sepRange = match?.range, !intersectsFence(sepRange, fences) else { return }
			textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: sepRange)

			guard sepRange.location > 0 else { return }
			let headerLineRange = (string as NSString).lineRange(for: NSRange(location: sepRange.location - 1, length: 0))
			// A bounded pass must not write outside its own range (#163):
			// the reset pass only covered `range`, so bolding a header line
			// beyond it would plant attributes no reset will ever clean.
			// The debounced visible-range pass re-bolds the header within
			// ~0.3 s of a keystroke on the separator line.
			guard NSIntersectionRange(headerLineRange, range).length > 0 else { return }
			let headerContent = (string as NSString).substring(with: headerLineRange)
			if headerContent.contains("|") {
				textStorage.addAttribute(.font, value: boldFont, range: headerLineRange)
			}
		}
	}

	// MARK: - Shared helper

	private static func applyInlineStyle(
		with regex: NSRegularExpression,
		traits: NSFontTraitMask,
		symbolLength: Int,
		in textStorage: NSTextStorage,
		string: String,
		range: NSRange,
		fences: [NSRange]
	) {
		let fontManager = NSFontManager.shared

		regex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
			guard let matchRange = match?.range, !intersectsFence(matchRange, fences),
				  let textRange  = match?.range(at: 1) else { return }

			// Add the traits to whatever font each run already has, so nested
			// spans compose (bold + italic) instead of overwriting each other.
			// Collect first, then apply: mutating the attribute being
			// enumerated mid-enumeration is undefined.
			var styledRuns: [(NSRange, NSFont)] = []
			textStorage.enumerateAttribute(.font, in: textRange, options: []) { value, runRange, _ in
				var font = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
				if traits.contains(.boldFontMask) {
					font = fontManager.convert(font, toHaveTrait: .boldFontMask)
				}
				if traits.contains(.italicFontMask) {
					font = fontManager.convert(font, toHaveTrait: .italicFontMask)
				}
				styledRuns.append((runRange, font))
			}
			for (runRange, font) in styledRuns {
				textStorage.addAttribute(.font, value: font, range: runRange)
			}

			for symbolRange in [
				NSRange(location: matchRange.location,            length: symbolLength),
				NSRange(location: NSMaxRange(matchRange) - symbolLength, length: symbolLength),
			] {
				textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: symbolRange)
			}
		}
	}
}

//
//  ListMarker.swift
//  Jot
//
//  Parses the list marker at the start of a markdown line. Shared by the
//  Return-key list continuation (#143) and the checklist commands (#146).
//

import Foundation

/// The leading marker of a markdown list line: indentation plus a bullet
/// (`- `, `* `, `+ `), an ordered number (`3. `), or a checkbox bullet
/// (`- [ ] `, `- [x] `).
struct ListMarker {

	/// Leading whitespace before the marker (tabs/spaces), preserved so
	/// continued items keep their nesting depth.
	let indent: String

	/// The marker text after the indent, through the space that separates
	/// it from the content: `"- "`, `"3. "`, or `"- [x] "`.
	let text: String

	/// The number of an ordered-list marker (`"3. "` → 3); nil for bullets.
	let number: Int?

	/// UTF-16 offset from the start of the line of the checkbox state
	/// character (the one between the brackets); nil when the marker has
	/// no checkbox.
	let checkboxStateOffset: Int?

	var isCheckbox: Bool { return checkboxStateOffset != nil }

	/// Length of indent + marker in UTF-16 units, for cursor math against
	/// NSString-based ranges.
	var prefixLength: Int {
		return (indent as NSString).length + (text as NSString).length
	}

	// Group 1: indent. Group 2: bullet character. Group 3: checkbox, if
	// present. Group 4: ordered-list number (capped at 9 digits so Int
	// conversion can't overflow). A space after the marker is required —
	// a bare "-" or "1." is ordinary text, and the trailing space keeps
	// this in step with MarkdownProcessor's list regexes.
	private static let regex = try! NSRegularExpression(
		pattern: "^([ \\t]*)(?:([-+*])( \\[[ xX]\\])? |(\\d{1,9})\\. )")

	/// Parses the marker at the start of `line` (a single line, without its
	/// trailing newline). Fails when the line is not a list item.
	init?(line: String) {
		let nsLine = line as NSString
		let fullRange = NSRange(location: 0, length: nsLine.length)
		guard let match = Self.regex.firstMatch(in: line, options: [], range: fullRange) else {
			return nil
		}

		let indentRange = match.range(at: 1)
		indent = nsLine.substring(with: indentRange)
		text = nsLine.substring(with: NSRange(location: indentRange.length,
											  length: match.range.length - indentRange.length))

		let numberRange = match.range(at: 4)
		number = numberRange.location == NSNotFound
			? nil
			: Int(nsLine.substring(with: numberRange))

		let checkboxRange = match.range(at: 3)
		// The checkbox group is " [x]"; the state character sits after
		// the space and the opening bracket.
		checkboxStateOffset = checkboxRange.location == NSNotFound
			? nil
			: checkboxRange.location + 2
	}

	/// The prefix that starts the next item: same indent and marker, with
	/// ordered numbers incremented and checkboxes reset to unchecked.
	var continuationPrefix: String {
		if let number = number {
			return indent + "\(number + 1). "
		}
		if isCheckbox {
			// First character of the marker text is the bullet.
			return indent + String(text.prefix(1)) + " [ ] "
		}
		return indent + text
	}

	// MARK: - Return-key behavior (#143)

	enum ReturnAction: Equatable {
		/// Continue the list: insert this text (newline + next marker) at
		/// the caret.
		case continueList(insert: String)
		/// Return on an empty item ends the list: delete this range (the
		/// whole line content) and leave the caret on the now-plain line.
		case endList(remove: NSRange)
		/// Not a list context — let the text view insert a plain newline.
		case none
	}

	/// What pressing Return at `caret` (a UTF-16 offset with no selection)
	/// should do. Pure function of the text so it can be tested without a
	/// text view.
	static func returnAction(in text: String, caret: Int) -> ReturnAction {
		let nsString = text as NSString
		guard caret >= 0 && caret <= nsString.length else { return .none }

		// getLineStart's contentsEnd excludes the line terminator. That
		// matters for CRLF files: lineRange includes the "\r\n", and a
		// String hasSuffix("\n") check never matches it because Swift
		// compares whole graphemes and "\r\n" is one Character.
		var lineStart = 0
		var lineEnd = 0
		var contentsEnd = 0
		nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd,
							  for: NSRange(location: caret, length: 0))
		let line = nsString.substring(with: NSRange(location: lineStart,
													length: contentsEnd - lineStart))

		guard let marker = ListMarker(line: line) else { return .none }

		// Only act when the caret sits in the content, past the marker;
		// Return at the line start should just push the line down.
		guard caret - lineStart >= marker.prefixLength else { return .none }

		// Whitespace-only content is an empty item: Return clears the
		// whole line, stray trailing spaces included.
		let content = (line as NSString).substring(from: marker.prefixLength)
		if content.trimmingCharacters(in: .whitespaces).isEmpty {
			return .endList(remove: NSRange(location: lineStart,
											length: contentsEnd - lineStart))
		}
		return .continueList(insert: "\n" + marker.continuationPrefix)
	}
}

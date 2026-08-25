//
//  BlockFormat.swift
//  Jot
//
//  Pure line transforms behind Format > Blockquote and the list
//  commands (#96). Each takes the lines the selection touches and
//  returns their replacements; the editor swaps the text in one edit
//  and re-selects the result.
//
//  Shared rule: if every non-blank line already carries the construct,
//  the command removes it; otherwise it applies it to every line. So
//  each command toggles on repeat, and a mixed selection is normalized
//  rather than flipped line by line.
//

import Foundation

enum BlockFormat {

	// MARK: - Blockquote

	static func toggleBlockquote(_ lines: [String]) -> [String] {
		let markable = lines.filter { !isBlank($0) }
		let allQuoted = !markable.isEmpty && markable.allSatisfy { $0.hasPrefix(">") }

		if allQuoted {
			return lines.map { line in
				if line.hasPrefix("> ") { return String(line.dropFirst(2)) }
				if line.hasPrefix(">") { return String(line.dropFirst(1)) }
				return line
			}
		}
		// Blank lines get a bare ">" so a multi-paragraph selection
		// stays one quote instead of splitting at every blank line.
		return lines.map { isBlank($0) ? ">" + $0 : "> " + $0 }
	}

	// MARK: - Lists

	static func toggleOrderedList(_ lines: [String]) -> [String] {
		let markable = lines.filter { !isBlank($0) }
		let allNumbered = !markable.isEmpty && markable.allSatisfy {
			ListMarker(line: $0)?.number != nil
		}

		if allNumbered { return lines.map(strippingMarker) }

		var number = 0
		return lines.map { line in
			if isBlank(line) { return line }
			number += 1
			if let marker = ListMarker(line: line) {
				// Re-marker an existing list line in place: bullets and
				// checkboxes become numbered items, indent preserved.
				let content = (line as NSString).substring(from: marker.prefixLength)
				return marker.indent + "\(number). " + content
			}
			return "\(number). " + line
		}
	}

	static func toggleUnorderedList(_ lines: [String]) -> [String] {
		let markable = lines.filter { !isBlank($0) }
		// Checkboxes don't count as "already bulleted": applying the
		// command to a checklist demotes it to plain bullets (To-do is
		// the command that manages the checkboxes themselves).
		let allBulleted = !markable.isEmpty && markable.allSatisfy { line in
			guard let marker = ListMarker(line: line) else { return false }
			return marker.number == nil && !marker.isCheckbox
		}

		if allBulleted { return lines.map(strippingMarker) }

		return lines.map { line in
			if isBlank(line) { return line }
			if let marker = ListMarker(line: line) {
				let content = (line as NSString).substring(from: marker.prefixLength)
				return marker.indent + "- " + content
			}
			return "- " + line
		}
	}

	// MARK: - Helpers

	/// The line without its list marker, indent preserved.
	private static func strippingMarker(_ line: String) -> String {
		guard let marker = ListMarker(line: line) else { return line }
		return marker.indent + (line as NSString).substring(from: marker.prefixLength)
	}

	private static func isBlank(_ line: String) -> Bool {
		return line.trimmingCharacters(in: .whitespaces).isEmpty
	}
}

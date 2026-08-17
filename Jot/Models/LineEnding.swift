//
//  LineEnding.swift
//  Jot
//
//  The newline convention a file arrived with (#194, #195). The editor
//  buffer is always normalized to "\n" — NSTextView inserts "\n" on Return
//  regardless of the file's convention, so keeping the buffer single-
//  convention avoids mixed endings by construction. The original
//  convention is restored at save time.
//

import Foundation

enum LineEnding: String {
	case lf = "LF"
	case crlf = "CRLF"
	case cr = "CR"

	var characters: String {
		switch self {
		case .lf: return "\n"
		case .crlf: return "\r\n"
		case .cr: return "\r"
		}
	}

	/// The convention of the first line break in `string`, or nil when it
	/// has none. Swift groups "\r\n" into a single Character, so a
	/// per-Character scan sees each break whole. Unicode's extra breaks
	/// (U+2028/2029/0085) are deliberately ignored — they stay in the text
	/// untouched and don't count as a file convention.
	static func detect(in string: String) -> LineEnding? {
		for character in string {
			switch character {
			case "\r\n": return .crlf
			case "\r": return .cr
			case "\n": return .lf
			default: continue
			}
		}
		return nil
	}

	/// `string` with every line break replaced by "\n".
	static func normalizeToLF(_ string: String) -> String {
		string
			.replacingOccurrences(of: "\r\n", with: "\n")
			.replacingOccurrences(of: "\r", with: "\n")
	}

	/// A normalized (LF-only) string converted back to this convention.
	func restore(in normalized: String) -> String {
		self == .lf ? normalized : normalized.replacingOccurrences(of: "\n", with: characters)
	}
}

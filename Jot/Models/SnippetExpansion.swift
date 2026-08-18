//
//  SnippetExpansion.swift
//  Jot
//
//  Created on 8/17/26.
//
//  Variable expansion for Edit > Insert Snippet (#162). Pure so the
//  substitution and cursor-offset rules are directly testable; callers
//  inject date, locale, and time zone in tests.
//

import Foundation

enum SnippetExpansion {

	/// One substitution pass: every {{date}} and {{time}} becomes a
	/// locale-aware string, then the first {{cursor}} is stripped and
	/// its position returned as an offset into the result. Later
	/// {{cursor}} occurrences and unknown {{variables}} stay literal.
	///
	/// Variables expand before the cursor marker is located, so the
	/// offset is correct when a variable precedes the marker. The
	/// offset is UTF-16 because it feeds an NSRange.
	static func expand(_ text: String,
	                   date: Date = Date(),
	                   locale: Locale = .current,
	                   timeZone: TimeZone = .current) -> (text: String, cursorOffsetUTF16: Int?) {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .medium
		dateFormatter.timeStyle = .none
		dateFormatter.locale = locale
		dateFormatter.timeZone = timeZone

		let timeFormatter = DateFormatter()
		timeFormatter.dateStyle = .none
		timeFormatter.timeStyle = .short
		timeFormatter.locale = locale
		timeFormatter.timeZone = timeZone

		var expanded = text
			.replacingOccurrences(of: "{{date}}", with: dateFormatter.string(from: date))
			.replacingOccurrences(of: "{{time}}", with: timeFormatter.string(from: date))

		guard let marker = expanded.range(of: "{{cursor}}") else {
			return (expanded, nil)
		}
		let offset = (String(expanded[..<marker.lowerBound]) as NSString).length
		expanded.removeSubrange(marker)
		return (expanded, offset)
	}
}

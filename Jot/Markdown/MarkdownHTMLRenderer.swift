//
//  MarkdownHTMLRenderer.swift
//  Jot
//
//  Created on 8/18/26.
//
//  Walks a swift-markdown AST and emits the HTML body for the preview
//  window (#30). Owning the HTML generation means raw HTML in the source
//  document is never passed through -- it is escaped and shown as literal
//  text -- which closes the XSS path by construction (#10, #134).
//

import Foundation
import Markdown

/// Converts a parsed markdown `Document` into an HTML body string.
///
/// Covers the CommonMark core plus the GFM extensions swift-markdown
/// parses by default (tables, strikethrough, task lists). Highlighting
/// (`==text==`) and footnotes (`[^id]`) are post-processed because
/// swift-markdown has no AST nodes for either.
struct MarkdownHTMLRenderer: MarkupVisitor {

	/// Parses `markdown` and returns the rendered HTML body.
	///
	/// `Markdown.Document` is spelled out because Jot's own `Document`
	/// (the NSDocument subclass) shadows the module type.
	///
	/// swift-markdown enables cmark's smart punctuation by default
	/// (curly quotes, -- to en dash). The preview must show what the
	/// markdown says; typographic substitution is an editor-side,
	/// per-mode decision (#150), so smart parsing is disabled here.
	static func render(markdown: String) -> String {
		let (processedMarkdown, footnotes) = extractFootnotes(from: markdown)
		let document = Markdown.Document(parsing: processedMarkdown, options: .disableSmartOpts)
		var renderer = MarkdownHTMLRenderer()
		var html = renderer.visit(document)
		html = applyHighlighting(html)
		html = applyFootnotes(html, definitions: footnotes)
		return html
	}

	// Link clicks open in the default browser (see the preview's
	// navigation delegate), so only schemes that are safe to hand to
	// NSWorkspace are emitted. Everything else renders as unlinked text.
	// The delegate re-checks this list before opening -- keep them in step.
	static let allowedLinkSchemes: Set<String> = ["http", "https", "mailto"]

	// Kept in step with the preview's CSP img-src directive. http is
	// excluded because the CSP never allows it (no cleartext image
	// loads); file: is excluded because loadHTMLString(baseURL: nil)
	// gives the page an about:blank origin that WebKit refuses file:
	// subresources from -- local images need the #38 rebuild to adopt
	// loadFileURL. data: URIs bypass this set; see allowedDataImagePrefixes.
	private static let allowedImageSchemes: Set<String> = ["https"]

	// data: images never touch the network, so they render regardless of
	// the remote-images preference -- but only raster types. SVG can
	// carry script and text/html is a document; neither belongs in an
	// img emitted from untrusted markdown.
	private static let allowedDataImagePrefixes = [
		"data:image/png", "data:image/jpeg", "data:image/gif", "data:image/webp",
	]

	// MARK: - Block elements

	mutating func visitDocument(_ document: Markdown.Document) -> String {
		renderChildren(of: document)
	}

	mutating func visitParagraph(_ paragraph: Paragraph) -> String {
		"<p>" + renderChildren(of: paragraph) + "</p>\n"
	}

	mutating func visitHeading(_ heading: Heading) -> String {
		"<h\(heading.level)>" + renderChildren(of: heading) + "</h\(heading.level)>\n"
	}

	mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
		"<blockquote>\n" + renderChildren(of: blockQuote) + "</blockquote>\n"
	}

	mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
		// codeBlock.code already ends with a newline. The info string can
		// carry extra words after the language (```ruby startline=3); only
		// the first word names the language, per CommonMark.
		let language = codeBlock.language?.split(whereSeparator: { $0 == " " || $0 == "\t" }).first
		let languageClass = language.map { " class=\"language-\(escapeHTML(String($0)))\"" } ?? ""
		return "<pre><code\(languageClass)>" + escapeHTML(codeBlock.code) + "</code></pre>\n"
	}

	mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
		"<hr />\n"
	}

	mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
		"<ul>\n" + renderChildren(of: unorderedList) + "</ul>\n"
	}

	mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
		let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
		return "<ol\(start)>\n" + renderChildren(of: orderedList) + "</ol>\n"
	}

	mutating func visitListItem(_ listItem: ListItem) -> String {
		var prefix = ""
		if let checkbox = listItem.checkbox {
			let checked = checkbox == .checked ? " checked" : ""
			prefix = "<input type=\"checkbox\" disabled\(checked) /> "
		}
		return "<li>" + prefix + renderChildren(of: listItem) + "</li>\n"
	}

	// MARK: - Tables (GFM extension)

	// Column alignments of the table currently being rendered. Markdown
	// tables cannot nest, so a single slot is enough.
	private var currentTableAlignments: [Table.ColumnAlignment?] = []

	mutating func visitTable(_ table: Table) -> String {
		currentTableAlignments = table.columnAlignments
		let html = "<table>\n" + visit(table.head) + visit(table.body) + "</table>\n"
		currentTableAlignments = []
		return html
	}

	mutating func visitTableHead(_ tableHead: Table.Head) -> String {
		var html = "<thead>\n<tr>"
		var gridColumn = 0
		for cell in tableHead.cells {
			html += renderTableCell(cell, tag: "th", column: gridColumn)
			gridColumn += Int(cell.colspan)
		}
		return html + "</tr>\n</thead>\n"
	}

	mutating func visitTableBody(_ tableBody: Table.Body) -> String {
		tableBody.isEmpty ? "" : "<tbody>\n" + renderChildren(of: tableBody) + "</tbody>\n"
	}

	mutating func visitTableRow(_ tableRow: Table.Row) -> String {
		var html = "<tr>"
		var gridColumn = 0
		for cell in tableRow.cells {
			html += renderTableCell(cell, tag: "td", column: gridColumn)
			gridColumn += Int(cell.colspan)
		}
		return html + "</tr>\n"
	}

	private mutating func renderTableCell(_ cell: Table.Cell, tag: String, column: Int) -> String {
		// A span of 0 means this position is covered by a neighboring
		// cell's colspan/rowspan: it emits nothing, and (colspan 0) it
		// advances the grid column by nothing in the caller.
		guard cell.colspan > 0 && cell.rowspan > 0 else { return "" }

		var attributes = ""
		if tag == "th" {
			// Explicit scope keeps VoiceOver's header attribution correct
			// even when a header cell spans columns.
			attributes += cell.colspan > 1 ? " scope=\"colgroup\"" : " scope=\"col\""
		}
		if cell.colspan > 1 { attributes += " colspan=\"\(cell.colspan)\"" }
		if cell.rowspan > 1 { attributes += " rowspan=\"\(cell.rowspan)\"" }
		if column < currentTableAlignments.count, let alignment = currentTableAlignments[column] {
			let value: String
			switch alignment {
			case .left: value = "left"
			case .center: value = "center"
			case .right: value = "right"
			}
			attributes += " style=\"text-align: \(value)\""
		}
		return "<\(tag)\(attributes)>" + renderChildren(of: cell) + "</\(tag)>"
	}

	// MARK: - Inline elements

	mutating func visitText(_ text: Text) -> String {
		escapeHTML(text.string)
	}

	mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
		"<em>" + renderChildren(of: emphasis) + "</em>"
	}

	mutating func visitStrong(_ strong: Strong) -> String {
		"<strong>" + renderChildren(of: strong) + "</strong>"
	}

	mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
		"<del>" + renderChildren(of: strikethrough) + "</del>"
	}

	mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
		"<code>" + escapeHTML(inlineCode.code) + "</code>"
	}

	mutating func visitLink(_ link: Link) -> String {
		let text = renderChildren(of: link)
		guard let destination = link.destination,
			  isAllowed(destination, schemes: Self.allowedLinkSchemes) else {
			return text
		}
		var html = "<a href=\"\(escapeHTML(destination))\""
		if let title = link.title, !title.isEmpty {
			html += " title=\"\(escapeHTML(title))\""
		}
		return html + ">" + text + "</a>"
	}

	mutating func visitImage(_ image: Image) -> String {
		guard let source = image.source, isAllowedImageSource(source) else {
			return renderChildren(of: image)
		}
		var html = "<img src=\"\(escapeHTML(source))\" alt=\"\(escapeHTML(image.plainText))\""
		if let title = image.title, !title.isEmpty {
			html += " title=\"\(escapeHTML(title))\""
		}
		return html + " />"
	}

	mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
		"\n"
	}

	mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
		"<br />\n"
	}

	// MARK: - Raw HTML (deliberately not passed through)

	// Escaped raw HTML renders in a code container: monospace signals
	// "literal markup" visually, and VoiceOver announces the code context
	// instead of reading bare tag soup. <pre> keeps multi-line blocks
	// from reflowing onto one line.
	mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
		"<pre><code>" + escapeHTML(html.rawHTML) + "</code></pre>\n"
	}

	mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
		"<code>" + escapeHTML(inlineHTML.rawHTML) + "</code>"
	}

	// MARK: - Fallback

	/// Any node without an explicit visit method renders its children and
	/// contributes no markup of its own.
	mutating func defaultVisit(_ markup: Markup) -> String {
		renderChildren(of: markup)
	}

	private mutating func renderChildren(of markup: Markup) -> String {
		markup.children.map { visit($0) }.joined()
	}

	// MARK: - Escaping

	/// One escape for text and attribute contexts alike. Double quotes
	/// are escaped everywhere -- required in attributes, harmless in
	/// text, and it matches cmark's reference output byte for byte.
	/// Single quotes are deliberately NOT escaped, so every attribute
	/// this renderer emits MUST be double-quoted; a single-quoted
	/// attribute would be an injection vector.
	private func escapeHTML(_ text: String) -> String {
		text.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
			.replacingOccurrences(of: "\"", with: "&quot;")
	}

	/// A destination is allowed if it is a relative reference, or its
	/// scheme is in `schemes`. A scheme per RFC 3986 is
	/// ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) followed by ":" before
	/// any "/", "?", or "#" -- so "notes/a:b.md" and "#sec:1" are
	/// relative references, not scheme-carrying URLs. A scheme-shaped
	/// prefix that is not on the allowlist fails closed.
	private func isAllowed(_ destination: String, schemes: Set<String>) -> Bool {
		// Protocol-relative destinations (//host/path) carry no scheme
		// but still name a remote host; reject them outright so the
		// navigation delegate can never receive one.
		if destination.hasPrefix("//") { return false }

		var scheme = ""
		for character in destination {
			if character == ":" {
				return !scheme.isEmpty && schemes.contains(scheme.lowercased())
			}
			if character == "/" || character == "?" || character == "#" { return true }
			guard character.isLetter || character.isNumber
				|| character == "+" || character == "-" || character == "." else { return true }
			scheme.append(character)
		}
		return true
	}

	/// Images accept https via the scheme allowlist, plus data: URIs
	/// restricted to raster image types.
	private func isAllowedImageSource(_ source: String) -> Bool {
		let lowered = source.lowercased()
		if lowered.hasPrefix("data:") {
			return Self.allowedDataImagePrefixes.contains { lowered.hasPrefix($0) }
		}
		return isAllowed(source, schemes: Self.allowedImageSchemes)
	}

	// MARK: - Highlighting (==text==)

	// swift-markdown has no Highlight AST node, so ==text== passes
	// through the visitor as literal text. This post-processes the
	// rendered HTML to convert it to <mark> tags, skipping code blocks
	// and inline code where the delimiters should stay literal.
	private static let highlightPattern = try! NSRegularExpression(
		pattern: "==([^=].*?)==",
		options: []
	)

	private static func applyHighlighting(_ html: String) -> String {
		var result = ""
		var searchStart = html.startIndex

		while searchStart < html.endIndex {
			let remaining = html[searchStart...]

			// Find the next <code or <pre> tag.
			let codeMatch = remaining.range(of: "<code")
			let preMatch = remaining.range(of: "<pre>")

			// Pick whichever comes first.
			let nextCodeOpen: Range<String.Index>?
			let closeTag: String
			if let c = codeMatch, let p = preMatch {
				if c.lowerBound <= p.lowerBound {
					nextCodeOpen = c; closeTag = "</code>"
				} else {
					nextCodeOpen = p; closeTag = "</pre>"
				}
			} else if let c = codeMatch {
				nextCodeOpen = c; closeTag = "</code>"
			} else if let p = preMatch {
				nextCodeOpen = p; closeTag = "</pre>"
			} else {
				nextCodeOpen = nil; closeTag = ""
			}

			guard let openRange = nextCodeOpen else {
				result += replaceHighlights(in: String(remaining))
				break
			}

			// Process everything before the code block.
			result += replaceHighlights(in: String(html[searchStart..<openRange.lowerBound]))

			// Find the matching close tag and pass the code block through unchanged.
			if let closeRange = html[openRange.upperBound...].range(of: closeTag) {
				result += String(html[openRange.lowerBound..<closeRange.upperBound])
				searchStart = closeRange.upperBound
			} else {
				result += String(html[openRange.lowerBound...])
				break
			}
		}

		return result
	}

	private static func replaceHighlights(in text: String) -> String {
		let range = NSRange(text.startIndex..., in: text)
		return highlightPattern.stringByReplacingMatches(
			in: text,
			range: range,
			withTemplate: "<mark>$1</mark>"
		)
	}

	// MARK: - Footnotes ([^id])

	// swift-markdown has no footnote AST nodes. Pre-processing strips
	// definition lines and replaces inline [^id] references with text
	// markers. The parser treats the markers as plain text (escaping
	// them inside code spans automatically). Post-processing converts
	// the markers outside <code>/<pre> into superscript links and
	// appends a footnotes section.

	private static let footnoteDefPattern = try! NSRegularExpression(
		pattern: #"(?m)^\[\^([A-Za-z0-9_-]+)\]:\s+(.+)$"#
	)

	private static let footnoteRefPattern = try! NSRegularExpression(
		pattern: #"\[\^([A-Za-z0-9_-]+)\]"#
	)

	private static let fnMarkerPrefix = "\u{FFFE}FN:"
	private static let fnMarkerSuffix = "\u{FFFE}"

	private static func extractFootnotes(from markdown: String) -> (String, [(id: String, text: String)]) {
		let nsMarkdown = markdown as NSString
		let fullRange = NSRange(location: 0, length: nsMarkdown.length)

		var definitions: [(id: String, text: String)] = []
		var definitionIDs: Set<String> = []
		for match in footnoteDefPattern.matches(in: markdown, range: fullRange) {
			let id = nsMarkdown.substring(with: match.range(at: 1))
			let text = nsMarkdown.substring(with: match.range(at: 2))
			if definitionIDs.insert(id).inserted {
				definitions.append((id: id, text: text))
			}
		}

		guard !definitions.isEmpty else { return (markdown, []) }

		// Strip definition lines.
		var processed = footnoteDefPattern.stringByReplacingMatches(
			in: markdown, range: fullRange, withTemplate: ""
		)

		// Replace [^id] references that have definitions with markers.
		let nsProcessed = processed as NSString
		let procRange = NSRange(location: 0, length: nsProcessed.length)
		let refMatches = footnoteRefPattern.matches(in: processed, range: procRange)
		for match in refMatches.reversed() {
			let id = nsProcessed.substring(with: match.range(at: 1))
			guard definitionIDs.contains(id) else { continue }
			let marker = fnMarkerPrefix + id + fnMarkerSuffix
			processed = (processed as NSString).replacingCharacters(in: match.range, with: marker)
		}

		return (processed, definitions)
	}

	private static func applyFootnotes(_ html: String, definitions: [(id: String, text: String)]) -> String {
		guard !definitions.isEmpty else { return html }

		var indexByID: [String: Int] = [:]
		for (i, def) in definitions.enumerated() {
			indexByID[def.id] = i + 1
		}

		// Replace markers with superscript links, skipping code blocks.
		let result = replaceFootnoteMarkers(in: html, indexByID: indexByID)

		// Append the footnotes section.
		var section = "<section class=\"footnotes\" role=\"doc-endnotes\" aria-label=\"Footnotes\">\n<hr />\n<ol>\n"
		for def in definitions {
			let escapedText = escapeHTMLStatic(def.text)
			section += "<li id=\"fn-\(def.id)\"><p>\(escapedText) "
			section += "<a href=\"#fnref-\(def.id)\" role=\"doc-backlink\">&#8617;</a>"
			section += "</p>\n</li>\n"
		}
		section += "</ol>\n</section>\n"

		// Any remaining markers (inside code blocks, or references
		// without definitions) revert to their original [^id] form.
		var final = result + section
		for id in indexByID.keys {
			let marker = fnMarkerPrefix + id + fnMarkerSuffix
			final = final.replacingOccurrences(of: marker, with: "[^\(id)]")
		}
		return final
	}

	private static func replaceFootnoteMarkers(in html: String, indexByID: [String: Int]) -> String {
		// Walk the HTML, skipping <code>/<pre> blocks (same approach
		// as applyHighlighting). Inside code, the parser has already
		// escaped the marker characters, so they won't match anyway,
		// but skipping keeps the logic explicit.
		var result = ""
		var searchStart = html.startIndex

		while searchStart < html.endIndex {
			let remaining = html[searchStart...]
			let codeMatch = remaining.range(of: "<code")
			let preMatch = remaining.range(of: "<pre>")

			let nextCodeOpen: Range<String.Index>?
			let closeTag: String
			if let c = codeMatch, let p = preMatch {
				if c.lowerBound <= p.lowerBound {
					nextCodeOpen = c; closeTag = "</code>"
				} else {
					nextCodeOpen = p; closeTag = "</pre>"
				}
			} else if let c = codeMatch {
				nextCodeOpen = c; closeTag = "</code>"
			} else if let p = preMatch {
				nextCodeOpen = p; closeTag = "</pre>"
			} else {
				nextCodeOpen = nil; closeTag = ""
			}

			guard let openRange = nextCodeOpen else {
				result += replaceMarkers(in: String(remaining), indexByID: indexByID)
				break
			}

			result += replaceMarkers(in: String(html[searchStart..<openRange.lowerBound]), indexByID: indexByID)

			if let closeRange = html[openRange.upperBound...].range(of: closeTag) {
				result += String(html[openRange.lowerBound..<closeRange.upperBound])
				searchStart = closeRange.upperBound
			} else {
				result += String(html[openRange.lowerBound...])
				break
			}
		}

		return result
	}

	private static func replaceMarkers(in text: String, indexByID: [String: Int]) -> String {
		var result = text
		for (id, index) in indexByID {
			let marker = fnMarkerPrefix + id + fnMarkerSuffix
			let sup = "<sup><a href=\"#fn-\(id)\" id=\"fnref-\(id)\" role=\"doc-noteref\">\(index)</a></sup>"
			result = result.replacingOccurrences(of: marker, with: sup)
		}
		return result
	}

	private static func escapeHTMLStatic(_ text: String) -> String {
		text.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
			.replacingOccurrences(of: "\"", with: "&quot;")
	}
}

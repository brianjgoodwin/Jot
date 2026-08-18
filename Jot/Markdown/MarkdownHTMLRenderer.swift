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
/// (`==text==`) and footnotes (`[^1]`) are custom extensions tracked
/// separately in #39.
struct MarkdownHTMLRenderer: MarkupVisitor {

	/// Parses `markdown` and returns the rendered HTML body.
	///
	/// `Markdown.Document` is spelled out because Jot's own `Document`
	/// (the NSDocument subclass) shadows the module type.
	static func render(markdown: String) -> String {
		let document = Markdown.Document(parsing: markdown)
		var renderer = MarkdownHTMLRenderer()
		return renderer.visit(document)
	}

	// Link clicks open in the default browser (see the preview's
	// navigation delegate), so only schemes that are safe to hand to
	// NSWorkspace are emitted. Everything else renders as unlinked text.
	private static let allowedLinkSchemes: Set<String> = ["http", "https", "mailto"]

	// Must stay in step with the preview's CSP img-src directive.
	private static let allowedImageSchemes: Set<String> = ["http", "https", "file", "data"]

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
		// codeBlock.code already ends with a newline.
		let languageClass = codeBlock.language.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
		return "<pre><code\(languageClass)>" + escapeText(codeBlock.code) + "</code></pre>\n"
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

	mutating func visitTable(_ table: Table) -> String {
		"<table>\n" + visit(table.head) + visit(table.body) + "</table>\n"
	}

	mutating func visitTableHead(_ tableHead: Table.Head) -> String {
		var html = "<thead>\n<tr>"
		for (column, cell) in tableHead.cells.enumerated() {
			html += renderTableCell(cell, tag: "th", column: column)
		}
		return html + "</tr>\n</thead>\n"
	}

	mutating func visitTableBody(_ tableBody: Table.Body) -> String {
		tableBody.isEmpty ? "" : "<tbody>\n" + renderChildren(of: tableBody) + "</tbody>\n"
	}

	mutating func visitTableRow(_ tableRow: Table.Row) -> String {
		var html = "<tr>"
		for (column, cell) in tableRow.cells.enumerated() {
			html += renderTableCell(cell, tag: "td", column: column)
		}
		return html + "</tr>\n"
	}

	private mutating func renderTableCell(_ cell: Table.Cell, tag: String, column: Int) -> String {
		// A span of 0 means this position is covered by a neighboring
		// cell's colspan/rowspan and emits nothing.
		guard cell.colspan > 0 && cell.rowspan > 0 else { return "" }

		var attributes = ""
		if cell.colspan > 1 { attributes += " colspan=\"\(cell.colspan)\"" }
		if cell.rowspan > 1 { attributes += " rowspan=\"\(cell.rowspan)\"" }
		if let alignment = columnAlignment(for: cell, column: column) {
			attributes += " style=\"text-align: \(alignment)\""
		}
		return "<\(tag)\(attributes)>" + renderChildren(of: cell) + "</\(tag)>"
	}

	private func columnAlignment(for cell: Table.Cell, column: Int) -> String? {
		guard let table = cell.parent?.parent as? Table ?? cell.parent?.parent?.parent as? Table,
			  column < table.columnAlignments.count,
			  let alignment = table.columnAlignments[column] else { return nil }
		switch alignment {
		case .left: return "left"
		case .center: return "center"
		case .right: return "right"
		}
	}

	// MARK: - Inline elements

	mutating func visitText(_ text: Text) -> String {
		escapeText(text.string)
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
		"<code>" + escapeText(inlineCode.code) + "</code>"
	}

	mutating func visitLink(_ link: Link) -> String {
		let text = renderChildren(of: link)
		guard let destination = link.destination,
			  isAllowed(destination, schemes: Self.allowedLinkSchemes) else {
			return text
		}
		return "<a href=\"\(escapeAttribute(destination))\">" + text + "</a>"
	}

	mutating func visitImage(_ image: Image) -> String {
		guard let source = image.source,
			  isAllowed(source, schemes: Self.allowedImageSchemes) else {
			return renderChildren(of: image)
		}
		var html = "<img src=\"\(escapeAttribute(source))\" alt=\"\(escapeAttribute(image.plainText))\""
		if let title = image.title, !title.isEmpty {
			html += " title=\"\(escapeAttribute(title))\""
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

	mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
		"<p>" + escapeText(html.rawHTML) + "</p>\n"
	}

	mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
		escapeText(inlineHTML.rawHTML)
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

	private func escapeText(_ text: String) -> String {
		text.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
	}

	private func escapeAttribute(_ text: String) -> String {
		escapeText(text).replacingOccurrences(of: "\"", with: "&quot;")
	}

	/// A destination is allowed if it is relative (no scheme) with a safe
	/// prefix, or its scheme is in `schemes`. Relative URLs resolve against
	/// a nil baseURL in the preview and simply fail to load, so they are
	/// harmless; scheme-carrying URLs must be on the allowlist.
	private func isAllowed(_ destination: String, schemes: Set<String>) -> Bool {
		// `data:` and friends parse as schemes below; a bare path like
		// "notes/today.md" has no scheme and is fine to emit.
		guard let colon = destination.firstIndex(of: ":") else { return true }
		let scheme = destination[destination.startIndex..<colon].lowercased()
		return schemes.contains(scheme)
	}
}

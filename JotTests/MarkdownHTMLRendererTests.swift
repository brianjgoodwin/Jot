//
//  MarkdownHTMLRendererTests.swift
//  JotTests
//
//  Tests for the swift-markdown HTML renderer behind the preview (#30).
//  The security cases pin down the no-raw-HTML-passthrough design (#10)
//  and the link/image scheme allowlists.
//

import XCTest
@testable import Jot

final class MarkdownHTMLRendererTests: XCTestCase {

	private func render(_ markdown: String) -> String {
		MarkdownHTMLRenderer.render(markdown: markdown)
	}

	// MARK: - Core constructs

	func testHeadings() {
		XCTAssertEqual(render("# Title"), "<h1>Title</h1>\n")
		XCTAssertEqual(render("###### Deep"), "<h6>Deep</h6>\n")
	}

	func testEmphasisAndStrong() {
		XCTAssertEqual(render("*a* **b**"), "<p><em>a</em> <strong>b</strong></p>\n")
	}

	func testStrikethrough() {
		XCTAssertEqual(render("~~gone~~"), "<p><del>gone</del></p>\n")
	}

	func testInlineCode() {
		XCTAssertEqual(render("`let x = 1`"), "<p><code>let x = 1</code></p>\n")
	}

	func testFencedCodeBlockWithLanguage() {
		let html = render("```swift\nlet x = 1\n```")
		XCTAssertEqual(html, "<pre><code class=\"language-swift\">let x = 1\n</code></pre>\n")
	}

	func testCodeBlockContentIsEscapedNotParsed() {
		let html = render("```\n**not bold** <b>\n```")
		XCTAssertTrue(html.contains("**not bold** &lt;b&gt;"))
		XCTAssertFalse(html.contains("<strong>"))
	}

	func testUnorderedList() {
		XCTAssertEqual(render("- a\n- b"),
					   "<ul>\n<li><p>a</p>\n</li>\n<li><p>b</p>\n</li>\n</ul>\n")
	}

	func testOrderedListStart() {
		let html = render("3. a\n4. b")
		XCTAssertTrue(html.hasPrefix("<ol start=\"3\">"))
	}

	func testTaskList() {
		let html = render("- [x] done\n- [ ] todo")
		XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled checked />"))
		XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled />"))
	}

	func testBlockQuote() {
		XCTAssertEqual(render("> quoted"), "<blockquote>\n<p>quoted</p>\n</blockquote>\n")
	}

	func testThematicBreak() {
		XCTAssertEqual(render("---"), "<hr />\n")
	}

	func testLink() {
		XCTAssertEqual(render("[Jot](https://example.com)"),
					   "<p><a href=\"https://example.com\">Jot</a></p>\n")
	}

	func testLinkTitle() {
		XCTAssertEqual(render("[Jot](https://example.com \"a note editor\")"),
					   "<p><a href=\"https://example.com\" title=\"a note editor\">Jot</a></p>\n")
	}

	func testLinkTitleQuoteCannotBreakOutOfAttribute() {
		let html = render("[x](https://example.com \"a \\\" b\")")
		XCTAssertTrue(html.contains("title=\"a &quot; b\""))
	}

	func testImage() {
		XCTAssertEqual(render("![alt text](https://example.com/i.png)"),
					   "<p><img src=\"https://example.com/i.png\" alt=\"alt text\" /></p>\n")
	}

	func testTableWithAlignment() {
		let html = render("| a | b |\n|:--|--:|\n| 1 | 2 |")
		XCTAssertTrue(html.contains("<th scope=\"col\" style=\"text-align: left\">a</th>"))
		XCTAssertTrue(html.contains("<th scope=\"col\" style=\"text-align: right\">b</th>"))
		XCTAssertTrue(html.contains("<td style=\"text-align: left\">1</td>"))
	}

	func testColspanKeepsAlignmentColumnsAligned() {
		// The spanned-over position appears as a colspan-0 placeholder
		// cell in the AST; grid-column tracking must skip it so the last
		// cell still gets column 2's alignment.
		let html = render("| a | b | c |\n|:--|:-:|--:|\n| 1 || 3 |")
		XCTAssertTrue(html.contains("<td colspan=\"2\" style=\"text-align: left\">1</td>"),
					  "got: \(html)")
		XCTAssertTrue(html.contains("<td style=\"text-align: right\">3</td>"), "got: \(html)")
	}

	func testTableParsesWithCRLFLineEndings() {
		let html = render("| a | b |\r\n|---|---|\r\n| 1 | 2 |")
		XCTAssertTrue(html.contains("<table>"), "CRLF documents should still parse tables, got: \(html)")
	}

	func testTableParsesDirectlyAfterParagraph() {
		let html = render("intro\n| a | b |\n|---|---|\n| 1 | 2 |")
		XCTAssertTrue(html.contains("<table>"), "table without preceding blank line should parse, got: \(html)")
	}

	func testTableParsesWithoutOuterPipes() {
		let html = render("a | b\n--|--\n1 | 2")
		XCTAssertTrue(html.contains("<table>"), "pipe-light table should parse, got: \(html)")
	}

	func testTableAfterClosedCodeFence() {
		let markdown = """
		```
		| a | b |
		|---|---|
		```

		| a | b |
		|---|---|
		| 1 | 2 |
		"""
		let html = render(markdown)
		XCTAssertTrue(html.contains("<pre><code>"), "fenced example should stay literal")
		XCTAssertTrue(html.contains("<table>"), "bare table after a closed fence should render")
	}

	func testUnclosedFenceSwallowsRestOfDocument() {
		// CommonMark behavior, same as Down/cmark: an unclosed fence runs to
		// end of document, so everything after it renders as literal code.
		let markdown = "# Title\n\n```\n| a | b |\n|---|---|\n| 1 | 2 |"
		let html = render(markdown)
		XCTAssertTrue(html.contains("<h1>Title</h1>"))
		XCTAssertFalse(html.contains("<table>"))
		XCTAssertTrue(html.contains("<pre><code>"))
	}

	func testHardLineBreak() {
		XCTAssertEqual(render("a  \nb"), "<p>a<br />\nb</p>\n")
	}

	// MARK: - Security: no raw HTML passthrough (#10)

	func testHTMLBlockIsEscapedInsideCodeBlock() {
		let html = render("<script>alert(1)</script>")
		XCTAssertFalse(html.contains("<script>"))
		XCTAssertTrue(html.contains("<pre><code>&lt;script&gt;alert(1)&lt;/script&gt;"))
	}

	func testInlineHTMLIsEscapedInsideCode() {
		let html = render("hello <b onclick=\"x()\">there</b>")
		XCTAssertFalse(html.contains("<b "))
		XCTAssertTrue(html.contains("<code>&lt;b onclick="))
	}

	func testRawHTMLInImageAltIsEscaped() {
		// Image.plainText passes raw inline HTML through verbatim; the
		// alt attribute emission must escape it.
		let html = render("![<img src=x onerror=alert(1)>](https://example.com/i.png)")
		XCTAssertFalse(html.contains("alt=\"<img"))
		XCTAssertTrue(html.contains("alt=\"&lt;img src=x onerror=alert(1)&gt;\""))
	}

	func testTextSpecialCharactersAreEscaped() {
		XCTAssertEqual(render("a < b & c > d"), "<p>a &lt; b &amp; c &gt; d</p>\n")
	}

	// MARK: - Security: scheme allowlists

	func testJavascriptLinkRendersAsPlainText() {
		let html = render("[click](javascript:alert(1))")
		XCTAssertFalse(html.contains("<a "))
		XCTAssertTrue(html.contains("click"))
	}

	func testRelativeLinkIsKept() {
		XCTAssertEqual(render("[notes](notes/today.md)"),
					   "<p><a href=\"notes/today.md\">notes</a></p>\n")
	}

	func testRelativeLinksWithColonsAfterDelimitersAreKept() {
		// A colon after "/", "?", or "#" is not a scheme delimiter
		// (RFC 3986); these are relative references, not URLs.
		XCTAssertTrue(render("[s](#sec:1)").contains("<a href=\"#sec:1\">"))
		XCTAssertTrue(render("[f](docs/a:b.md)").contains("<a href=\"docs/a:b.md\">"))
		XCTAssertTrue(render("[q](?x=a:b)").contains("<a href=\"?x=a:b\">"))
	}

	func testSchemeShapedPrefixNotOnAllowlistFailsClosed() {
		XCTAssertFalse(render("[x](ftp://example.com)").contains("<a "))
		XCTAssertFalse(render("[x](vbscript:evil)").contains("<a "))
	}

	func testProtocolRelativeLinkRendersAsPlainText() {
		// //host names a remote host without a scheme; it must never
		// reach the navigation delegate's NSWorkspace hand-off.
		let html = render("[x](//evil.example/path)")
		XCTAssertFalse(html.contains("<a "))
		XCTAssertTrue(html.contains("x"))
	}

	func testFootnoteSyntaxIsNotYetSupported() {
		// No footnote extension in swift-markdown 0.8.0: [^1] parses as
		// a link reference definition. Real footnotes are #39; this pins
		// the interim behavior so #39 starts from a known state.
		XCTAssertEqual(render("text[^1]\n\n[^1]: note"),
					   "<p>text<a href=\"note\">^1</a></p>\n")
	}

	// MARK: - Security: data: image hardening

	func testRasterDataImageIsKept() {
		let html = render("![dot](data:image/png;base64,iVBORw0KGgo=)")
		XCTAssertTrue(html.contains("<img src=\"data:image/png;base64,iVBORw0KGgo=\""))
	}

	func testNonRasterDataImageRendersAsAltText() {
		// SVG can carry script and text/html is a document; neither may
		// reach WebKit's loader from untrusted markdown.
		let svg = render("![alt](data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=)")
		XCTAssertFalse(svg.contains("<img"))
		XCTAssertTrue(svg.contains("alt"))
		let html = render("![alt](data:text/html;base64,PGI+PC9iPg==)")
		XCTAssertFalse(html.contains("<img"))
	}

	func testHTTPImageRendersAsAltText() {
		// The CSP never allows cleartext image loads, so emitting the
		// img would guarantee a broken image; alt text is better.
		let html = render("![alt text](http://example.com/i.png)")
		XCTAssertFalse(html.contains("<img"))
		XCTAssertTrue(html.contains("alt text"))
	}

	func testQuoteBreakoutInLinkDestinationIsEscaped() {
		let html = render("[x](https://example.com/\"><script>)")
		XCTAssertFalse(html.contains("\"><script>"))
	}
}

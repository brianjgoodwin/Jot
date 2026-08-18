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

	func testImage() {
		XCTAssertEqual(render("![alt text](https://example.com/i.png)"),
					   "<p><img src=\"https://example.com/i.png\" alt=\"alt text\" /></p>\n")
	}

	func testTableWithAlignment() {
		let html = render("| a | b |\n|:--|--:|\n| 1 | 2 |")
		XCTAssertTrue(html.contains("<th style=\"text-align: left\">a</th>"))
		XCTAssertTrue(html.contains("<th style=\"text-align: right\">b</th>"))
		XCTAssertTrue(html.contains("<td style=\"text-align: left\">1</td>"))
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

	func testHardLineBreak() {
		XCTAssertEqual(render("a  \nb"), "<p>a<br />\nb</p>\n")
	}

	// MARK: - Security: no raw HTML passthrough (#10)

	func testHTMLBlockIsEscaped() {
		let html = render("<script>alert(1)</script>")
		XCTAssertFalse(html.contains("<script>"))
		XCTAssertTrue(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
	}

	func testInlineHTMLIsEscaped() {
		let html = render("hello <b onclick=\"x()\">there</b>")
		XCTAssertFalse(html.contains("<b "))
		XCTAssertTrue(html.contains("&lt;b onclick="))
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

	func testQuoteBreakoutInLinkDestinationIsEscaped() {
		let html = render("[x](https://example.com/\"><script>)")
		XCTAssertFalse(html.contains("\"><script>"))
	}
}

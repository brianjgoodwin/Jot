//
//  PreviewShellTests.swift
//  JotTests
//
//  Created on 8/19/26.
//
//  Pins the preview's HTML shell (#38): document structure, the CSP
//  posture (#134), the accessibility affordances baked into the head
//  (#52), and the theme rules that exist to fix specific rendering
//  problems. Pure string assertions -- no WKWebView, no UI.
//

import XCTest
@testable import Jot

final class PreviewShellTests: XCTestCase {

	private func makeDocument(title: String = "Test",
							  body: String = "<p>hello</p>",
							  remoteImages: Bool = false,
							  languageTag: String = "en") -> String {
		PreviewShell.document(title: title, bodyHTML: body,
							  loadRemoteImages: remoteImages,
							  languageTag: languageTag)
	}

	// MARK: - Document structure

	func testDocumentWrapsBodyVerbatim() {
		let html = makeDocument(body: "<p>alpha &amp; omega</p>")
		XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"))
		XCTAssertTrue(html.contains("<body>\n<p>alpha &amp; omega</p>\n</body>"))
		XCTAssertTrue(html.contains("<meta charset=\"utf-8\">"))
	}

	func testTitleIsEscaped() {
		let html = makeDocument(title: "Q3 <plan> & \"notes\"")
		XCTAssertTrue(html.contains("<title>Q3 &lt;plan&gt; &amp; &quot;notes&quot;</title>"))
		XCTAssertFalse(html.contains("<plan>"))
	}

	// MARK: - Accessibility head state (#52)

	func testLanguageTagIsEmitted() {
		let html = makeDocument(languageTag: "en-US")
		XCTAssertTrue(html.contains("<html lang=\"en-US\">"))
	}

	func testMalformedLanguageTagFallsBackToEnglish() {
		// A tag that could escape the attribute must be rejected, not
		// emitted; same for one that is simply not BCP-47 shaped.
		for bad in ["en\"><script>", "en US", ""] {
			let html = makeDocument(languageTag: bad)
			XCTAssertTrue(html.contains("<html lang=\"en\">"), "tag: \(bad)")
		}
	}

	func testDeclaresBothColorSchemes() {
		XCTAssertTrue(makeDocument().contains(
			"<meta name=\"color-scheme\" content=\"light dark\">"))
	}

	// MARK: - Content Security Policy (#134)

	func testCSPWithRemoteImagesOff() {
		XCTAssertTrue(makeDocument(remoteImages: false).contains(
			"content=\"default-src 'none'; style-src 'unsafe-inline'; img-src data:;\""))
	}

	func testCSPWithRemoteImagesOn() {
		XCTAssertTrue(makeDocument(remoteImages: true).contains(
			"content=\"default-src 'none'; style-src 'unsafe-inline'; img-src https: data:;\""))
	}

	// MARK: - Theme injection

	func testThemeCSSLandsInStyleBlock() {
		let theme = PreviewTheme(name: "Marker", css: "body { --marker: 1; }")
		let html = PreviewShell.document(title: "t", bodyHTML: "<p>x</p>",
										 theme: theme, loadRemoteImages: false)
		XCTAssertTrue(html.contains("body { --marker: 1; }"))
		XCTAssertFalse(html.contains("--table-border"),
					   "the default theme must not leak in alongside a custom one")
	}

	// MARK: - Standard theme rules that fix specific problems

	// The renderer wraps every list item's text in <p> because
	// swift-markdown does not expose list tightness; the theme collapses
	// those margins (rebuild plan, "deferred notes"). :only-of-type, not
	// :only-child, so checkbox and nested-list items still collapse.
	func testStandardThemeCollapsesTightListParagraphs() {
		XCTAssertTrue(PreviewTheme.standard.css.contains("li > p:only-of-type { margin: 0; }"))
	}

	// A task-list item is <li><input/> <p>text</p></li>; without this the
	// block <p> drops the text below its checkbox.
	func testStandardThemeKeepsTaskListTextInline() {
		XCTAssertTrue(PreviewTheme.standard.css.contains("li > input[type=\"checkbox\"] + p { display: inline; }"))
	}

	func testStandardThemeStylesDarkModeAndPrint() {
		let css = PreviewTheme.standard.css
		XCTAssertTrue(css.contains("@media (prefers-color-scheme: dark)"))
		XCTAssertTrue(css.contains("@media print"))
		XCTAssertTrue(css.contains("color-scheme: light dark"))
	}
}

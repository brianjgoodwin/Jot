//
//  EditorTextViewTests.swift
//  JotTests
//
//  Tests for the paste-URL-over-selection link wrapping (#145). The
//  decision function is pure; the paste plumbing itself is exercised by
//  hand (it needs a live pasteboard and first responder).
//

import XCTest
@testable import Jot

@MainActor
final class EditorTextViewTests: XCTestCase {

	func testHTTPSURLWrapsSelection() {
		XCTAssertEqual(
			EditorTextView.markdownLink(wrapping: "the docs", around: "https://example.com/docs"),
			"[the docs](https://example.com/docs)")
	}

	func testHTTPURLWrapsSelection() {
		XCTAssertEqual(
			EditorTextView.markdownLink(wrapping: "old site", around: "http://example.com"),
			"[old site](http://example.com)")
	}

	func testCopiedURLWithTrailingNewlineIsTrimmed() {
		XCTAssertEqual(
			EditorTextView.markdownLink(wrapping: "docs", around: "https://example.com\n"),
			"[docs](https://example.com)")
	}

	func testUppercaseSchemeWraps() {
		// URLs copied from some apps arrive with an uppercased scheme
		XCTAssertEqual(
			EditorTextView.markdownLink(wrapping: "docs", around: "HTTPS://example.com"),
			"[docs](HTTPS://example.com)")
	}

	func testProseDoesNotWrap() {
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: "just some words"))
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: "visit https://example.com today"))
	}

	func testNonHTTPSchemesDoNotWrap() {
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: "ftp://example.com/file"))
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: "mailto:someone@example.com"))
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: "file:///etc/hosts"))
	}

	func testBareDomainWithoutSchemeDoesNotWrap() {
		// Requiring a scheme keeps ordinary words like "example.com" (or
		// "index.html") from being treated as URLs.
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: "example.com"))
	}

	func testSchemeWithoutHostDoesNotWrap() {
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: "https://"))
	}

	func testEmptyPasteboardStringDoesNotWrap() {
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: ""))
		XCTAssertNil(EditorTextView.markdownLink(wrapping: "sel", around: "  \n"))
	}

	func testExistingMarkdownLinkSelectionFallsThrough() {
		XCTAssertNil(EditorTextView.markdownLink(
			wrapping: "[docs](https://old.example.com)",
			around: "https://new.example.com"))
	}

	func testMultilineSelectionFallsThrough() {
		XCTAssertNil(EditorTextView.markdownLink(
			wrapping: "line one\nline two",
			around: "https://example.com"))
	}
}

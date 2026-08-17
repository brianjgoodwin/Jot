//
//  EditorModeTests.swift
//  JotTests
//
//  Tests for the initial-mode inference from the document type (#158).
//  The filename extension is the primary signal: .md's UTI resolves to
//  whatever markdown app on the machine exports its own type (iA Writer's
//  net.ia.markdown, for one), so the UTI alone is machine-dependent.
//

import XCTest
@testable import Jot

final class EditorModeTests: XCTestCase {

	// MARK: - Extension signal

	func testMarkdownExtensionsInferMarkdownMode() {
		for ext in ["md", "markdown", "mdown"] {
			XCTAssertEqual(
				EditorMode.inferred(fromTypeIdentifier: "public.plain-text", filenameExtension: ext),
				.markdown, "\(ext) files must open in markdown mode")
		}
	}

	func testExtensionMatchIsCaseInsensitive() {
		XCTAssertEqual(
			EditorMode.inferred(fromTypeIdentifier: nil, filenameExtension: "MD"),
			.markdown)
	}

	func testForeignMarkdownUTIWithMarkdownExtensionInfersMarkdownMode() {
		// The real-world case this exists for: another app exports its own
		// markdown UTI, so the identifier is unrecognizable but the
		// extension still says markdown
		XCTAssertEqual(
			EditorMode.inferred(fromTypeIdentifier: "com.example.other-apps-markdown", filenameExtension: "md"),
			.markdown)
	}

	func testTextExtensionInfersPlainTextMode() {
		XCTAssertEqual(
			EditorMode.inferred(fromTypeIdentifier: "public.plain-text", filenameExtension: "txt"),
			.plainText)
	}

	// MARK: - UTI signal (no URL)

	func testMarkdownTypeWithoutExtensionInfersMarkdownMode() {
		XCTAssertEqual(
			EditorMode.inferred(fromTypeIdentifier: "net.daringfireball.markdown", filenameExtension: nil),
			.markdown)
	}

	func testPlainTextTypeInfersPlainTextMode() {
		// Markdown conforms to plain text, but not the other way around —
		// a plain .txt file must not open styled
		XCTAssertEqual(
			EditorMode.inferred(fromTypeIdentifier: "public.plain-text", filenameExtension: nil),
			.plainText)
	}

	func testOtherDeclaredTypesInferPlainTextMode() {
		for identifier in ["public.json", "public.xml", "public.source-code"] {
			XCTAssertEqual(
				EditorMode.inferred(fromTypeIdentifier: identifier, filenameExtension: nil),
				.plainText, "\(identifier) must open in plain text mode")
		}
	}

	func testNilTypeAndExtensionInfersPlainTextMode() {
		// Untitled documents
		XCTAssertEqual(
			EditorMode.inferred(fromTypeIdentifier: nil, filenameExtension: nil),
			.plainText)
	}

	func testUnknownTypeInfersPlainTextMode() {
		XCTAssertEqual(
			EditorMode.inferred(fromTypeIdentifier: "com.example.not-a-real-type", filenameExtension: nil),
			.plainText)
	}
}

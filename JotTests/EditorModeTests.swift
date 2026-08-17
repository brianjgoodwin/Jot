//
//  EditorModeTests.swift
//  JotTests
//
//  Tests for the initial-mode inference from the document type (#158).
//

import XCTest
@testable import Jot

final class EditorModeTests: XCTestCase {

	func testMarkdownTypeInfersMarkdownMode() {
		XCTAssertEqual(EditorMode.inferred(fromTypeIdentifier: "net.daringfireball.markdown"), .markdown)
	}

	func testPlainTextTypeInfersPlainTextMode() {
		// Markdown conforms to plain text, but not the other way around —
		// a plain .txt file must not open styled
		XCTAssertEqual(EditorMode.inferred(fromTypeIdentifier: "public.plain-text"), .plainText)
	}

	func testOtherDeclaredTypesInferPlainTextMode() {
		XCTAssertEqual(EditorMode.inferred(fromTypeIdentifier: "public.json"), .plainText)
		XCTAssertEqual(EditorMode.inferred(fromTypeIdentifier: "public.xml"), .plainText)
		XCTAssertEqual(EditorMode.inferred(fromTypeIdentifier: "public.source-code"), .plainText)
	}

	func testNilTypeInfersPlainTextMode() {
		// Untitled documents and anything else without a resolvable type
		XCTAssertEqual(EditorMode.inferred(fromTypeIdentifier: nil), .plainText)
	}

	func testUnknownTypeInfersPlainTextMode() {
		XCTAssertEqual(EditorMode.inferred(fromTypeIdentifier: "com.example.not-a-real-type"), .plainText)
	}
}

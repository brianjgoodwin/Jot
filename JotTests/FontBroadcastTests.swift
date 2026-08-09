//
//  FontBroadcastTests.swift
//  JotTests
//
//  Tests for the font-change broadcast (#124): FontConfiguration changes
//  must reach every open editor and persist without one, replacing the
//  1:1 delegate that only updated whichever window was main when
//  Settings opened.
//

import XCTest
@testable import Jot

@MainActor
final class FontBroadcastTests: XCTestCase {

	// FontConfiguration persists through UserDefaults.standard. Each test
	// wraps itself in this so the developer's real preferences survive;
	// no stored fixtures — XCTest's setUp is nonisolated under Swift 6
	// (same reasoning as EditorFormattingTests).
	private func withSavedFontPreferences(_ body: () throws -> Void) rethrows {
		let savedFontName = PreferencesManager.shared.fontName
		let savedFontSize = PreferencesManager.shared.fontSize
		let savedConfigSize = FontConfiguration.shared.currentSize
		defer {
			FontConfiguration.shared.applySize(savedConfigSize)
			PreferencesManager.shared.fontName = savedFontName
			PreferencesManager.shared.fontSize = savedFontSize
		}
		try body()
	}

	private func makeEditor() throws -> (Document, EditorViewController) {
		let document = Document()
		document.makeWindowControllers()
		let editor = try XCTUnwrap(
			document.windowControllers.first?.contentViewController as? EditorViewController
		)
		return (document, editor)
	}

	func testSizeChangeReachesEveryOpenEditor() throws {
		try withSavedFontPreferences {
			let (doc1, editor1) = try makeEditor()
			defer { doc1.close() }
			let (doc2, editor2) = try makeEditor()
			defer { doc2.close() }

			let newSize = FontConfiguration.shared.currentSize + 3
			FontConfiguration.shared.applySize(newSize)

			XCTAssertEqual(editor1.textView.font?.pointSize, newSize)
			XCTAssertEqual(editor2.textView.font?.pointSize, newSize)
		}
	}

	func testSizeChangePersistsWithoutAnyEditorOpen() {
		withSavedFontPreferences {
			let newSize = FontConfiguration.shared.currentSize + 2
			FontConfiguration.shared.applySize(newSize)

			XCTAssertEqual(PreferencesManager.shared.fontSize, newSize)
		}
	}

	func testSizeOnlyChangeDoesNotPersistAFontName() {
		withSavedFontPreferences {
			// A user who never chose a font must not get the system font's
			// dot-prefixed name written into preferences — NSFont(name:)
			// round-trips those unreliably across OS versions.
			PreferencesManager.shared.fontName = nil
			FontConfiguration.shared.applySize(FontConfiguration.shared.currentSize + 1)

			XCTAssertNil(PreferencesManager.shared.fontName)
		}
	}

	func testFontChangePostsExactlyOneNotification() {
		withSavedFontPreferences {
			// applyFont adopts font and size together: one change, one
			// restyle. assertForOverFulfill catches a double post.
			let expectation = XCTNSNotificationExpectation(
				name: FontConfiguration.didChangeNotification)
			expectation.assertForOverFulfill = true

			FontConfiguration.shared.applyFont(
				NSFont.systemFont(ofSize: FontConfiguration.shared.currentSize))

			wait(for: [expectation], timeout: 1)
		}
	}

	func testIncreaseAndDecreaseFontSizeActions() throws {
		try withSavedFontPreferences {
			let (doc, editor) = try makeEditor()
			defer { doc.close() }

			let start = FontConfiguration.shared.currentSize
			editor.increaseFontSize(self)
			XCTAssertEqual(FontConfiguration.shared.currentSize, start + 1)
			XCTAssertEqual(PreferencesManager.shared.fontSize, start + 1)

			editor.decreaseFontSize(self)
			XCTAssertEqual(FontConfiguration.shared.currentSize, start)
		}
	}
}

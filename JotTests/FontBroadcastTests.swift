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
	//
	// FontConfiguration.shared is a process-lifetime singleton, so restoring
	// only the defaults keys would leave the in-memory font mutated for
	// every later test in the run. currentFont is restored too.
	private func withSavedFontPreferences(_ body: () throws -> Void) rethrows {
		let savedFontName = PreferencesManager.shared.fontName
		let savedFontSize = PreferencesManager.shared.fontSize
		let savedFont = FontConfiguration.shared.resolvedFont()
		defer {
			FontConfiguration.shared.applyFont(savedFont)
			PreferencesManager.shared.fontName = savedFontName
			PreferencesManager.shared.fontSize = savedFontSize
		}
		// Start from a known size: several tests below decrement toward the
		// floor or assert against the persisted value, and inheriting
		// whatever the previous test left behind couples them to run order.
		FontConfiguration.shared.applySize(12)
		try body()
	}

	// Closes the document on failure rather than leaving it and its editor
	// alive as a stray font observer for the rest of the run — the caller's
	// defer isn't registered until after this returns.
	private func makeEditor() throws -> (Document, EditorViewController) {
		let document = Document()
		document.makeWindowControllers()
		guard let editor = document.windowControllers.first?.contentViewController
				as? EditorViewController else {
			document.close()
			XCTFail("document window controller should host an EditorViewController")
			throw XCTSkip("no editor to test")
		}
		// viewWillAppear registers the font observer; makeWindowControllers
		// alone doesn't run it in a headless test
		editor.viewWillAppear()
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

	// MARK: - Bigger/Smaller: per-window temporary zoom (#124 follow-up)

	func testBiggerIsAPerWindowOverride() throws {
		try withSavedFontPreferences {
			let (doc1, editor1) = try makeEditor()
			defer { doc1.close() }
			let (doc2, editor2) = try makeEditor()
			defer { doc2.close() }

			// A known non-nil persisted size: asserting against nil would
			// pass whether or not the zoom wrote to defaults
			FontConfiguration.shared.applySize(14)
			let globalSize = FontConfiguration.shared.currentSize
			XCTAssertEqual(PreferencesManager.shared.fontSize, 14)

			editor1.increaseFontSize(self)

			XCTAssertEqual(editor1.textView.font?.pointSize, globalSize + 1)
			// Display-only: the other window, the shared configuration,
			// and the persisted preference are all untouched
			XCTAssertEqual(editor2.textView.font?.pointSize, globalSize)
			XCTAssertEqual(FontConfiguration.shared.currentSize, globalSize)
			XCTAssertEqual(PreferencesManager.shared.fontSize, 14)
		}
	}

	func testActualSizeClearsTheZoom() throws {
		try withSavedFontPreferences {
			let (doc, editor) = try makeEditor()
			defer { doc.close() }

			let globalSize = FontConfiguration.shared.currentSize
			editor.increaseFontSize(self)
			editor.increaseFontSize(self)
			XCTAssertEqual(editor.textView.font?.pointSize, globalSize + 2)

			editor.resetFontSize(self)
			XCTAssertEqual(editor.textView.font?.pointSize, globalSize)
		}
	}

	func testActualSizeIsDisabledWhenNotZoomed() throws {
		try withSavedFontPreferences {
			let (doc, editor) = try makeEditor()
			defer { doc.close() }

			let item = NSMenuItem(
				title: "Actual Size",
				action: #selector(EditorViewController.resetFontSize(_:)),
				keyEquivalent: "0")
			XCTAssertFalse(editor.validateMenuItem(item),
						   "Actual Size answers 'is this window zoomed?' — dimmed when it isn't")

			editor.increaseFontSize(self)
			XCTAssertTrue(editor.validateMenuItem(item))

			editor.resetFontSize(self)
			XCTAssertFalse(editor.validateMenuItem(item))
		}
	}

	func testBiggerCeilingHolds() throws {
		try withSavedFontPreferences {
			let (doc, editor) = try makeEditor()
			defer { doc.close() }

			for _ in 0..<400 { editor.increaseFontSize(self) }
			XCTAssertEqual(editor.textView.font?.pointSize, 288)
		}
	}

	func testSmallerFloorsAtSixPoints() throws {
		try withSavedFontPreferences {
			let (doc, editor) = try makeEditor()
			defer { doc.close() }

			for _ in 0..<50 { editor.decreaseFontSize(self) }
			XCTAssertEqual(editor.textView.font?.pointSize, 6)
		}
	}

	func testZoomSurvivesAStateRestorationRoundTrip() throws {
		try withSavedFontPreferences {
			let (doc, editor) = try makeEditor()
			defer { doc.close() }

			editor.increaseFontSize(self)
			editor.increaseFontSize(self)
			let zoomedSize = try XCTUnwrap(editor.textView.font?.pointSize)

			let archiver = NSKeyedArchiver(requiringSecureCoding: true)
			editor.encodeRestorableState(with: archiver)
			archiver.finishEncoding()

			let (doc2, editor2) = try makeEditor()
			defer { doc2.close() }
			let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
			unarchiver.requiresSecureCoding = true
			editor2.restoreState(with: unarchiver)

			XCTAssertEqual(editor2.textView.font?.pointSize, zoomedSize,
						   "a restored window should look like the one that was closed")
		}
	}

	func testSettingsChangeResetsWindowZoom() throws {
		try withSavedFontPreferences {
			let (doc, editor) = try makeEditor()
			defer { doc.close() }

			editor.increaseFontSize(self)
			editor.increaseFontSize(self)

			// A global change snaps the window back — deliberate: Settings
			// doubles as reset-zoom-everywhere
			let newGlobal = FontConfiguration.shared.currentSize + 5
			FontConfiguration.shared.applySize(newGlobal)

			XCTAssertEqual(editor.textView.font?.pointSize, newGlobal)
		}
	}
}

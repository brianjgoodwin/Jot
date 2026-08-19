//
//  PreferencesManagerTests.swift
//  JotTests
//
//  Tests for PreferencesManager: UserDefaults persistence round-trips,
//  default values, and edge cases.
//

import XCTest
@testable import Jot

@MainActor
final class PreferencesManagerTests: XCTestCase {

    // A fresh throwaway suite per test (#174): the developer's real
    // preferences are never read or written, even if the run dies
    // mid-test — the old save/restore dance depended on defer, which
    // does not run on fatalError or a cancelled run.
    private var suiteName = ""
    private var defaults: UserDefaults!

    /// Fresh instance over the throwaway suite. Computed so the
    /// MainActor-isolated init runs inside the MainActor test body,
    /// not in nonisolated setUp; PreferencesManager holds no state of
    /// its own, so a new wrapper per access reads the same store.
    private var prefs: PreferencesManager { PreferencesManager(defaults: defaults) }

    override func setUp() {
        super.setUp()
        suiteName = "JotTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        // Deletes the suite's plist from the test host container. If a
        // crash skips this, the orphan lives in the container, not in
        // the developer's preferences.
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Font name

    func testFontNameDefaultsToNil() {
        XCTAssertNil(prefs.fontName)
    }

    func testFontNamePersists() {
        prefs.fontName = "Courier New"
        XCTAssertEqual(prefs.fontName, "Courier New")
    }

    func testFontNameCanBeCleared() {
        prefs.fontName = "Helvetica"
        prefs.fontName = nil
        XCTAssertNil(prefs.fontName)
    }

    // MARK: - Font size

    func testFontSizeDefaultsToNil() {
        XCTAssertNil(prefs.fontSize)
    }

    func testFontSizePersists() {
        prefs.fontSize = 18
        XCTAssertEqual(prefs.fontSize, 18)
    }

    func testFontSizeCanBeCleared() {
        prefs.fontSize = 24
        prefs.fontSize = nil
        XCTAssertNil(prefs.fontSize)
    }

    /// Documented quirk (#174): the getter maps a stored 0 to nil, so
    /// the boundary is not a faithful round-trip at exactly this value.
    /// Not reachable through the UI today — the font system never
    /// yields a 0-point size — but if that changes, this test is the
    /// tripwire.
    func testFontSizeZeroReadsBackAsNil() {
        prefs.fontSize = 0
        XCTAssertNil(prefs.fontSize)
    }

    // MARK: - Remote images

    func testLoadRemoteImagesDefaultsToFalse() {
        XCTAssertFalse(prefs.loadRemoteImages)
    }

    func testLoadRemoteImagesCanBeEnabled() {
        prefs.loadRemoteImages = true
        XCTAssertTrue(prefs.loadRemoteImages)
    }

    func testLoadRemoteImagesCanBeDisabled() {
        prefs.loadRemoteImages = true
        prefs.loadRemoteImages = false
        XCTAssertFalse(prefs.loadRemoteImages)
    }

    // MARK: - Font loading

    func testPersistedFontNameResolvesToFont() {
        prefs.fontName = "Courier New"
        prefs.fontSize = 14

        let font = NSFont(name: prefs.fontName!, size: prefs.fontSize!)
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontName.hasPrefix("Courier"))
    }

    func testInvalidFontNameReturnsNil() {
        prefs.fontName = "NonExistentFont-12345"

        let font = NSFont(name: prefs.fontName!, size: 12)
        XCTAssertNil(font)
    }
}

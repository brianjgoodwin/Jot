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

    private let prefs = PreferencesManager.shared
    private let defaults = UserDefaults.standard

    // Save and restore all keys around each test to avoid polluting state.
    private var savedFontName: Any?
    private var savedFontSize: Any?
    private var savedAutosave: Any?

    override func setUp() {
        super.setUp()
        savedFontName = defaults.object(forKey: "selectedFontName")
        savedFontSize = defaults.object(forKey: "selectedFontSize")
        savedAutosave = defaults.object(forKey: "autosaveEnabled")

        defaults.removeObject(forKey: "selectedFontName")
        defaults.removeObject(forKey: "selectedFontSize")
        defaults.removeObject(forKey: "autosaveEnabled")
    }

    override func tearDown() {
        defaults.set(savedFontName, forKey: "selectedFontName")
        defaults.set(savedFontSize, forKey: "selectedFontSize")
        defaults.set(savedAutosave, forKey: "autosaveEnabled")
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

    // MARK: - Autosave

    func testAutosaveDefaultsToTrue() {
        XCTAssertTrue(prefs.autosaveEnabled)
    }

    func testAutosaveCanBeDisabled() {
        prefs.autosaveEnabled = false
        XCTAssertFalse(prefs.autosaveEnabled)
    }

    func testAutosaveCanBeReEnabled() {
        prefs.autosaveEnabled = false
        prefs.autosaveEnabled = true
        XCTAssertTrue(prefs.autosaveEnabled)
    }

    // MARK: - Font loading

    func testPersistedFontNameResolvesToFont() {
        prefs.fontName = "Courier New"
        prefs.fontSize = 14

        let font = NSFont(name: prefs.fontName!, size: prefs.fontSize!)
        XCTAssertNotNil(font)
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontName.hasPrefix("Courier"))
    }

    func testInvalidFontNameReturnsNil() {
        prefs.fontName = "NonExistentFont-12345"

        let font = NSFont(name: prefs.fontName!, size: 12)
        XCTAssertNil(font)
    }
}

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
    private var savedRemoteImages: Any?

    override func setUp() {
        super.setUp()
        savedFontName = defaults.object(forKey: "selectedFontName")
        savedFontSize = defaults.object(forKey: "selectedFontSize")
        savedRemoteImages = defaults.object(forKey: "loadRemoteImages")

        defaults.removeObject(forKey: "selectedFontName")
        defaults.removeObject(forKey: "selectedFontSize")
        defaults.removeObject(forKey: "loadRemoteImages")
    }

    override func tearDown() {
        defaults.set(savedFontName, forKey: "selectedFontName")
        defaults.set(savedFontSize, forKey: "selectedFontSize")
        defaults.set(savedRemoteImages, forKey: "loadRemoteImages")
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

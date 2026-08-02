//
//  DocumentTests.swift
//  JotTests
//
//  Tests for Document model: data encoding/decoding, write, and duplication.
//

import XCTest
@testable import Jot

@MainActor
final class DocumentTests: XCTestCase {

    private var savedFolder: URL?
    private var tempFolder: URL!

    override func setUp() {
        super.setUp()
        // Redirect unsaved state storage to a temp directory (#95)
        savedFolder = Document.unsavedStatesFolder
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        Document.unsavedStatesFolder = tempFolder
    }

    override func tearDown() {
        // Clean up temp directory and restore real folder
        if let folder = tempFolder {
            try? FileManager.default.removeItem(at: folder)
        }
        Document.unsavedStatesFolder = savedFolder
        super.tearDown()
    }

    // MARK: - data(ofType:)

    func testDataOfTypeReturnsUTF8Data() throws {
        let doc = Document()
        doc.text = "Hello, world!"

        let data = try doc.data(ofType: "public.plain-text")
        let decoded = String(data: data, encoding: .utf8)

        XCTAssertEqual(decoded, "Hello, world!")
    }

    func testDataOfTypeWithEmptyText() throws {
        let doc = Document()
        doc.text = ""

        let data = try doc.data(ofType: "public.plain-text")

        XCTAssertEqual(data.count, 0)
    }

    func testDataOfTypePreservesUnicode() throws {
        let doc = Document()
        doc.text = "Cafe\u{0301} -- em dash"

        let data = try doc.data(ofType: "public.plain-text")
        let decoded = String(data: data, encoding: .utf8)

        XCTAssertEqual(decoded, "Cafe\u{0301} -- em dash")
    }

    func testDataOfTypePreservesNewlines() throws {
        let doc = Document()
        doc.text = "line one\nline two\nline three"

        let data = try doc.data(ofType: "public.plain-text")
        let decoded = String(data: data, encoding: .utf8)

        XCTAssertEqual(decoded, "line one\nline two\nline three")
    }

    // MARK: - read(from:ofType:)

    func testReadFromDataSetsText() throws {
        let doc = Document()
        let input = "Some text to load"
        let data = input.data(using: .utf8)!

        try doc.read(from: data, ofType: "public.plain-text")

        XCTAssertEqual(doc.text, "Some text to load")
    }

    func testReadFromEmptyData() throws {
        let doc = Document()
        doc.text = "pre-existing"
        let data = "".data(using: .utf8)!

        try doc.read(from: data, ofType: "public.plain-text")

        XCTAssertEqual(doc.text, "")
    }

    func testReadFromDataPreservesUnicode() throws {
        let doc = Document()
        let input = "Noel \u{00EB}"
        let data = input.data(using: .utf8)!

        try doc.read(from: data, ofType: "public.plain-text")

        XCTAssertEqual(doc.text, input)
    }

    // MARK: - Round-trip

    func testDataRoundTrip() throws {
        let doc = Document()
        doc.text = "Round trip test with special chars: <>&\""

        let data = try doc.data(ofType: "public.plain-text")

        let doc2 = Document()
        try doc2.read(from: data, ofType: "public.plain-text")

        XCTAssertEqual(doc.text, doc2.text)
    }

    // MARK: - write(to:ofType:)

    func testWriteToURL() throws {
        let doc = Document()
        doc.text = "File content"

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTest_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try doc.write(to: tempURL, ofType: "public.plain-text")

        let written = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertEqual(written, "File content")
    }

    func testWriteToURLOverwritesExisting() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTest_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let doc1 = Document()
        doc1.text = "First version"
        try doc1.write(to: tempURL, ofType: "public.plain-text")

        let doc2 = Document()
        doc2.text = "Second version"
        try doc2.write(to: tempURL, ofType: "public.plain-text")

        let written = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertEqual(written, "Second version")
    }

    // MARK: - printableView()

    func testPrintableViewContainsText() {
        let doc = Document()
        doc.text = "Print me"

        let view = doc.printableView()

        guard let textView = view as? NSTextView else {
            XCTFail("printableView() should return an NSTextView")
            return
        }
        XCTAssertEqual(textView.string, "Print me")
    }

    // MARK: - autosavesInPlace

    func testAutosaveDefaultsToTrue() {
        let saved = UserDefaults.standard.object(forKey: "autosaveEnabled")
        defer { UserDefaults.standard.set(saved, forKey: "autosaveEnabled") }

        UserDefaults.standard.removeObject(forKey: "autosaveEnabled")

        XCTAssertTrue(Document.autosavesInPlace)
    }

    // MARK: - Encoding fallback

    func testReadUTF16WithBOM() throws {
        let doc = Document()
        let input = "Hello UTF-16"
        let data = input.data(using: .utf16)!  // includes BOM

        try doc.read(from: data, ofType: "public.plain-text")

        XCTAssertEqual(doc.text, input)
    }

    func testReadCP1252SmartQuotes() throws {
        let doc = Document()
        // CP1252 bytes for left/right double smart quotes: 0x93 / 0x94
        let data = Data([0x93, 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x94])

        try doc.read(from: data, ofType: "public.plain-text")

        XCTAssertTrue(doc.text.contains("Hello"))
        XCTAssertTrue(doc.text.contains("\u{201C}"))  // left double quote
        XCTAssertTrue(doc.text.contains("\u{201D}"))  // right double quote
    }

    func testReadCRLFRoundTrip() throws {
        let doc = Document()
        let input = "line one\r\nline two\r\nline three"
        let data = input.data(using: .utf8)!

        try doc.read(from: data, ofType: "public.plain-text")

        XCTAssertEqual(doc.text, input)
    }

    // MARK: - Unsaved state persistence

    func testSaveUnsavedStateCreatesFile() {
        let doc = Document()
        doc.text = "unsaved content"

        doc.saveUnsavedState()
        defer { doc.cleanUpUnsavedState() }

        XCTAssertTrue(FileManager.default.fileExists(atPath: doc.unsavedStateURL.path))
    }

    func testSaveUnsavedStateRoundTrip() throws {
        let doc = Document()
        doc.text = "round trip content"

        doc.saveUnsavedState()
        defer { doc.cleanUpUnsavedState() }

        let restored = try String(contentsOf: doc.unsavedStateURL, encoding: .utf8)
        XCTAssertEqual(restored, "round trip content")
    }

    func testSaveUnsavedStateSkipsEmptyText() {
        let doc = Document()
        doc.text = ""

        doc.saveUnsavedState()

        XCTAssertFalse(FileManager.default.fileExists(atPath: doc.unsavedStateURL.path))
    }

    func testCleanUpRemovesUnsavedFile() {
        let doc = Document()
        doc.text = "will be cleaned up"

        doc.saveUnsavedState()
        XCTAssertTrue(FileManager.default.fileExists(atPath: doc.unsavedStateURL.path))

        doc.cleanUpUnsavedState()
        XCTAssertFalse(FileManager.default.fileExists(atPath: doc.unsavedStateURL.path))
    }

    // MARK: - autosavesInPlace

    func testAutosaveRespectsPreference() {
        let savedValue = UserDefaults.standard.object(forKey: "autosaveEnabled")
        defer { UserDefaults.standard.set(savedValue, forKey: "autosaveEnabled") }

        UserDefaults.standard.set(false, forKey: "autosaveEnabled")
        XCTAssertFalse(Document.autosavesInPlace)

        UserDefaults.standard.set(true, forKey: "autosaveEnabled")
        XCTAssertTrue(Document.autosavesInPlace)
    }
}

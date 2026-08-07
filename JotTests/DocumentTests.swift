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

    // MARK: - Printing (#125)

    func testPrintableViewContainsText() {
        let doc = Document()
        doc.text = "Print me"

        let view = doc.printableView(for: NSPrintInfo())

        guard let textView = view as? NSTextView else {
            XCTFail("printableView(for:) should return an NSTextView")
            return
        }
        XCTAssertEqual(textView.string, "Print me")
    }

    func testPrintableViewMatchesPageContentWidth() {
        let doc = Document()
        doc.text = "Print me"
        let printInfo = NSPrintInfo()
        let contentWidth = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin

        let view = doc.printableView(for: printInfo)

        XCTAssertEqual(view.frame.width, contentWidth,
                       "print layout width must follow paper minus margins, not a fixed frame")
    }

    func testPrintableViewGrowsBeyondOnePageForLongDocuments() {
        let doc = Document()
        doc.text = String(repeating: "A line of sample text for pagination.\n", count: 500)
        let printInfo = NSPrintInfo()
        let contentHeight = printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin

        let view = doc.printableView(for: printInfo)

        XCTAssertGreaterThan(view.frame.height, contentHeight,
                             "a multi-page document must lay out taller than one page or printing truncates")
    }

    func testPrintOperationUsesDocumentPrintInfo() throws {
        let doc = Document()
        doc.text = "Print me"
        doc.printInfo.orientation = .landscape

        let operation = try doc.printOperation(withSettings: [:])

        XCTAssertEqual(operation.printInfo.orientation, .landscape,
                       "the operation must inherit the document's Page Setup")
        XCTAssertFalse(operation.printInfo === NSPrintInfo.shared,
                       "printing must not mutate the shared global print info")
        XCTAssertEqual(operation.printInfo.verticalPagination, .automatic)
    }

    // MARK: - autosavesInPlace

    func testAutosavesInPlaceIsAlwaysTrue() {
        XCTAssertTrue(Document.autosavesInPlace,
                      "NSDocument autosave owns crash recovery (#121); this must not regress to a preference")
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

    // MARK: - Revert to Saved (#119)

    func testRevertReloadsModelFromDisk() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotRevert_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try "saved version".write(to: tempURL, atomically: true, encoding: .utf8)

        let doc = Document()
        doc.fileURL = tempURL
        doc.text = "edited version"
        doc.updateChangeCount(.changeDone)

        try doc.revert(toContentsOf: tempURL, ofType: "public.plain-text")

        XCTAssertEqual(doc.text, "saved version")
        XCTAssertFalse(doc.isDocumentEdited, "revert should clear the change count")
    }

    func testRevertUpdatesEditorTextView() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotRevert_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try "saved version".write(to: tempURL, atomically: true, encoding: .utf8)

        let doc = Document()
        doc.fileURL = tempURL
        doc.text = "saved version"
        doc.makeWindowControllers()
        defer { doc.close() }

        guard let editor = doc.windowControllers.first?.contentViewController as? EditorViewController else {
            XCTFail("expected an EditorViewController")
            return
        }
        editor.textView.string = "edited version"
        doc.text = "edited version"

        try doc.revert(toContentsOf: tempURL, ofType: "public.plain-text")

        XCTAssertEqual(editor.textView.string, "saved version",
                       "revert must reload the visible editor, not just the model")
    }

    // MARK: - Legacy unsaved-state migration (#121)

    func testMigrationRestoresLegacyDraftAsEditedDocument() throws {
        let marker = "legacy-\(UUID().uuidString)"
        let stateURL = tempFolder.appendingPathComponent("untitled.unsaved")
        try marker.write(to: stateURL, atomically: true, encoding: .utf8)

        Document.performLegacyMigration()

        let restored = NSDocumentController.shared.documents
            .compactMap { $0 as? Document }
            .first { $0.text == marker }
        defer { restored?.close() }

        XCTAssertNotNil(restored, "migration should open a document for the legacy .unsaved file")
        XCTAssertEqual(restored?.isDocumentEdited, true,
                       "a migrated draft must be marked edited so autosave and close prompts apply")
    }

    func testMigrationStripsPathSentinel() throws {
        let marker = "named-\(UUID().uuidString)"
        let content = "jot-original-path:/tmp/original.txt\n" + marker
        let stateURL = tempFolder.appendingPathComponent("named.unsaved")
        try content.write(to: stateURL, atomically: true, encoding: .utf8)

        Document.performLegacyMigration()

        let restored = NSDocumentController.shared.documents
            .compactMap { $0 as? Document }
            .first { $0.text == marker }
        defer { restored?.close() }

        XCTAssertNotNil(restored, "sentinel line should be stripped and the body restored")
    }

    func testMigrationDeletesLegacyFiles() throws {
        let marker = "deleted-\(UUID().uuidString)"
        let stateURL = tempFolder.appendingPathComponent("untitled.unsaved")
        try marker.write(to: stateURL, atomically: true, encoding: .utf8)

        Document.performLegacyMigration()

        let restored = NSDocumentController.shared.documents
            .compactMap { $0 as? Document }
            .first { $0.text == marker }
        defer { restored?.close() }

        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path),
                       "legacy plaintext drafts must not persist after migration")
    }

    func testMigrationIgnoresOtherFiles() throws {
        let marker = "ignored-\(UUID().uuidString)"
        let url = tempFolder.appendingPathComponent("notes.txt")
        try marker.write(to: url, atomically: true, encoding: .utf8)

        Document.performLegacyMigration()

        let restored = NSDocumentController.shared.documents
            .compactMap { $0 as? Document }
            .first { $0.text == marker }

        XCTAssertNil(restored, "only .unsaved files should be migrated")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "non-.unsaved files must be left alone")
    }

}

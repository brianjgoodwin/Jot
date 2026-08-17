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

    /// Runs `body` with Document's legacy unsaved-state folder redirected to
    /// a fresh temp directory. Lives in the test methods (main actor) rather
    /// than setUp/tearDown, which XCTest declares nonisolated under Swift 6.
    private func withLegacyStateFolder(_ body: (URL) throws -> Void) throws {
        let savedFolder = Document.unsavedStatesFolder
        let tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        Document.unsavedStatesFolder = tempFolder
        defer {
            Document.unsavedStatesFolder = savedFolder
            try? FileManager.default.removeItem(at: tempFolder)
        }
        try body(tempFolder)
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

    // MARK: - Writing (NSDocument's default write, routed through data(ofType:) -- see #118)

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

        // The buffer is normalized to LF (#194) — NSTextView types "\n"
        // regardless, so a mixed-endings buffer is avoided by construction
        XCTAssertEqual(doc.text, "line one\nline two\nline three")
        XCTAssertEqual(doc.lineEnding, .crlf)

        let saved = try doc.data(ofType: "public.plain-text")
        XCTAssertEqual(String(data: saved, encoding: .utf8), input,
                       "CRLF must be restored byte-for-byte on save")
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
        try withLegacyStateFolder { tempFolder in
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
    }

    func testMigrationNamesRecoveredDrafts() throws {
        try withLegacyStateFolder { tempFolder in
            let marker = "named-draft-\(UUID().uuidString)"
            let stateURL = tempFolder.appendingPathComponent("untitled.unsaved")
            try marker.write(to: stateURL, atomically: true, encoding: .utf8)

            Document.performLegacyMigration()

            let restored = NSDocumentController.shared.documents
                .compactMap { $0 as? Document }
                .first { $0.text == marker }
            defer { restored?.close() }

            // The window title carries the recovery context instead of an
            // anonymous "Untitled" (#153)
            XCTAssertEqual(restored?.displayName, "Recovered Draft")
        }
    }

    func testRecoveredDraftTakesItsFilenameOnceSaved() throws {
        try withLegacyStateFolder { tempFolder in
            let marker = "saved-draft-\(UUID().uuidString)"
            let stateURL = tempFolder.appendingPathComponent("untitled.unsaved")
            try marker.write(to: stateURL, atomically: true, encoding: .utf8)

            Document.performLegacyMigration()

            let restored = try XCTUnwrap(
                NSDocumentController.shared.documents
                    .compactMap { $0 as? Document }
                    .first { $0.text == marker }
            )
            defer { restored.close() }
            XCTAssertEqual(restored.displayName, "Recovered Draft")

            // An overridden displayName getter would keep saying "Recovered
            // Draft" here — in the window title, the save panel, the close
            // alert, and the Word Count panel — for the life of the document
            // Save outside tempFolder: the migration removes that folder once
            // it is empty, and withLegacyStateFolder cleans it up afterward
            let saveFolder = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("JotSaveTest-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: saveFolder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: saveFolder) }

            let savedURL = saveFolder.appendingPathComponent("chapter-3.txt")
            try restored.text.write(to: savedURL, atomically: true, encoding: .utf8)
            restored.fileURL = savedURL

            XCTAssertEqual(restored.displayName, "chapter-3.txt",
                           "a saved draft must show its real filename, not the recovery placeholder")
        }
    }

    func testMigrationStripsPathSentinel() throws {
        try withLegacyStateFolder { tempFolder in
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
    }

    func testMigrationDeletesLegacyFiles() throws {
        try withLegacyStateFolder { tempFolder in
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
    }

    func testMigrationIgnoresOtherFiles() throws {
        try withLegacyStateFolder { tempFolder in
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

    // MARK: - Migration never destroys what it can't judge (#173)

    /// The archive folder the migration derives from the (overridden) state
    /// folder. Mirrors the production derivation.
    private func archiveFolder(for stateFolder: URL) -> URL {
        stateFolder.deletingLastPathComponent()
            .appendingPathComponent(stateFolder.lastPathComponent + "-Archived", isDirectory: true)
    }

    func testMigrationArchivesUnreadableDraft() throws {
        try withLegacyStateFolder { tempFolder in
            let archive = archiveFolder(for: tempFolder)
            defer { try? FileManager.default.removeItem(at: archive) }

            let badBytes = Data([0xFF, 0xFE, 0x00, 0x01])
            let stateURL = tempFolder.appendingPathComponent("bad.unsaved")
            try badBytes.write(to: stateURL)
            let documentsBefore = NSDocumentController.shared.documents.count

            Document.performLegacyMigration()

            XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path),
                           "an unreadable draft should leave the state folder")
            let archivedURL = archive.appendingPathComponent("bad.unsaved")
            XCTAssertEqual(try? Data(contentsOf: archivedURL), badBytes,
                           "the bytes must survive, parked in the archive")
            XCTAssertEqual(NSDocumentController.shared.documents.count, documentsBefore,
                           "no window should open for content that couldn't be read")
        }
    }

    func testMigrationArchivesTruncatedSentinelDraft() throws {
        try withLegacyStateFolder { tempFolder in
            let archive = archiveFolder(for: tempFolder)
            defer { try? FileManager.default.removeItem(at: archive) }

            // A sentinel line with no newline after it: the shape of a file
            // the legacy writer abandoned mid-write
            let content = "jot-original-path:/tmp/a.txt"
            let stateURL = tempFolder.appendingPathComponent("truncated.unsaved")
            try content.write(to: stateURL, atomically: true, encoding: .utf8)

            Document.performLegacyMigration()

            let archivedURL = archive.appendingPathComponent("truncated.unsaved")
            XCTAssertEqual(try? String(contentsOf: archivedURL, encoding: .utf8), content,
                           "a truncated draft must be archived intact, not deleted")
        }
    }

    func testMigrationArchiveSurvivesNameCollision() throws {
        try withLegacyStateFolder { tempFolder in
            let archive = archiveFolder(for: tempFolder)
            defer { try? FileManager.default.removeItem(at: archive) }

            let badBytes = Data([0xFF, 0xFE])
            let stateURL = tempFolder.appendingPathComponent("bad.unsaved")
            try badBytes.write(to: stateURL)
            Document.performLegacyMigration()
            // The first run archived the only file and removed the empty
            // state folder; recreate it for the second round
            try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
            try badBytes.write(to: stateURL)
            Document.performLegacyMigration()

            let archived = try FileManager.default.contentsOfDirectory(atPath: archive.path)
            XCTAssertEqual(archived.count, 2,
                           "a second draft with the same name must not overwrite the first")
        }
    }

    func testMigrationRecoversDraftEvenWhenOriginalFileIsOpen() throws {
        try withLegacyStateFolder { tempFolder in
            let marker = "unsynced-edits-\(UUID().uuidString)"
            let originalURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("open-\(UUID().uuidString).txt")
            try "older on-disk text".write(to: originalURL, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: originalURL) }

            // Simulate window restoration having already reopened the file
            let openDoc = Document()
            openDoc.fileURL = originalURL
            NSDocumentController.shared.addDocument(openDoc)
            defer { openDoc.close() }

            let content = "jot-original-path:\(originalURL.path)\n" + marker
            let stateURL = tempFolder.appendingPathComponent("named.unsaved")
            try content.write(to: stateURL, atomically: true, encoding: .utf8)

            Document.performLegacyMigration()

            let restored = NSDocumentController.shared.documents
                .compactMap { $0 as? Document }
                .first { $0.text == marker }
            defer { restored?.close() }

            // The draft holds edits the on-disk file never received; "the
            // file is open" must not discard it (#173)
            XCTAssertNotNil(restored,
                            "a draft must be recovered even when its file is already open")
            XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))
        }
    }

    func testRecoveredDraftTitleCarriesOriginalFilename() throws {
        try withLegacyStateFolder { tempFolder in
            let marker = "titled-\(UUID().uuidString)"
            let content = "jot-original-path:/tmp/chapter-3.txt\n" + marker
            let stateURL = tempFolder.appendingPathComponent("named.unsaved")
            try content.write(to: stateURL, atomically: true, encoding: .utf8)

            Document.performLegacyMigration()

            let restored = NSDocumentController.shared.documents
                .compactMap { $0 as? Document }
                .first { $0.text == marker }
            defer { restored?.close() }

            XCTAssertEqual(restored?.displayName, "Recovered Draft — chapter-3.txt",
                           "the title should let the user match the draft to its file")
        }
    }

    // MARK: - Encoding preservation (#194)

    func testCP1252RoundTripPreservesBytes() throws {
        let doc = Document()
        // 0x93/0x94 smart quotes, 0x97 em-dash — CP1252-only byte values
        let input = Data([0x93, 0x48, 0x69, 0x94, 0x97, 0x20, 0x65, 0x6E, 0x64])

        try doc.read(from: input, ofType: "public.plain-text")
        XCTAssertEqual(doc.readEncoding, .windowsCP1252)

        let saved = try doc.data(ofType: "public.plain-text")
        XCTAssertEqual(saved, input, "an untouched CP1252 file must round-trip byte-for-byte")
    }

    func testUTF8BOMIsStrippedFromBufferAndRestoredOnSave() throws {
        let doc = Document()
        let bom = Data([0xEF, 0xBB, 0xBF])
        let input = bom + Data("hello".utf8)

        try doc.read(from: input, ofType: "public.plain-text")

        XCTAssertEqual(doc.text, "hello",
                       "U+FEFF must not leak into the editor buffer")
        XCTAssertTrue(doc.hadUTF8BOM)

        let saved = try doc.data(ofType: "public.plain-text")
        XCTAssertEqual(saved, input, "the BOM bytes must be restored on save")
    }

    func testFileWithoutBOMNeverGainsOne() throws {
        let doc = Document()
        try doc.read(from: Data("plain".utf8), ofType: "public.plain-text")

        let saved = try doc.data(ofType: "public.plain-text")
        XCTAssertEqual(saved, Data("plain".utf8))
    }

    func testUnrepresentableContentFailsWithRecoverableError() throws {
        let doc = Document()
        let cp1252Bytes = Data([0x93, 0x48, 0x69, 0x94])
        try doc.read(from: cp1252Bytes, ofType: "public.plain-text")
        doc.text += " 😀"

        XCTAssertThrowsError(try doc.data(ofType: "public.plain-text")) { error in
            let nsError = error as NSError
            let options = nsError.userInfo[NSLocalizedRecoveryOptionsErrorKey] as? [String]
            XCTAssertEqual(options?.first, "Save as UTF-8",
                           "the error must offer conversion as an explicit choice, never convert silently")
            XCTAssertNotNil(nsError.userInfo[NSRecoveryAttempterErrorKey])
        }
    }

    func testEncodingRecoveryConvertsToUTF8() throws {
        let doc = Document()
        try doc.read(from: Data([0x93, 0x48, 0x69, 0x94]), ofType: "public.plain-text")
        doc.text += " 😀"

        var thrown: NSError?
        XCTAssertThrowsError(try doc.data(ofType: "public.plain-text")) { thrown = $0 as NSError }
        let attempter = try XCTUnwrap(thrown?.userInfo[NSRecoveryAttempterErrorKey] as? NSObject)

        let recovered = attempter.attemptRecovery(fromError: thrown!, optionIndex: 0)

        XCTAssertTrue(recovered)
        XCTAssertEqual(doc.readEncoding, .utf8)
        XCTAssertNoThrow(try doc.data(ofType: "public.plain-text"),
                         "after converting to UTF-8 the save must succeed")
    }

    func testFileAttributesIncludeTextEncodingXattr() throws {
        let doc = Document()
        try doc.read(from: Data([0x93, 0x48, 0x94]), ofType: "public.plain-text")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("xattr-\(UUID().uuidString).txt")
        let attributes = try doc.fileAttributesToWrite(
            to: url, ofType: "public.plain-text", for: .saveOperation, originalContentsURL: nil)

        let extended = attributes["NSFileExtendedAttributes"] as? [String: Any]
        let value = extended?["com.apple.TextEncoding"] as? Data
        XCTAssertEqual(value.flatMap { String(data: $0, encoding: .utf8) }, "windows-1252;1280",
                       "the xattr must carry the TextEdit-compatible IANA-name;CFStringEncoding pair")
    }

    func testXattrHintWinsOverDetectionLadder() throws {
        // Plain ASCII decodes as UTF-8 on the ladder's first rung; the
        // com.apple.TextEncoding hint must take precedence so the file
        // saves back in the encoding it was written with
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hint-\(UUID().uuidString).txt")
        try Data("plain ascii".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let xattrValue = "iso-8859-1;513"
        _ = xattrValue.withCString { valuePtr in
            setxattr(url.path, "com.apple.TextEncoding", valuePtr, strlen(valuePtr), 0, 0)
        }

        let doc = Document()
        try doc.read(from: url, ofType: "public.plain-text")

        XCTAssertEqual(doc.readEncoding, .isoLatin1)
        XCTAssertEqual(doc.text, "plain ascii")
    }

    // MARK: - Per-document view settings (#157)

    func testFileAttributesIncludeViewSettingsWhenOverrideSet() throws {
        let doc = Document()
        doc.modeOverride = .markdown

        let attributes = try doc.fileAttributesToWrite(
            to: URL(fileURLWithPath: "/tmp/ignored.txt"), ofType: "public.plain-text",
            for: .saveOperation, originalContentsURL: nil)

        let extended = try XCTUnwrap(attributes["NSFileExtendedAttributes"] as? [String: Any])
        let data = try XCTUnwrap(extended[Document.viewSettingsAttributeName] as? Data)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["mode"] as? String, "markdown")
    }

    func testFileAttributesOmitViewSettingsWithoutOverride() throws {
        let doc = Document()

        let attributes = try doc.fileAttributesToWrite(
            to: URL(fileURLWithPath: "/tmp/ignored.txt"), ofType: "public.plain-text",
            for: .saveOperation, originalContentsURL: nil)

        let extended = attributes["NSFileExtendedAttributes"] as? [String: Any]
        XCTAssertNil(extended?[Document.viewSettingsAttributeName],
                     "no explicit choice → no attribute — inference stays in charge")
    }

    /// The round trip the issue asks for: through writeSafely (which applies
    /// fileAttributesToWrite as part of the safe-save), not just setxattr.
    func testModeOverrideRoundTripsThroughRealSave() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotViewSettings_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let doc = Document()
        doc.text = "content"
        doc.modeOverride = .markdown
        try doc.writeSafely(to: tempURL, ofType: "public.plain-text", for: .saveAsOperation)

        let reread = Document()
        try reread.read(from: tempURL, ofType: "public.plain-text")
        XCTAssertEqual(reread.modeOverride, .markdown)
        XCTAssertEqual(reread.initialEditorMode, .markdown,
                       "the recorded choice beats the .txt inference")
    }

    func testModeOverrideReadFromExtendedAttribute() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotViewSettings_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try "content".write(to: tempURL, atomically: true, encoding: .utf8)

        let value = try XCTUnwrap(Document.viewSettingsAttributeValue(mode: .markdown))
        try value.withUnsafeBytes { buffer in
            let result = setxattr(tempURL.path, Document.viewSettingsAttributeName,
                                  buffer.baseAddress, buffer.count, 0, 0)
            if result != 0 { throw POSIXError(.EIO) }
        }

        let doc = Document()
        try doc.read(from: tempURL, ofType: "public.plain-text")
        XCTAssertEqual(doc.modeOverride, .markdown)
    }

    func testGarbageViewSettingsAttributeIsIgnored() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotViewSettings_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try "content".write(to: tempURL, atomically: true, encoding: .utf8)

        let garbage: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        setxattr(tempURL.path, Document.viewSettingsAttributeName, garbage, garbage.count, 0, 0)

        let doc = Document()
        try doc.read(from: tempURL, ofType: "public.plain-text")
        XCTAssertNil(doc.modeOverride, "an unreadable attribute degrades to inference, never an error")
        XCTAssertEqual(doc.text, "content")
    }

    func testInitialModeFallsThroughToInferenceWithoutOverride() {
        let doc = Document()
        doc.fileURL = URL(fileURLWithPath: "/tmp/notes.md")
        XCTAssertEqual(doc.initialEditorMode, .markdown, ".md inference applies when no override")

        doc.modeOverride = .plainText
        XCTAssertEqual(doc.initialEditorMode, .plainText, "the explicit choice beats inference")
    }

    func testNoteUserChangedModeWritesAttributeWithoutDirtying() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotViewSettings_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try "content".write(to: tempURL, atomically: true, encoding: .utf8)

        let doc = Document()
        doc.fileURL = tempURL
        doc.noteUserChangedMode(.markdown)

        XCTAssertEqual(doc.modeOverride, .markdown)
        XCTAssertFalse(doc.isDocumentEdited,
                       "a view-setting change must not mark the document edited")

        // On disk immediately — a crash before the next save loses nothing
        let reread = Document()
        try reread.read(from: tempURL, ofType: "public.plain-text")
        XCTAssertEqual(reread.modeOverride, .markdown)
    }

    func testNoteUserChangedModeOnUntitledDocumentStaysInMemory() {
        let doc = Document()
        doc.noteUserChangedMode(.markdown)

        XCTAssertEqual(doc.modeOverride, .markdown,
                       "held in memory until the first save writes it via fileAttributesToWrite")
        XCTAssertFalse(doc.isDocumentEdited)
    }

    func testDuplicateCarriesModeOverride() throws {
        // In memory only: the duplicate's own autosave runs before the
        // override is assigned, so disk gets it at the first explicit
        // save (#228 tracks whether that should change)
        let doc = Document()
        doc.text = "content"
        doc.modeOverride = .markdown

        let duplicated = try XCTUnwrap(doc.duplicate() as? Document)
        defer { duplicated.close() }
        XCTAssertEqual(duplicated.modeOverride, .markdown)
    }

    func testNoteUserChangedModeOnMissingFileKeepsOverride() {
        // The file was moved or deleted in Finder while the window stayed
        // open; setxattr fails with ENOENT and must not crash or lose the
        // in-memory choice
        let doc = Document()
        doc.fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotGone_\(UUID().uuidString).txt")

        doc.noteUserChangedMode(.markdown)

        XCTAssertEqual(doc.modeOverride, .markdown)
    }

    // MARK: - Review-pinned round trips (#194 follow-up)

    /// The encoding tests stop at data(ofType:); this one verifies the
    /// com.apple.TextEncoding xattr actually lands on a real saved file.
    func testTextEncodingAttributeLandsOnDiskThroughRealSave() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotEncoding_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let doc = Document()
        doc.text = "smart \u{201C}quotes\u{201D}"
        doc.readEncoding = .windowsCP1252
        try doc.writeSafely(to: tempURL, ofType: "public.plain-text", for: .saveAsOperation)

        var buffer = [UInt8](repeating: 0, count: 256)
        let length = getxattr(tempURL.path, "com.apple.TextEncoding", &buffer, buffer.count, 0, 0)
        XCTAssertGreaterThan(length, 0, "the attribute must survive the safe-save")
        XCTAssertEqual(String(bytes: buffer[0..<max(length, 0)], encoding: .utf8), "windows-1252;1280")
    }

    /// Correct today and fragile: a BOM-only file must open as empty text
    /// and save back as exactly its three bytes.
    func testBOMOnlyFileRoundTrips() throws {
        let doc = Document()
        try doc.read(from: Data([0xEF, 0xBB, 0xBF]), ofType: "public.plain-text")

        XCTAssertEqual(doc.text, "")
        XCTAssertTrue(doc.hadUTF8BOM)
        XCTAssertEqual(Array(try doc.data(ofType: "public.plain-text")), [0xEF, 0xBB, 0xBF])
    }

    func testEmptyFileRoundTripsWithoutGainingBOM() throws {
        let doc = Document()
        try doc.read(from: Data(), ofType: "public.plain-text")

        XCTAssertEqual(doc.text, "")
        XCTAssertFalse(doc.hadUTF8BOM)
        XCTAssertEqual(try doc.data(ofType: "public.plain-text").count, 0)
    }

}

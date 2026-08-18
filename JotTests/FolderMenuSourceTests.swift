//
//  FolderMenuSourceTests.swift
//  JotTests
//
//  Tests for the folder-backed dynamic submenu behind
//  File > New from Template (#161).
//

import XCTest
@testable import Jot

@MainActor
final class FolderMenuSourceTests: XCTestCase {

    /// Dummy targets for the menu item actions; the tests only assert the
    /// wiring, never fire the selectors.
    @objc private func selectItem(_ sender: Any?) {}
    @objc private func openFolder(_ sender: Any?) {}

    private func makeSource(folder: URL?) -> FolderMenuSource {
        FolderMenuSource(folder: folder,
                         fileExtensions: ["txt", "md"],
                         emptyTitle: "No Templates",
                         selectionAction: #selector(selectItem(_:)),
                         selectionTarget: self,
                         openFolderTitle: "Open Templates Folder",
                         openFolderAction: #selector(openFolder(_:)),
                         openFolderTarget: self)
    }

    /// selectionTarget nil means responder-chain dispatch (#162); the
    /// default in makeSource is self, so nil needs its own factory.
    private func makeNilSelectionTargetSource(folder: URL?) -> FolderMenuSource {
        FolderMenuSource(folder: folder,
                         fileExtensions: ["txt", "md"],
                         emptyTitle: "No Snippets",
                         selectionAction: #selector(selectItem(_:)),
                         selectionTarget: nil,
                         openFolderTitle: "Open Snippets Folder",
                         openFolderAction: #selector(openFolder(_:)),
                         openFolderTarget: self)
    }

    /// Runs `body` with a fresh temp directory that is removed afterward.
    private func withTempFolder(_ body: (URL) throws -> Void) throws {
        let tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFolder) }
        try body(tempFolder)
    }

    private func createFile(_ name: String, in folder: URL) throws {
        try "content".write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    // MARK: - files()

    func testFilesIncludesMatchingExtensionsOnly() throws {
        try withTempFolder { folder in
            try createFile("Notes.txt", in: folder)
            try createFile("Post.md", in: folder)
            try createFile("Scan.pdf", in: folder)

            let names = makeSource(folder: folder).files().map { $0.lastPathComponent }

            XCTAssertEqual(Set(names), ["Notes.txt", "Post.md"])
        }
    }

    func testFilesMatchesExtensionsCaseInsensitively() throws {
        try withTempFolder { folder in
            try createFile("NOTES.TXT", in: folder)

            let names = makeSource(folder: folder).files().map { $0.lastPathComponent }

            XCTAssertEqual(names, ["NOTES.TXT"])
        }
    }

    func testFilesSkipsHiddenFiles() throws {
        try withTempFolder { folder in
            try createFile(".hidden.txt", in: folder)
            try createFile("Visible.txt", in: folder)

            let names = makeSource(folder: folder).files().map { $0.lastPathComponent }

            XCTAssertEqual(names, ["Visible.txt"])
        }
    }

    func testFilesSortsLikeFinder() throws {
        try withTempFolder { folder in
            try createFile("Template 10.txt", in: folder)
            try createFile("Template 2.txt", in: folder)
            try createFile("Agenda.md", in: folder)

            let names = makeSource(folder: folder).files().map { $0.lastPathComponent }

            // localizedStandardCompare puts 2 before 10
            XCTAssertEqual(names, ["Agenda.md", "Template 2.txt", "Template 10.txt"])
        }
    }

    func testFilesEmptyForMissingFolder() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTests-missing-\(UUID().uuidString)", isDirectory: true)

        XCTAssertEqual(makeSource(folder: missing).files(), [])
    }

    func testFilesEmptyForNilFolder() {
        XCTAssertEqual(makeSource(folder: nil).files(), [])
    }

    // MARK: - menuNeedsUpdate

    func testMenuListsTemplatesWithoutExtensions() throws {
        try withTempFolder { folder in
            try createFile("Meeting Notes.txt", in: folder)
            try createFile("Blog Post.md", in: folder)
            let source = makeSource(folder: folder)
            let menu = NSMenu()

            source.menuNeedsUpdate(menu)

            // 2 templates + separator + open item
            XCTAssertEqual(menu.items.count, 4)
            XCTAssertEqual(menu.items[0].title, "Blog Post")
            XCTAssertEqual(menu.items[1].title, "Meeting Notes")
            XCTAssertEqual(menu.items[0].representedObject as? URL,
                           folder.appendingPathComponent("Blog Post.md"))
            XCTAssertEqual(menu.items[0].action, #selector(selectItem(_:)))
            XCTAssertTrue(menu.items[0].target === self)
            XCTAssertTrue(menu.items[2].isSeparatorItem)
            XCTAssertEqual(menu.items[3].title, "Open Templates Folder")
            XCTAssertEqual(menu.items[3].action, #selector(openFolder(_:)))
        }
    }

    func testMenuShowsDisabledEmptyStateWhenFolderIsEmpty() throws {
        try withTempFolder { folder in
            let source = makeSource(folder: folder)
            let menu = NSMenu()

            source.menuNeedsUpdate(menu)

            XCTAssertEqual(menu.items.count, 3)
            XCTAssertEqual(menu.items[0].title, "No Templates")
            // nil action leaves the item disabled via autoenablesItems
            XCTAssertNil(menu.items[0].action)
            XCTAssertTrue(menu.items[1].isSeparatorItem)
            XCTAssertEqual(menu.items[2].title, "Open Templates Folder")
        }
    }

    func testNilSelectionTargetYieldsNilItemTargets() throws {
        try withTempFolder { folder in
            try createFile("Notes.txt", in: folder)
            let source = makeNilSelectionTargetSource(folder: folder)
            let menu = NSMenu()

            source.menuNeedsUpdate(menu)

            // File item: responder-chain dispatch (#162)
            XCTAssertNil(menu.items[0].target)
            XCTAssertEqual(menu.items[0].action, #selector(selectItem(_:)))
            // Open-folder item keeps its concrete target
            XCTAssertTrue(menu.items[2].target === self)
        }
    }

    func testMenuRebuildDoesNotAccumulateItems() throws {
        try withTempFolder { folder in
            try createFile("Notes.txt", in: folder)
            let source = makeSource(folder: folder)
            let menu = NSMenu()

            source.menuNeedsUpdate(menu)
            source.menuNeedsUpdate(menu)

            XCTAssertEqual(menu.items.count, 3)
        }
    }
}

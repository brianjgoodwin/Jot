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
                         trailingItems: [.init(title: "Open Templates Folder",
                                               action: #selector(openFolder(_:)))],
                         trailingTarget: self)
    }

    /// selectionTarget nil means responder-chain dispatch (#162); the
    /// default in makeSource is self, so nil needs its own factory.
    private func makeNilSelectionTargetSource(folder: URL?) -> FolderMenuSource {
        FolderMenuSource(folder: folder,
                         fileExtensions: ["txt", "md"],
                         emptyTitle: "No Snippets",
                         selectionAction: #selector(selectItem(_:)),
                         selectionTarget: nil,
                         trailingItems: [.init(title: "Open Snippets Folder",
                                               action: #selector(openFolder(_:)))],
                         trailingTarget: self)
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

    func testFilesExcludesDirectoriesWithMatchingExtension() throws {
        try withTempFolder { folder in
            try createFile("Real.txt", in: folder)
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent("Sub.md", isDirectory: true),
                withIntermediateDirectories: false)

            let names = makeSource(folder: folder).files().map { $0.lastPathComponent }

            XCTAssertEqual(names, ["Real.txt"])
        }
    }

    /// Symlinks are deliberately excluded, even to regular files (see files()).
    func testFilesExcludesSymlinks() throws {
        try withTempFolder { folder in
            try createFile("Target.txt", in: folder)
            try FileManager.default.createSymbolicLink(
                at: folder.appendingPathComponent("Link.md"),
                withDestinationURL: folder.appendingPathComponent("Target.txt"))
            try FileManager.default.createSymbolicLink(
                at: folder.appendingPathComponent("Broken.md"),
                withDestinationURL: folder.appendingPathComponent("Gone.txt"))

            let names = makeSource(folder: folder).files().map { $0.lastPathComponent }

            XCTAssertEqual(names, ["Target.txt"])
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

    /// "Notes.txt" and "Notes.md" as bare "Notes" twice are identical
    /// visually and to VoiceOver — and behave differently, since the
    /// extension steers the template's mode (#239).
    func testMenuShowsExtensionsForCollidingBasenames() throws {
        try withTempFolder { folder in
            try createFile("Notes.txt", in: folder)
            try createFile("Notes.md", in: folder)
            try createFile("Agenda.md", in: folder)
            let source = makeSource(folder: folder)
            let menu = NSMenu()

            source.menuNeedsUpdate(menu)

            XCTAssertEqual(menu.items.prefix(3).map(\.title),
                           ["Agenda", "Notes.md", "Notes.txt"])
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

    func testMenuListsTrailingItemsInOrder() throws {
        try withTempFolder { folder in
            let source = FolderMenuSource(
                folder: folder,
                fileExtensions: ["txt", "md"],
                emptyTitle: "No Templates",
                selectionAction: #selector(selectItem(_:)),
                selectionTarget: self,
                trailingItems: [
                    .init(title: "Create New Template…", action: #selector(selectItem(_:))),
                    .init(title: "Open Templates Folder", action: #selector(openFolder(_:))),
                ],
                trailingTarget: self)
            let menu = NSMenu()

            source.menuNeedsUpdate(menu)

            // empty state + separator + two trailing items
            XCTAssertEqual(menu.items.count, 4)
            XCTAssertEqual(menu.items[2].title, "Create New Template…")
            XCTAssertEqual(menu.items[3].title, "Open Templates Folder")
            XCTAssertTrue(menu.items[2].target === self)
            XCTAssertTrue(menu.items[3].target === self)
        }
    }

    // MARK: - badgeLabel (#233, #238)

    func testBadgeLabelForTemplatesAndSnippetsFolders() throws {
        try withTempFolder { templates in
            try withTempFolder { snippets in
                let inTemplates = templates.appendingPathComponent("Meeting.md")
                let inSnippets = snippets.appendingPathComponent("Sig.txt")
                let elsewhere = FileManager.default.temporaryDirectory.appendingPathComponent("Plain.txt")

                XCTAssertEqual(FolderMenuSource.badgeLabel(for: inTemplates,
                                                           templatesFolder: templates,
                                                           snippetsFolder: snippets), "TEMPLATE")
                XCTAssertEqual(FolderMenuSource.badgeLabel(for: inSnippets,
                                                           templatesFolder: templates,
                                                           snippetsFolder: snippets), "SNIPPET")
                XCTAssertNil(FolderMenuSource.badgeLabel(for: elsewhere,
                                                         templatesFolder: templates,
                                                         snippetsFolder: snippets))
                XCTAssertNil(FolderMenuSource.badgeLabel(for: nil,
                                                         templatesFolder: templates,
                                                         snippetsFolder: snippets))
            }
        }
    }

    /// A file in a subfolder of Templates is not a template — the menu
    /// scan is not recursive, so the badge must not claim it either.
    func testBadgeLabelIgnoresSubfolders() throws {
        try withTempFolder { templates in
            let nested = templates.appendingPathComponent("Sub", isDirectory: true)
                .appendingPathComponent("Deep.md")

            XCTAssertNil(FolderMenuSource.badgeLabel(for: nested,
                                                     templatesFolder: templates,
                                                     snippetsFolder: nil))
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

//
//  MainMenuTests.swift
//  JotTests
//
//  Tests for the main menu loaded from Main.storyboard.
//

import XCTest
@testable import Jot

@MainActor
final class MainMenuTests: XCTestCase {

    private func allItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { item -> [NSMenuItem] in
            [item] + (item.submenu.map(allItems(in:)) ?? [])
        }
    }

    // Show Fonts (Cmd-T) used to open the standard Font panel, but
    // nothing in the app implements changeFont: — the panel looked
    // functional and did nothing (#171). The item was removed; Settings
    // is the single font entry point. This walks the whole menu tree so
    // the item can't quietly come back under another name or location.
    func testNoMenuItemOpensTheFontPanel() throws {
        let mainMenu = try XCTUnwrap(NSApp.mainMenu)

        let fontPanelItems = allItems(in: mainMenu).filter {
            $0.action == #selector(NSFontManager.orderFrontFontPanel(_:))
        }
        XCTAssertTrue(fontPanelItems.isEmpty)
    }

    // The Format menu carries one item per markdown command (#96).
    // Asserting on action selectors, not positions, so the menu can be
    // rearranged without breaking the tests — what matters is that
    // every command stays reachable.
    func testFormatMenuContainsTheMarkdownCommands() throws {
        let mainMenu = try XCTUnwrap(NSApp.mainMenu)
        let actions = allItems(in: mainMenu).compactMap(\.action)

        let commands: [Selector] = [
            #selector(EditorViewController.toggleBoldMarkdown(_:)),
            #selector(EditorViewController.toggleItalicMarkdown(_:)),
            #selector(EditorViewController.toggleStrikethroughMarkdown(_:)),
            #selector(EditorViewController.toggleHighlightMarkdown(_:)),
            #selector(EditorViewController.toggleBlockquote(_:)),
            #selector(EditorViewController.toggleInlineCodeMarkdown(_:)),
            #selector(EditorViewController.insertLinkMarkdown(_:)),
            #selector(EditorViewController.toggleOrderedList(_:)),
            #selector(EditorViewController.toggleUnorderedList(_:)),
            #selector(EditorViewController.toggleChecklistItem(_:)),
        ]
        for command in commands {
            XCTAssertTrue(actions.contains(command),
                          "No menu item with action \(command)")
        }
    }

    // Toggle Checklist was retitled To-do when it joined the flat
    // Format menu (#96); it keeps its Cmd-L shortcut.
    func testToDoItemKeepsItsShortcut() throws {
        let mainMenu = try XCTUnwrap(NSApp.mainMenu)
        let item = try XCTUnwrap(allItems(in: mainMenu).first {
            $0.action == #selector(EditorViewController.toggleChecklistItem(_:))
        })

        XCTAssertEqual(item.title, "To-do")
        XCTAssertEqual(item.keyEquivalent, "l")
        XCTAssertEqual(item.keyEquivalentModifierMask, .command)
    }
}

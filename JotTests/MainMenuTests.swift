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

    // The Xcode template's rich-text items (Kern, Ligatures, Baseline,
    // Show Colors, Copy/Paste Style, alignment, ruler) were removed in
    // #274: Jot documents are plain text, so anything these apply can
    // never survive a save. Walks the whole tree so none of them can
    // quietly come back.
    func testNoRichTextMenuItemsRemain() throws {
        let mainMenu = try XCTUnwrap(NSApp.mainMenu)
        let actions = allItems(in: mainMenu).compactMap(\.action)

        let richTextActions: [Selector] = [
            #selector(NSFontManager.modifyFont(_:)),
            Selector(("orderFrontColorPanel:")),
            #selector(NSTextView.copyFont(_:)),
            #selector(NSTextView.pasteFont(_:)),
            #selector(NSTextView.useStandardKerning(_:)),
            #selector(NSTextView.turnOffKerning(_:)),
            #selector(NSTextView.tightenKerning(_:)),
            #selector(NSTextView.loosenKerning(_:)),
            #selector(NSTextView.useStandardLigatures(_:)),
            #selector(NSTextView.turnOffLigatures(_:)),
            #selector(NSTextView.useAllLigatures(_:)),
            #selector(NSText.superscript(_:)),
            #selector(NSText.subscript(_:)),
            #selector(NSText.unscript(_:)),
            #selector(NSTextView.raiseBaseline(_:)),
            #selector(NSTextView.lowerBaseline(_:)),
            #selector(NSTextView.alignLeft(_:)),
            #selector(NSTextView.alignCenter(_:)),
            #selector(NSTextView.alignJustified(_:)),
            #selector(NSTextView.alignRight(_:)),
            #selector(NSTextView.toggleRuler(_:)),
            #selector(NSTextView.copyRuler(_:)),
            #selector(NSTextView.pasteRuler(_:)),
        ]
        for action in richTextActions {
            XCTAssertFalse(actions.contains(action),
                           "Rich-text menu item with action \(action) is back")
        }
    }

    // The size commands moved out of Format > Font to View as zoom,
    // which is what they are — the editor, preview, and Help window
    // all answer them per-window (#274).
    func testZoomCommandsLiveInTheViewMenu() throws {
        let mainMenu = try XCTUnwrap(NSApp.mainMenu)
        let viewMenu = try XCTUnwrap(
            mainMenu.items.first { $0.submenu?.title == "View" }?.submenu
        )
        let items = allItems(in: viewMenu)

        let zoomIn = try XCTUnwrap(items.first {
            $0.action == #selector(EditorViewController.increaseFontSize(_:))
        })
        XCTAssertEqual(zoomIn.title, "Zoom In")
        XCTAssertEqual(zoomIn.keyEquivalent, "+")

        let zoomOut = try XCTUnwrap(items.first {
            $0.action == #selector(EditorViewController.decreaseFontSize(_:))
        })
        XCTAssertEqual(zoomOut.title, "Zoom Out")

        let actualSize = try XCTUnwrap(items.first {
            $0.action == #selector(EditorViewController.resetFontSize(_:))
        })
        XCTAssertEqual(actualSize.title, "Actual Size")
    }

    // Writing Direction stays: it genuinely affects RTL editing and is
    // not a rich-text attribute (#274).
    func testWritingDirectionSurvivedTheCleanup() throws {
        let mainMenu = try XCTUnwrap(NSApp.mainMenu)
        let actions = allItems(in: mainMenu).compactMap(\.action)

        XCTAssertTrue(actions.contains(
            #selector(NSResponder.makeBaseWritingDirectionNatural(_:))))
        XCTAssertTrue(actions.contains(
            #selector(NSResponder.makeTextWritingDirectionRightToLeft(_:))))
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

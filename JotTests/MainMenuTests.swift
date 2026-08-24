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
}

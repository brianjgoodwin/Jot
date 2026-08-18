//
//  ServiceProviderTests.swift
//  JotTests
//
//  Tests for the "New Jot Note from Selection" service handler (#149).
//  The NSServices registration itself is Info.plist configuration and
//  is covered by the manual checklist, not unit tests.
//

import XCTest
@testable import Jot

@MainActor
final class ServiceProviderTests: XCTestCase {

    /// A unique pasteboard so tests never touch the general pasteboard.
    private func withPasteboard(_ body: (NSPasteboard) throws -> Void) rethrows {
        let pboard = NSPasteboard(name: NSPasteboard.Name("JotTests-\(UUID().uuidString)"))
        defer { pboard.releaseGlobally() }
        try body(pboard)
    }

    private func appDelegate() throws -> AppDelegate {
        try XCTUnwrap(NSApp.delegate as? AppDelegate)
    }

    func testServiceCreatesDocumentFromPasteboardText() throws {
        try withPasteboard { pboard in
            let marker = "service-\(UUID().uuidString)"
            pboard.clearContents()
            pboard.setString(marker, forType: .string)
            var serviceError: NSString?

            try appDelegate().newJotNoteFromSelection(pboard, userData: nil, error: &serviceError)

            let created = NSDocumentController.shared.documents
                .compactMap { $0 as? Document }
                .first { $0.text == marker }
            defer { created?.close() }

            XCTAssertNil(serviceError)
            XCTAssertNotNil(created, "the service should open a draft holding the selection")
            XCTAssertEqual(created?.isDocumentEdited, true)
        }
    }

    func testServiceWithoutTextReportsErrorAndAddsNoDocument() throws {
        try withPasteboard { pboard in
            pboard.clearContents()
            var serviceError: NSString?
            let countBefore = NSDocumentController.shared.documents.count

            try appDelegate().newJotNoteFromSelection(pboard, userData: nil, error: &serviceError)

            XCTAssertNotNil(serviceError)
            XCTAssertEqual(NSDocumentController.shared.documents.count, countBefore)
        }
    }
}

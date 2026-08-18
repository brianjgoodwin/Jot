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

    /// The cold-launch suppression flag must only arm during launch —
    /// a service invoked while the app is running (this test host) must
    /// not swallow the next dock-click untitled window.
    func testServiceAfterLaunchDoesNotSuppressUntitledWindow() throws {
        try withPasteboard { pboard in
            pboard.clearContents()
            pboard.setString("post-launch", forType: .string)
            var serviceError: NSString?
            let delegate = try appDelegate()

            delegate.newJotNoteFromSelection(pboard, userData: nil, error: &serviceError)
            let created = NSDocumentController.shared.documents
                .compactMap { $0 as? Document }
                .first { $0.text == "post-launch" }
            defer { created?.close() }

            XCTAssertTrue(delegate.applicationShouldOpenUntitledFile(NSApp))
        }
    }

    func testServiceRejectsOversizedSelection() throws {
        try withPasteboard { pboard in
            pboard.clearContents()
            // One byte past the guard; ASCII so bytes == characters
            pboard.setString(String(repeating: "a", count: Document.maximumInputBytes + 1),
                             forType: .string)
            var serviceError: NSString?
            let countBefore = NSDocumentController.shared.documents.count

            try appDelegate().newJotNoteFromSelection(pboard, userData: nil, error: &serviceError)

            XCTAssertNotNil(serviceError)
            XCTAssertEqual(NSDocumentController.shared.documents.count, countBefore)
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

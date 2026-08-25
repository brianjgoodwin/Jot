//
//  SmartSubstitutionTests.swift
//  JotTests
//
//  Smart quotes and dashes must start off in every mode (#150) —
//  curly quotes corrupt code spans and link syntax, and Jot's text
//  often feeds terminals and compilers. Without the explicit
//  override the text view inherits the system-wide keyboard
//  preference, which is on for most people.
//

import XCTest
@testable import Jot

@MainActor
final class SmartSubstitutionTests: XCTestCase {

    private func makeEditor() throws -> (document: Document, editor: EditorViewController) {
        let document = Document()
        document.makeWindowControllers()
        let editor = try XCTUnwrap(
            document.windowControllers.first?.contentViewController as? EditorViewController
        )
        return (document, editor)
    }

    func testSmartQuotesAndDashesStartOff() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        XCTAssertFalse(editor.textView.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(editor.textView.isAutomaticDashSubstitutionEnabled)
    }

    // Guards against a future per-mode implementation quietly turning
    // the substitutions back on when a document leaves markdown mode.
    func testSmartSubstitutionsStayOffAcrossModeSwitches() throws {
        let (document, editor) = try makeEditor()
        defer { document.close() }

        editor.applyInitialMode(.markdown)
        editor.applyInitialMode(.plainText)

        XCTAssertFalse(editor.textView.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(editor.textView.isAutomaticDashSubstitutionEnabled)
    }
}

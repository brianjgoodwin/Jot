//
//  PreviewWindowControllerTests.swift
//  JotTests
//
//  Created on 8/19/26.
//
//  Exercises the preview window's update model (#38): one shell
//  navigation per presented document, body swaps for refreshes, the
//  pending-body queue that covers a refresh racing the shell load, and
//  the web-process teardown on close (#137). The window is created but
//  never shown -- WKWebView renders offscreen (proven in the #252
//  spike), and tests must never present real UI.
//

import XCTest
import WebKit
@testable import Jot

@MainActor
final class PreviewWindowControllerTests: XCTestCase {

	// Created per test (setUp/tearDown override nonisolated XCTestCase
	// methods and so cannot touch MainActor state under Swift 6);
	// windowWillClose in tearDownBlocks handles the teardown.
	private func makeController() -> PreviewWindowController {
		let controller = PreviewWindowController()
		addTeardownBlock { @MainActor in controller.close() }
		return controller
	}

	// MARK: - Helpers

	/// Polls the page until `script` evaluates to a string containing
	/// `needle`, pumping the run loop so WebKit's async work proceeds.
	@discardableResult
	private func waitForPage(_ controller: PreviewWindowController,
							 script: String = "document.body.innerText",
							 toContain needle: String,
							 timeout: TimeInterval = 5) -> Bool {
		let deadline = Date(timeIntervalSinceNow: timeout)
		while Date() < deadline {
			guard let webView = controller.webView else {
				RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
				continue
			}
			var latest: String?
			var done = false
			webView.evaluateJavaScript(script) { value, _ in
				latest = value as? String
				done = true
			}
			while !done && Date() < deadline {
				RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
			}
			if latest?.contains(needle) == true { return true }
			RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
		}
		return false
	}

	// MARK: - Presenting

	func testPreviewRendersMarkdownThroughTheShell() {
		let controller = makeController()
		controller.preview(title: "Agenda.md", markdown: "# Quarterly Review")
		XCTAssertTrue(waitForPage(controller, toContain: "Quarterly Review"))
		XCTAssertTrue(waitForPage(controller, script: "document.title", toContain: "Agenda.md"))
		XCTAssertEqual(controller.window?.title, "Agenda.md")
	}

	func testEmptyStateExplainsItself() {
		let controller = makeController()
		controller.showEmptyState()
		XCTAssertTrue(waitForPage(controller, toContain: "Nothing to preview"))
		XCTAssertEqual(controller.window?.title, "Markdown Preview")
	}

	// MARK: - Refresh (body swap)

	func testRefreshSwapsBodyWithoutANavigation() {
		let controller = makeController()
		controller.preview(title: "Doc", markdown: "first draft")
		XCTAssertTrue(waitForPage(controller, toContain: "first draft"))

		controller.refresh(markdown: "second draft")
		XCTAssertTrue(waitForPage(controller, toContain: "second draft"))
		XCTAssertEqual(controller.finishedNavigations, 1,
					   "a refresh must swap the body, never reload the page")
	}

	func testRefreshDuringShellLoadIsNotLost() {
		let controller = makeController()
		// No waiting between the calls: the refresh arrives while the
		// shell navigation is still in flight and must be queued, not
		// dropped -- and not stomped by the navigation finishing.
		controller.preview(title: "Doc", markdown: "stale content")
		controller.refresh(markdown: "fresh content")
		XCTAssertTrue(waitForPage(controller, toContain: "fresh content"))
		XCTAssertEqual(controller.finishedNavigations, 1)
	}

	func testRefreshBeforeAnyPresentIsANoOp() {
		let controller = makeController()
		controller.refresh(markdown: "never shown")
		XCTAssertNil(controller.webView)
	}

	// MARK: - Teardown on close (#137)

	func testCloseDestroysTheWebView() {
		let controller = makeController()
		controller.preview(title: "Doc", markdown: "content")
		XCTAssertTrue(waitForPage(controller, toContain: "content"))

		controller.close()
		XCTAssertNil(controller.webView, "a closed preview must not keep a web process alive")
	}

	func testReopeningAfterCloseRendersAgain() {
		let controller = makeController()
		controller.preview(title: "Doc", markdown: "before close")
		XCTAssertTrue(waitForPage(controller, toContain: "before close"))
		controller.close()

		controller.preview(title: "Doc", markdown: "after close")
		XCTAssertTrue(waitForPage(controller, toContain: "after close"))
	}
}

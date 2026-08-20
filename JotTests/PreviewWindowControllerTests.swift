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
import PDFKit
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

	// MARK: - Tracking (#38)

	/// Stands in for an editor window; tests must never present real UI,
	/// and EditorViewController only exists fully wired via storyboard.
	private final class StubSource: NSViewController, PreviewSource {
		var previewMode: EditorMode = .markdown
		var previewTitle = "Stub.md"
		var previewMarkdown = ""
		override func loadView() { view = NSView() }
	}

	private func makeEditorWindow(mode: EditorMode = .markdown,
								  title: String,
								  markdown: String) -> (NSWindow, StubSource) {
		let source = StubSource()
		source.previewMode = mode
		source.previewTitle = title
		source.previewMarkdown = markdown
		let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
							  styleMask: [.titled, .closable], backing: .buffered, defer: false)
		window.isReleasedWhenClosed = false
		window.contentViewController = source
		addTeardownBlock { @MainActor in window.close() }
		return (window, source)
	}

	/// A controller with tracking active, without showWindow (which
	/// would present real UI). Content visibility defaults to true.
	private func makeTrackingController(main: NSWindow?, ordered: [NSWindow] = []) -> PreviewWindowController {
		let controller = makeController()
		controller.isTracking = true
		controller.refreshDelay = 0.05
		controller.isContentVisible = { true }
		controller.mainWindowProvider = { [weak main] in main }
		controller.orderedWindowsProvider = { ordered }
		return controller
	}

	func testTracksTheFrontmostMarkdownEditor() {
		let (editorWindow, _) = makeEditorWindow(title: "Agenda.md", markdown: "# Agenda")
		let controller = makeTrackingController(main: editorWindow)

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "Agenda"))
		XCTAssertEqual(controller.window?.title, "Agenda.md")
		XCTAssertTrue(controller.trackedWindow === editorWindow)
	}

	func testPlainTextMainWindowDoesNotStealTheTarget() {
		let (markdownWindow, _) = makeEditorWindow(title: "Doc.md", markdown: "kept content")
		let (plainWindow, _) = makeEditorWindow(mode: .plainText, title: "notes.txt", markdown: "scratch")
		let controller = makeTrackingController(main: markdownWindow)

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "kept content"))

		// The all-day plain-text scratchpad comes to the front.
		controller.mainWindowProvider = { [weak plainWindow] in plainWindow }
		controller.reevaluateTarget()

		XCTAssertTrue(controller.trackedWindow === markdownWindow, "the preview must hold its target")
		XCTAssertEqual(controller.finishedNavigations, 1, "holding must not reload anything")
	}

	func testRetargetsWhenAnotherMarkdownEditorBecomesMain() {
		let (first, _) = makeEditorWindow(title: "First.md", markdown: "first content")
		let (second, _) = makeEditorWindow(title: "Second.md", markdown: "second content")
		let controller = makeTrackingController(main: first)

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "first content"))

		controller.mainWindowProvider = { [weak second] in second }
		controller.reevaluateTarget()

		XCTAssertTrue(waitForPage(controller, toContain: "second content"))
		XCTAssertEqual(controller.window?.title, "Second.md")
		XCTAssertEqual(controller.finishedNavigations, 2, "a retarget is an honest new page")
	}

	func testFallsToNextMarkdownEditorWhenTargetCloses() {
		let (closing, _) = makeEditorWindow(title: "Closing.md", markdown: "closing content")
		let (remaining, _) = makeEditorWindow(title: "Remaining.md", markdown: "remaining content")
		let controller = makeTrackingController(main: closing, ordered: [closing, remaining])

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "closing content"))

		closing.close()

		XCTAssertTrue(waitForPage(controller, toContain: "remaining content"))
		XCTAssertTrue(controller.trackedWindow === remaining)
	}

	func testShowsEmptyStateWhenLastMarkdownEditorCloses() {
		let (only, _) = makeEditorWindow(title: "Only.md", markdown: "only content")
		let controller = makeTrackingController(main: only, ordered: [only])

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "only content"))

		only.close()

		XCTAssertTrue(waitForPage(controller, toContain: "Nothing to preview"))
		XCTAssertNil(controller.trackedWindow)
	}

	func testTargetLeavingMarkdownModeRetargets() {
		let (toggling, togglingSource) = makeEditorWindow(title: "Toggling.md", markdown: "toggling content")
		let (other, _) = makeEditorWindow(title: "Other.md", markdown: "other content")
		let controller = makeTrackingController(main: toggling, ordered: [toggling, other])

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "toggling content"))

		togglingSource.previewMode = .plainText
		NotificationCenter.default.post(
			name: EditorViewController.modeDidChangeNotification, object: togglingSource)

		XCTAssertTrue(waitForPage(controller, toContain: "other content"))
	}

	func testTextChangesRefreshAfterTheDebounce() {
		let (editorWindow, source) = makeEditorWindow(title: "Doc.md", markdown: "before edit")
		let controller = makeTrackingController(main: editorWindow)

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "before edit"))

		source.previewMarkdown = "after edit"
		NotificationCenter.default.post(
			name: EditorViewController.textDidChangeNotification, object: source)

		XCTAssertTrue(waitForPage(controller, toContain: "after edit"))
		XCTAssertEqual(controller.finishedNavigations, 1, "typing must body-swap, not reload")
	}

	func testTextChangesInOtherEditorsAreIgnored() {
		let (tracked, _) = makeEditorWindow(title: "Tracked.md", markdown: "tracked content")
		let (other, otherSource) = makeEditorWindow(title: "Other.md", markdown: "other content")
		let controller = makeTrackingController(main: tracked, ordered: [tracked, other])

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "tracked content"))

		otherSource.previewMarkdown = "updated other"
		NotificationCenter.default.post(
			name: EditorViewController.textDidChangeNotification, object: otherSource)

		// The debounce would have fired well within this window.
		XCTAssertFalse(waitForPage(controller, toContain: "updated other", timeout: 0.5))
	}

	func testNoRenderWhileOccludedThenOneCatchUp() {
		let (editorWindow, source) = makeEditorWindow(title: "Doc.md", markdown: "visible content")
		let controller = makeTrackingController(main: editorWindow)

		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "visible content"))

		controller.isContentVisible = { false }
		source.previewMarkdown = "typed while hidden"
		NotificationCenter.default.post(
			name: EditorViewController.textDidChangeNotification, object: source)
		XCTAssertFalse(waitForPage(controller, toContain: "typed while hidden", timeout: 0.5),
					   "an occluded preview must not render")

		controller.isContentVisible = { true }
		controller.windowDidChangeOcclusionState(
			Notification(name: NSWindow.didChangeOcclusionStateNotification))
		XCTAssertTrue(waitForPage(controller, toContain: "typed while hidden"),
					  "becoming visible owes exactly one catch-up render")
	}

	// MARK: - Printing (#38)

	/// Print-operation completion callback holder. runModal's delegate
	/// callback is the only reliable end-of-print signal (#252): run()
	/// returns before WKWebView's async pipeline produces output.
	private final class PrintWaiter: NSObject, @unchecked Sendable {
		nonisolated(unsafe) var done = false
		@objc func printOperationDidRun(_ printOperation: NSPrintOperation, success: Bool,
										contextInfo: UnsafeMutableRawPointer?) {
			done = true
		}
	}

	/// Hooks the controller's print path to write a PDF instead of
	/// presenting the real dialog, and returns the PDF once the
	/// operation completes. Returns nil on timeout.
	private func printToPDF(_ controller: PreviewWindowController,
							timeout: TimeInterval = 10) -> PDFDocument? {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("jot-print-test-\(UUID().uuidString).pdf")
		addTeardownBlock { try? FileManager.default.removeItem(at: url) }

		let waiter = PrintWaiter()
		let hostWindow = controller.window!
		controller.printOperationHook = { operation in
			operation.showsPrintPanel = false
			operation.showsProgressPanel = false
			operation.printInfo.jobDisposition = .save
			operation.printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
			operation.runModal(for: hostWindow, delegate: waiter,
							   didRun: #selector(PrintWaiter.printOperationDidRun(_:success:contextInfo:)),
							   contextInfo: nil)
		}

		controller.printDocument(nil)

		let deadline = Date(timeIntervalSinceNow: timeout)
		while !waiter.done && Date() < deadline {
			RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
		}
		controller.tearDownPrintWebView()
		return waiter.done ? PDFDocument(url: url) : nil
	}

	func testPrintProducesPDFOfDisplayedContent() {
		let (editorWindow, _) = makeEditorWindow(
			title: "PrintMe.md",
			markdown: "# Printable Heading\n\nBody text that must reach paper.")
		let controller = makeTrackingController(main: editorWindow)
		controller.reevaluateTarget(force: true)
		XCTAssertTrue(waitForPage(controller, toContain: "Printable Heading"))

		guard let pdf = printToPDF(controller) else {
			return XCTFail("print operation never completed")
		}
		XCTAssertGreaterThanOrEqual(pdf.pageCount, 1)
		let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined()
		XCTAssertTrue(text.contains("Printable Heading"))
		XCTAssertTrue(text.contains("Body text that must reach paper"))
	}

	func testPrintRendersAtThePrintableWidth() {
		// The #252 finding: WKWebView paginates at its layout width, so
		// 1:1 output requires the print view to be sized to the paper
		// minus the margins -- not to the on-screen window.
		let controller = makeController()
		controller.preview(title: "Doc.md", markdown: "content")
		XCTAssertTrue(waitForPage(controller, toContain: "content"))

		var captured: NSPrintOperation?
		controller.printOperationHook = { captured = $0 }
		controller.printDocument(nil)

		let deadline = Date(timeIntervalSinceNow: 5)
		while captured == nil && Date() < deadline {
			RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
		}
		guard let operation = captured, let printView = controller.printWebView else {
			return XCTFail("print operation was never handed off")
		}
		let info = operation.printInfo
		XCTAssertEqual(printView.frame.width,
					   info.paperSize.width - info.leftMargin - info.rightMargin)
		XCTAssertNotEqual(printView, controller.webView,
						  "printing must not disturb the on-screen web view")
		// WKWebView vends its printing view with a zero frame, and the
		// print panel traps on the empty rect (crash found 2026-08-20;
		// the spike missed it because .save tolerates the empty frame).
		// The controller must have sized it before handing the
		// operation over.
		XCTAssertEqual(operation.view?.frame, printView.bounds,
					   "the printing view must be sized before the panel presents")
		controller.tearDownPrintWebView()
	}

	func testPrintWithNothingToShowIsRefused() {
		let controller = makeController()
		var hookRan = false
		controller.printOperationHook = { _ in hookRan = true }

		controller.printDocument(nil)

		XCTAssertNil(controller.printWebView)
		XCTAssertFalse(hookRan)
	}

	// MARK: - Zoom (#52)

	func testZoomChangesPageZoomAndActualSizeRestoresIt() {
		let controller = makeController()
		controller.preview(title: "Doc.md", markdown: "content")
		XCTAssertTrue(waitForPage(controller, toContain: "content"))
		guard let webView = controller.webView else { return XCTFail("no web view") }

		controller.increaseFontSize(nil)
		controller.increaseFontSize(nil)
		XCTAssertGreaterThan(webView.pageZoom, 1.0)

		controller.resetFontSize(nil)
		XCTAssertEqual(webView.pageZoom, 1.0)

		controller.decreaseFontSize(nil)
		XCTAssertLessThan(webView.pageZoom, 1.0)
	}

	func testZoomDoesNotTouchThePrintPath() {
		let controller = makeController()
		controller.preview(title: "Doc.md", markdown: "content")
		XCTAssertTrue(waitForPage(controller, toContain: "content"))
		controller.increaseFontSize(nil)
		controller.increaseFontSize(nil)

		var captured: NSPrintOperation?
		controller.printOperationHook = { captured = $0 }
		controller.printDocument(nil)
		let deadline = Date(timeIntervalSinceNow: 5)
		while captured == nil && Date() < deadline {
			RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
		}

		XCTAssertEqual(controller.printWebView?.pageZoom, 1.0,
					   "window zoom must never distort print output")
		controller.tearDownPrintWebView()
	}

	func testPrintMenuItemValidation() {
		let controller = makeController()
		let printItem = NSMenuItem(title: "Print…",
								   action: #selector(PreviewWindowController.printDocument(_:)),
								   keyEquivalent: "p")

		XCTAssertFalse(controller.validateMenuItem(printItem),
					   "nothing to print before a document is presented")

		controller.preview(title: "Doc.md", markdown: "content")
		XCTAssertTrue(waitForPage(controller, toContain: "content"))
		XCTAssertTrue(controller.validateMenuItem(printItem))

		controller.showEmptyState()
		XCTAssertTrue(waitForPage(controller, toContain: "Nothing to preview"))
		XCTAssertFalse(controller.validateMenuItem(printItem),
					   "the empty state has nothing to print")
	}
}

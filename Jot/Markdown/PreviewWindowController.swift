//
//  PreviewWindowController.swift
//  Jot
//
//  Created on 8/19/26.
//
//  The markdown preview window (#38): programmatic, and a singleton by
//  convention -- the app delegate holds one instance, the classic Mac
//  utility grammar where document windows multiply and the preview
//  does not (see docs/preview-rebuild-plan.md).
//
//  Update model: the HTML shell (CSP, lang, title, theme CSS) is
//  loaded as a full navigation only when a document is presented; body
//  swaps handle everything after that, so re-renders never flash and
//  never lose scroll position. The window survives closing, but its
//  WKWebView is torn down -- a leave-it-running app must not bleed a
//  web process from a window nobody is looking at (#137).
//
//  While on screen it feeds itself: it follows the frontmost
//  markdown-mode document (holding its target when plain-text windows
//  come forward), re-renders after a typing lull, and does nothing at
//  all while occluded. See "Tracking" below for the full rule.
//

import Cocoa
import WebKit
import os.signpost

@MainActor
final class PreviewWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate,
									 NSMenuItemValidation {

	/// Readable so tests can drive the page; created on demand and
	/// destroyed on window close (#137).
	private(set) var webView: WKWebView?

	/// Full navigations that have completed. The body-swap contract is
	/// that this stays at 1 per presented document no matter how many
	/// refreshes happen -- pinned in PreviewWindowControllerTests.
	private(set) var finishedNavigations = 0

	/// A refresh that arrives while the shell navigation is still in
	/// flight would race the load (the commit could stomp the swapped
	/// body), so it waits here and applies in didFinish. Latest wins.
	private var pendingBodyHTML: String?
	private var isShellReady = false

	// MARK: - Print state (#38)

	/// The body currently on screen, kept so printing reproduces exactly
	/// what the preview shows -- no re-render at print time, no drift.
	private var lastBodyHTML: String?
	private var lastTitle: String?

	/// The offscreen web view a print run renders in, sized to the
	/// printable width. Readable so tests can assert its geometry; nil
	/// whenever no print is in flight.
	private(set) var printWebView: WKWebView?
	private var printHostWindow: NSWindow?
	private var pendingPrintInfo: NSPrintInfo?

	/// Test seam: when set, runPrint hands the configured operation here
	/// instead of presenting the real modal print dialog.
	var printOperationHook: ((NSPrintOperation) -> Void)?

	// MARK: - Tracking state

	/// The editor window being previewed. Weak: closing evicts it via
	/// the willClose observer, but a window deallocating out from under
	/// us must not dangle.
	private(set) weak var trackedWindow: NSWindow?

	/// Tracking runs only while the preview is on screen; showWindow
	/// turns it on and resyncs, windowWillClose turns it off. Internal
	/// (not private) so tests can activate tracking without presenting
	/// a real window.
	var isTracking = false

	/// Set when a render was skipped because the window was occluded;
	/// the occlusion-state delegate callback pays it off.
	private var needsCatchUpRender = false

	/// The debounce interval for typing (a taste constant per the plan:
	/// 0.5 feels attentive, 1.5 document-like). A var so tests can
	/// shrink it instead of waiting out real time.
	var refreshDelay: TimeInterval = 0.75

	// Test seams: window state comes from closures so the tracking rule
	// is testable with never-shown windows. Defaults are the real app.
	var mainWindowProvider: () -> NSWindow? = { NSApp.mainWindow }
	var orderedWindowsProvider: () -> [NSWindow] = { NSApp.orderedWindows }
	/// nil means "ask the real occlusion state".
	var isContentVisible: (() -> Bool)?

	convenience init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.title = "Markdown Preview"
		window.isReleasedWhenClosed = false
		window.setFrameAutosaveName("MarkdownPreview")
		window.center()

		self.init(window: window)
		window.delegate = self
		startObserving()
	}

	// MARK: - Tracking (#38)

	// The rule, from docs/preview-rebuild-plan.md: follow the frontmost
	// markdown-mode document; hold the last target when a non-markdown
	// window becomes main (plain-text windows are invisible); when the
	// target closes or leaves markdown mode, fall to the frontmost
	// remaining markdown document, else show the empty state.

	private func startObserving() {
		let nc = NotificationCenter.default
		nc.addObserver(self, selector: #selector(handleWindowStateChanged(_:)),
					   name: NSWindow.didBecomeMainNotification, object: nil)
		nc.addObserver(self, selector: #selector(handleWindowWillClose(_:)),
					   name: NSWindow.willCloseNotification, object: nil)
		nc.addObserver(self, selector: #selector(handleTextDidChange(_:)),
					   name: EditorViewController.textDidChangeNotification, object: nil)
		nc.addObserver(self, selector: #selector(handleModeDidChange(_:)),
					   name: EditorViewController.modeDidChangeNotification, object: nil)
	}

	@objc private func handleWindowStateChanged(_ notification: Notification) {
		reevaluateTarget()
	}

	@objc private func handleModeDidChange(_ notification: Notification) {
		reevaluateTarget()
	}

	@objc private func handleWindowWillClose(_ notification: Notification) {
		guard let closing = notification.object as? NSWindow, closing !== window else { return }
		if closing === trackedWindow {
			reevaluateTarget(excluding: closing)
		}
	}

	@objc private func handleTextDidChange(_ notification: Notification) {
		guard isTracking,
			  let editor = notification.object as? NSViewController,
			  editor === trackedWindow?.contentViewController else { return }
		scheduleRefresh()
	}

	override func showWindow(_ sender: Any?) {
		super.showWindow(sender)
		isTracking = true
		reevaluateTarget(force: true)
	}

	/// Recomputes which window the preview should follow and retargets
	/// (full shell load) when it changed. `force` re-presents even an
	/// unchanged target -- the showWindow path, where the web view may
	/// have been torn down or the content gone stale while hidden.
	func reevaluateTarget(force: Bool = false, excluding closingWindow: NSWindow? = nil) {
		guard isTracking else { return }

		let desired = desiredTargetWindow(excluding: closingWindow)
		guard force || desired !== trackedWindow else { return }

		trackedWindow = desired
		if let source = desired.flatMap(previewSource(of:)) {
			preview(title: source.previewTitle, markdown: source.previewMarkdown)
		} else {
			showEmptyState()
		}
	}

	private func desiredTargetWindow(excluding closingWindow: NSWindow?) -> NSWindow? {
		if let main = mainWindowProvider(), main !== closingWindow, isMarkdownEditor(main) {
			return main
		}
		// Hold: a non-markdown window in front does not steal the target.
		if let current = trackedWindow, current !== closingWindow, isMarkdownEditor(current) {
			return current
		}
		return orderedWindowsProvider().first {
			$0 !== closingWindow && isMarkdownEditor($0)
		}
	}

	private func isMarkdownEditor(_ window: NSWindow) -> Bool {
		previewSource(of: window)?.previewMode == .markdown
	}

	private func previewSource(of window: NSWindow) -> PreviewSource? {
		window.contentViewController as? PreviewSource
	}

	// MARK: - Debounced refresh

	/// Trailing debounce, classic AppKit: each text change cancels the
	/// pending render and re-arms the delay, so the render fires once,
	/// after typing stops. Cheap enough to leave eager because the body
	/// swap makes re-renders visually free.
	private func scheduleRefresh() {
		NSObject.cancelPreviousPerformRequests(
			withTarget: self, selector: #selector(performDebouncedRefresh), object: nil)
		perform(#selector(performDebouncedRefresh), with: nil, afterDelay: refreshDelay)
	}

	@objc func performDebouncedRefresh() {
		guard isTracking, let source = trackedWindow.flatMap(previewSource(of:)) else { return }
		// An occluded preview renders nothing (#137's cousin: no work an
		// all-day background session can't see); one catch-up render
		// happens when the window becomes visible again.
		guard contentIsVisible() else {
			needsCatchUpRender = true
			return
		}
		needsCatchUpRender = false
		window?.title = source.previewTitle
		refresh(markdown: source.previewMarkdown)
	}

	private func contentIsVisible() -> Bool {
		if let isContentVisible { return isContentVisible() }
		return window?.occlusionState.contains(.visible) ?? false
	}

	func windowDidChangeOcclusionState(_ notification: Notification) {
		guard isTracking, needsCatchUpRender, contentIsVisible() else { return }
		performDebouncedRefresh()
	}

	override init(window: NSWindow?) {
		super.init(window: window)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	// MARK: - Presenting content

	/// Shows `markdown` as a fresh page: full shell load, window and
	/// page title set to `title`. This is the open/retarget path; for
	/// re-renders of the same document use refresh(markdown:).
	///
	/// The remote-images preference is baked into the shell's CSP, so a
	/// preference change applies on the next present, not mid-page.
	func preview(title: String, markdown: String) {
		let bodyHTML = renderBody(markdown)
		let html = PreviewShell.document(
			title: title,
			bodyHTML: bodyHTML,
			loadRemoteImages: PreferencesManager.shared.loadRemoteImages)

		lastBodyHTML = bodyHTML
		lastTitle = title
		window?.title = title
		isShellReady = false
		pendingBodyHTML = nil
		ensureWebView().loadHTMLString(html, baseURL: nil)
	}

	/// Re-renders the current document in place by swapping the body --
	/// no navigation, no flash, scroll position survives. A no-op until
	/// a document has been presented.
	func refresh(markdown: String) {
		guard webView != nil else { return }
		let bodyHTML = renderBody(markdown)
		lastBodyHTML = bodyHTML
		if isShellReady {
			swapBody(bodyHTML)
		} else {
			pendingBodyHTML = bodyHTML
		}
	}

	/// What the preview shows when there is nothing to preview: opened
	/// with no document in front, or the previewed document closed.
	func showEmptyState() {
		let html = PreviewShell.document(
			title: "Markdown Preview",
			bodyHTML: PreviewShell.emptyStateBody,
			loadRemoteImages: false)

		lastBodyHTML = nil
		lastTitle = nil
		window?.title = "Markdown Preview"
		isShellReady = false
		pendingBodyHTML = nil
		ensureWebView().loadHTMLString(html, baseURL: nil)
	}

	// MARK: - Printing (#38)

	// Print output is the heart of the feature (both user stories end at
	// the print dialog, whose PDF button is the export path). The run
	// prints in a dedicated offscreen web view sized to the printable
	// width, because WKWebView paginates at its LAYOUT width (#252): the
	// on-screen view at an arbitrary window width would print scaled by
	// .fit. Size-then-load-then-print is the exact sequence the spike
	// validated 1:1; resizing the live view mid-print was not proven and
	// races the web process's asynchronous relayout.

	/// Cmd+P / File > Print, via the responder chain: the storyboard's
	/// Print item targets First Responder, so this runs exactly when the
	/// preview is the key window -- editors keep their own plain-text
	/// print path (see the plan). Same selector NSDocument uses.
	@objc func printDocument(_ sender: Any?) {
		guard let bodyHTML = lastBodyHTML, printWebView == nil else { return }

		// A copy: mutating NSPrintInfo.shared from a parallel print path
		// was #125. The copy still carries the user's Page Setup choices
		// (paper size, orientation) and the system default margins --
		// deliberately no opinionated page setup.
		let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
		let printableSize = NSSize(
			width: printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin,
			height: printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin)

		let webView = WKWebView(frame: NSRect(origin: .zero, size: printableSize))
		webView.navigationDelegate = self

		// WKWebView only renders while attached to a window; this one is
		// never ordered on screen (the #252 harness pattern).
		let host = NSWindow(contentRect: webView.frame, styleMask: [.titled],
							backing: .buffered, defer: false)
		host.isReleasedWhenClosed = false
		host.contentView = webView

		printWebView = webView
		printHostWindow = host
		pendingPrintInfo = printInfo

		// Known limit, accepted for 2.0: with remote images enabled,
		// images still in flight at didFinish can miss the print.
		let html = PreviewShell.document(
			title: lastTitle ?? "Markdown Preview",
			bodyHTML: bodyHTML,
			loadRemoteImages: PreferencesManager.shared.loadRemoteImages)
		webView.loadHTMLString(html, baseURL: nil)
	}

	/// Runs once the offscreen web view finishes loading (see didFinish).
	private func startPrintOperation() {
		guard let printWebView, let printInfo = pendingPrintInfo else { return }
		// The view already matches the printable width, so .fit is an
		// identity safety net, not a scaling mechanism.
		printInfo.horizontalPagination = .fit
		printInfo.verticalPagination = .automatic

		let operation = printWebView.printOperation(with: printInfo)
		operation.jobTitle = lastTitle ?? "Markdown Preview"
		runPrint(operation)
	}

	private func runPrint(_ operation: NSPrintOperation) {
		if let printOperationHook {
			printOperationHook(operation)
			return
		}
		guard let window else {
			tearDownPrintWebView()
			return
		}
		// runModal(for:delegate:didRun:), never run(): WKWebView's print
		// pipeline is asynchronous and run() returns before any output
		// exists (#252).
		operation.runModal(for: window, delegate: self,
						   didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
						   contextInfo: nil)
	}

	@objc private func printOperationDidRun(_ printOperation: NSPrintOperation, success: Bool,
											contextInfo: UnsafeMutableRawPointer?) {
		tearDownPrintWebView()
	}

	func tearDownPrintWebView() {
		printWebView?.removeFromSuperview()
		printWebView = nil
		printHostWindow = nil
		pendingPrintInfo = nil
	}

	private func renderBody(_ markdown: String) -> String {
		let signpostID = OSSignpostID(log: PerformanceLog.log)
		os_signpost(.begin, log: PerformanceLog.log, name: "Preview Render", signpostID: signpostID,
					"%d chars", markdown.utf16.count)
		defer { os_signpost(.end, log: PerformanceLog.log, name: "Preview Render", signpostID: signpostID) }
		return MarkdownHTMLRenderer.render(markdown: markdown)
	}

	/// The swap runs despite the page's default-src 'none' CSP because
	/// WebKit treats app-injected JavaScript as user-agent script, while
	/// scripts inside the injected HTML stay blocked -- both proven
	/// empirically in the #252 spike. The HTML travels as a real
	/// argument, never string-built into the JS source, so no content
	/// can escape into script context.
	private func swapBody(_ bodyHTML: String) {
		webView?.callAsyncJavaScript(
			"document.body.innerHTML = html;",
			arguments: ["html": bodyHTML],
			in: nil,
			in: .defaultClient
		) { _ in }
	}

	// MARK: - Web view lifecycle (#137)

	private func ensureWebView() -> WKWebView {
		if let webView { return webView }

		let created = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
		created.navigationDelegate = self
		created.translatesAutoresizingMaskIntoConstraints = false
		created.setAccessibilityLabel("Markdown preview")

		if let contentView = window?.contentView {
			contentView.addSubview(created)
			NSLayoutConstraint.activate([
				created.topAnchor.constraint(equalTo: contentView.topAnchor),
				created.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
				created.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
				created.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			])
		}

		webView = created
		return created
	}

	func windowWillClose(_ notification: Notification) {
		// Closing the preview must end its web process; the window itself
		// is cheap and stays for reuse (frame autosave included).
		NSObject.cancelPreviousPerformRequests(
			withTarget: self, selector: #selector(performDebouncedRefresh), object: nil)
		isTracking = false
		trackedWindow = nil
		needsCatchUpRender = false
		tearDownPrintWebView()
		lastBodyHTML = nil
		lastTitle = nil
		webView?.removeFromSuperview()
		webView = nil
		isShellReady = false
		pendingBodyHTML = nil
		finishedNavigations = 0
	}

	// MARK: - Navigation policy

	// Deny-by-default: the preview only ever loads its own generated
	// HTML. Clicked links open in the default browser -- after
	// re-checking the scheme allowlist at this trust boundary, so the
	// NSWorkspace hand-off stays safe even if the renderer's own
	// filtering ever drifts. Relative links (no scheme) no-op here.
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
				 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
		switch navigationAction.navigationType {
		case .other, .reload, .backForward:
			// .other covers loadHTMLString; reload/backForward can only
			// reach self-generated documents.
			decisionHandler(.allow)
		case .linkActivated:
			if let url = navigationAction.request.url,
			   let scheme = url.scheme?.lowercased(),
			   MarkdownHTMLRenderer.allowedLinkSchemes.contains(scheme) {
				NSWorkspace.shared.open(url)
			}
			decisionHandler(.cancel)
		default:
			decisionHandler(.cancel)
		}
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		if webView === printWebView {
			startPrintOperation()
			return
		}
		finishedNavigations += 1
		isShellReady = true
		if let bodyHTML = pendingBodyHTML {
			pendingBodyHTML = nil
			swapBody(bodyHTML)
		}
	}

	// MARK: - Menu validation

	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(printDocument(_:)) {
			// Nothing to print in the empty state; one print at a time.
			return lastBodyHTML != nil && printWebView == nil
		}
		return true
	}
}

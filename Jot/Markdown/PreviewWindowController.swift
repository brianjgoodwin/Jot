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

import Cocoa
import WebKit
import os.signpost

@MainActor
final class PreviewWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate {

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
		let html = PreviewShell.document(
			title: title,
			bodyHTML: renderBody(markdown),
			loadRemoteImages: PreferencesManager.shared.loadRemoteImages)

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

		window?.title = "Markdown Preview"
		isShellReady = false
		pendingBodyHTML = nil
		ensureWebView().loadHTMLString(html, baseURL: nil)
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
		finishedNavigations += 1
		isShellReady = true
		if let bodyHTML = pendingBodyHTML {
			pendingBodyHTML = nil
			swapBody(bodyHTML)
		}
	}
}

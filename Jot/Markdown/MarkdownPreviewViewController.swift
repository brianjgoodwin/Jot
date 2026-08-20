//
//  MarkdownPreviewViewController.swift
//  Jot
//
//  Created by Brian on 1/19/24.
//

import Cocoa
import WebKit
import os.signpost

class MarkdownPreviewViewController: NSViewController, WKNavigationDelegate {

	@IBOutlet weak var webView: WKWebView!

	override func viewDidLoad() {
		super.viewDidLoad()
		webView.navigationDelegate = self
		webView.setAccessibilityLabel("Markdown preview")
	}

	// Deny-by-default navigation policy: the preview only ever loads its
	// own generated HTML. Clicked links open in the default browser --
	// after re-checking the scheme allowlist at this trust boundary, so
	// the NSWorkspace hand-off stays safe even if the renderer's own
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

	func renderMarkdown(markdown: String) {
		let signpostID = OSSignpostID(log: PerformanceLog.log)
		os_signpost(.begin, log: PerformanceLog.log, name: "Preview Render", signpostID: signpostID,
					"%d chars", markdown.utf16.count)
		defer { os_signpost(.end, log: PerformanceLog.log, name: "Preview Render", signpostID: signpostID) }
		let bodyHTML = MarkdownHTMLRenderer.render(markdown: markdown)

		// PreviewShell owns the document wrapper: CSP, lang, title, and
		// theme CSS live there. The #38 rebuild replaces this controller
		// (and this per-render loadHTMLString) with the singleton window
		// and body-swap updates; until then it passes a generic title
		// because this storyboard path never learns the document's name.
		let safeHTML = PreviewShell.document(
			title: "Markdown Preview",
			bodyHTML: bodyHTML,
			loadRemoteImages: PreferencesManager.shared.loadRemoteImages)

		webView.loadHTMLString(safeHTML, baseURL: nil)
	}
}


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

		// Wrap in a full HTML document with a Content Security Policy that
		// blocks inline scripts, eval, and all external resource loading.
		// This prevents XSS even if the markdown contains <script> tags or
		// event handler attributes (onclick, onerror, etc.).
		//
		// When remote image loading is disabled, img-src is restricted to
		// data: URIs (which never touch the network), blocking tracking
		// pixels and remote images. file: is not listed because an
		// about:blank origin cannot load file: subresources anyway --
		// local images need the #38 rebuild to adopt loadFileURL.
		let imgSrc = PreferencesManager.shared.loadRemoteImages ? "img-src https: data:" : "img-src data:"
		let safeHTML = """
		<!DOCTYPE html>
		<html>
		<head>
		<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; \(imgSrc);">
		<meta charset="utf-8">
		<style>
		/* Browsers draw no table borders by default, so an unstyled table is
		   an invisible grid. Minimal styling only -- real preview theming is
		   #38/#40 territory. */
		table { border-collapse: collapse; }
		/* Solid mid-gray clears the 3:1 non-text contrast guideline on
		   both white and a future dark background (#52). */
		th, td { border: 1px solid #808080; padding: 3px 8px; }
		</style>
		</head>
		<body>
		\(bodyHTML)
		</body>
		</html>
		"""

		webView.loadHTMLString(safeHTML, baseURL: nil)
	}
}


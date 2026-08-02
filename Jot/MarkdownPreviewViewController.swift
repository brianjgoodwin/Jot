//
//  MarkdownPreviewViewController.swift
//  Jot
//
//  Created by Brian on 1/19/24.
//

import Cocoa
import Down
import WebKit

class MarkdownPreviewViewController: NSViewController, WKNavigationDelegate {

	@IBOutlet weak var webView: WKWebView!

	override func viewDidLoad() {
		super.viewDidLoad()
		webView.navigationDelegate = self
		webView.setAccessibilityLabel("Markdown preview")
	}

	// Block all link navigation to prevent crafted markdown from navigating
	// the preview to a remote URL. Clicked links open in the default browser.
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
				 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		// Allow programmatic loads (loadHTMLString) -- these use .other
		guard navigationAction.navigationType == .linkActivated else {
			decisionHandler(.allow)
			return
		}
		// Open clicked links in the default browser instead
		if let url = navigationAction.request.url {
			NSWorkspace.shared.open(url)
		}
		decisionHandler(.cancel)
	}

	func renderMarkdown(markdown: String) {
		let down = Down(markdownString: markdown)
		let bodyHTML = (try? down.toHTML()) ?? ""

		// Wrap in a full HTML document with a Content Security Policy that
		// blocks inline scripts, eval, and all external resource loading.
		// This prevents XSS even if the markdown contains <script> tags or
		// event handler attributes (onclick, onerror, etc.).
		let safeHTML = """
		<!DOCTYPE html>
		<html>
		<head>
		<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src * data:;">
		<meta charset="utf-8">
		</head>
		<body>
		\(bodyHTML)
		</body>
		</html>
		"""

		webView.loadHTMLString(safeHTML, baseURL: nil)
	}
}


//
//  MarkdownPreviewViewController.swift
//  Jot
//
//  Created by Brian on 1/19/24.
//

import Cocoa
import Down
import WebKit

class MarkdownPreviewViewController: NSViewController {

	@IBOutlet weak var webView: WKWebView!

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
		<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline';">
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


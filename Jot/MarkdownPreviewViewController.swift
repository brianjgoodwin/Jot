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
		let htmlString = try? down.toHTML()
		webView.loadHTMLString(htmlString ?? "", baseURL: nil)
	}
}


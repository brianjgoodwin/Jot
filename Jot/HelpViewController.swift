//
//  HelpViewController.swift
//  Jot
//
//  Created by Brian on 1/10/24.
//

import Cocoa
import WebKit

class HelpViewController: NSViewController, WKNavigationDelegate {
	@IBOutlet var webView: WKWebView!

	override func viewDidLoad() {
		super.viewDidLoad()
		webView.navigationDelegate = self
		loadHelpFile(named: "index")
	}

	func loadHelpFile(named fileName: String) {
		guard let filePath = Bundle.main.path(forResource: fileName, ofType: "html") else { return }

		let fileURL = URL(fileURLWithPath: filePath)
		webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard let url = navigationAction.request.url else {
			decisionHandler(.allow)
			return
		}

		// Allow file:// navigation for local help pages
		if url.scheme == "file" {
			decisionHandler(.allow)
			return
		}

		// Open all non-file links (http, https, mailto, etc.) in the default app
		if navigationAction.navigationType == .linkActivated {
			NSWorkspace.shared.open(url)
		}
		decisionHandler(.cancel)
	}
}

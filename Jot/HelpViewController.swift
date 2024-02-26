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
		guard let filePath = Bundle.main.path(forResource: fileName, ofType: "html") else {
			print("Help file not found.")
			return
		}

		let fileURL = URL(fileURLWithPath: filePath)
		webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
			if url.absoluteString.contains("github.com/brianjgoodwin/Jot/") {
				// Open the GitHub link in the default web browser
				NSWorkspace.shared.open(url)
				decisionHandler(.cancel)
			} else if url.scheme == "mailto" {
				// Open mailto links in the default email client
				NSWorkspace.shared.open(url)
				decisionHandler(.cancel)
			} else {
				// Allow other links to be opened within the WebView
				decisionHandler(.allow)
			}
		} else {
			// Allow other types of navigation
			decisionHandler(.allow)
		}
	}
}

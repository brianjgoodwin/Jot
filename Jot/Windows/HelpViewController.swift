//
//  HelpViewController.swift
//  Jot
//
//  Created by Brian on 1/10/24.
//

import Cocoa
import WebKit

class HelpViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
	@IBOutlet var webView: WKWebView!

	override func viewDidLoad() {
		super.viewDidLoad()
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.setAccessibilityLabel("Help content")
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

		// Open all non-file URLs (http, https, mailto, etc.) in the default app
		NSWorkspace.shared.open(url)
		decisionHandler(.cancel)
	}

	// Handle links that WKWebView treats as new-window navigations
	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		if let url = navigationAction.request.url, url.scheme != "file" {
			NSWorkspace.shared.open(url)
		} else {
			// Local file link that tried to open in a new window -- load it in this web view
			if let request = navigationAction.request.url {
				webView.load(URLRequest(url: request))
			}
		}
		return nil
	}
}

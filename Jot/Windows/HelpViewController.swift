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
		guard let filePath = Bundle.main.path(forResource: fileName, ofType: "html") else {
			// A build-phase mistake (target membership, a rename) would
			// otherwise ship as a silently blank window (#116)
			assertionFailure("Help resource \(fileName).html is missing from the bundle")
			webView.loadHTMLString("""
				<!DOCTYPE html>
				<html lang="en">
				<head>
				<meta charset="utf-8">
				<meta name="color-scheme" content="light dark">
				<title>Jot Help</title>
				</head>
				<body style="font-family: -apple-system, system-ui; margin: 2em;">
				<h1>Help unavailable</h1>
				<p>The help content could not be loaded. Please
				<a href="https://github.com/brianjgoodwin/Jot/wiki/Feedback-and-Support">contact support</a>
				to report this.</p>
				</body>
				</html>
				""", baseURL: nil)
			return
		}

		let fileURL = URL(fileURLWithPath: filePath)
		webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
	}

	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		if let url = navigationAction.request.url {
			let scheme = url.scheme?.lowercased() ?? ""
			if scheme == "http" || scheme == "https" || scheme == "mailto" {
				NSWorkspace.shared.open(url)
			}
		}
		return nil
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

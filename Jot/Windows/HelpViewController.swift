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
		// Match the window chrome so dark mode doesn't flash white
		// before the page's CSS paints (#117)
		webView.underPageBackgroundColor = .windowBackgroundColor
		loadHelpFile()
	}

	func loadHelpFile() {
		guard let fileURL = Bundle.main.url(forResource: "Help", withExtension: "html", subdirectory: "Help") else {
			// A build-phase mistake (target membership, a rename) would
			// otherwise ship as a silently blank window (#116)
			assertionFailure("Help/Help.html is missing from the bundle")
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

		// Scope read access to the Help folder only, not all of Resources
		webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
	}

	@IBAction func increaseFontSize(_ sender: Any?) {
		webView.pageZoom *= 1.1
	}

	@IBAction func decreaseFontSize(_ sender: Any?) {
		webView.pageZoom /= 1.1
	}

	@IBAction func resetFontSize(_ sender: Any?) {
		webView.pageZoom = 1.0
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard let url = navigationAction.request.url else {
			decisionHandler(.cancel)
			return
		}

		if url.scheme == "file" {
			decisionHandler(.allow)
			return
		}

		if navigationAction.navigationType == .linkActivated {
			let scheme = url.scheme?.lowercased() ?? ""
			if scheme == "http" || scheme == "https" || scheme == "mailto" {
				NSWorkspace.shared.open(url)
			}
		}
		decisionHandler(.cancel)
	}
}

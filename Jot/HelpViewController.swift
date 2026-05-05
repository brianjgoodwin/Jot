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
			logToFile("❌ Help file not found: \(fileName).html")
			return
		}

		let fileURL = URL(fileURLWithPath: filePath)
		webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard let url = navigationAction.request.url else {
			decisionHandler(.allow)
			return
		}

		if url.isFileURL {
			// Allow local file navigation (the bundled help pages)
			decisionHandler(.allow)
		} else {
			// Send everything else — http, https, mailto, etc. — to the system browser
			NSWorkspace.shared.open(url)
			decisionHandler(.cancel)
		}
	}
}

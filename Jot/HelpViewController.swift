//
//  HelpViewController.swift
//  Jot
//
//  Created by Brian on 1/10/24.
//

import Cocoa
import WebKit

class HelpViewController: NSViewController {
	@IBOutlet var webView: WKWebView!

	override func viewDidLoad() {
		super.viewDidLoad()
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

}

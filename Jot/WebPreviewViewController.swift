//
//  WebPreviewViewController.swift
//  Jot
//
//  Created by Brian on 3/1/24.
//

import Cocoa
import WebKit

protocol WebPreviewDelegate: AnyObject {
	func getCurrentTextEditorContent() -> String
}

class WebPreviewViewController: NSViewController {
	@IBOutlet var webView: WKWebView!
	weak var delegate: WebPreviewDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do view setup here.
	}

	func loadHTMLContent(_ html: String) {
		webView.loadHTMLString(html, baseURL: nil)
		webView.reload()
	}

	func reloadPreview() {
		if let textEditorContent = delegate?.getCurrentTextEditorContent() {
			loadHTMLContent(textEditorContent)
		}
	}
}

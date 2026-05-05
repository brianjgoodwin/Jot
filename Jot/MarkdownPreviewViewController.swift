//
//  MarkdownPreviewViewController.swift
//  Jot
//
//  Created by Brian on 1/19/24.
//

import Cocoa
import WebKit
import Down

class MarkdownPreviewViewController: NSViewController {

	// Kept to satisfy the storyboard IBOutlet connection — replaced in the view hierarchy by downView.
	@IBOutlet weak var webView: WKWebView!

	private var downView: DownView?

	override func viewDidLoad() {
		super.viewDidLoad()
		setupDownView(markdown: "")
	}

	func renderMarkdown(markdown: String) {
		if let dv = downView {
			do {
				try dv.update(markdownString: markdown)
			} catch {
				logToFile("❌ DownView update failed: \(error)")
			}
		} else {
			setupDownView(markdown: markdown)
		}
	}

	private func setupDownView(markdown: String) {
		do {
			let dv = try DownView(
				frame: view.bounds,
				markdownString: markdown,
				openLinksInBrowser: true,
				options: .safe
			)
			dv.translatesAutoresizingMaskIntoConstraints = false
			webView?.removeFromSuperview()
			view.addSubview(dv)
			NSLayoutConstraint.activate([
				dv.topAnchor.constraint(equalTo: view.topAnchor),
				dv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
				dv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
				dv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			])
			downView = dv
		} catch {
			logToFile("❌ DownView init failed: \(error)")
		}
	}
}

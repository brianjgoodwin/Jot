//
//  MarkdownPreviewWindowController.swift
//  Jot
//
//  Created by Brian on 1/19/24.
//

import Cocoa
import WebKit
import Down

class MarkdownPreviewWindowController: NSWindowController {
	var markdownContent: String = ""

	override func windowDidLoad() {
		super.windowDidLoad()
		if let markdownVC = contentViewController as? MarkdownPreviewViewController {
			markdownVC.renderMarkdown(markdown: markdownContent)
		}
	}

	func loadMarkdown(markdown: String) {
		self.markdownContent = markdown
		// If the window is already loaded, update the content
		if isWindowLoaded, let markdownVC = contentViewController as? MarkdownPreviewViewController {
			markdownVC.renderMarkdown(markdown: markdownContent)
		}
	}
}



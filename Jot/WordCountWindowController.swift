//
//  WordCountWindowController.swift
//  Jot
//
//  Created by Brian on 1/8/24.
//

import Cocoa

class WordCountWindowController: NSWindowController {

	override func windowDidLoad() {
		super.windowDidLoad()
		// Any additional setup after the window has been loaded.
	}

	// Update the statistics in the WordCountViewController with the given text
	func updateStatistics(withText text: String) {
		if let wordCountVC = contentViewController as? WordCountViewController {
			wordCountVC.updateStatistics(withText: text)
		}
	}
}

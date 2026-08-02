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
	}

	func updateStatistics(withText text: String) {
		if let wordCountVC = contentViewController as? WordCountViewController {
			wordCountVC.updateStatistics(withText: text)
		}
	}
}

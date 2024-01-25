//
//  WordCountWindowController.swift
//  Jot
//
//  Created by Brian on 1/8/24.
//

import Cocoa

class WordCountWindowController: NSWindowController {
	var textContent: String = ""

	
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
	
	func loadText(_ text: String) {
		self.textContent = text
		if let wordCountVC = contentViewController as? WordCountViewController {
			wordCountVC.textContent = text
			wordCountVC.updateStatisticsDisplay()
		}
	}

}

//
//  ViewController.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class ViewController: NSViewController {
	
	@IBOutlet var textView: NSTextView!
	@IBOutlet var wordCountLabel: NSTextField! // Add this outlet for the word count label
	
	var selectedFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
	
	func updateViewFont() {
		// Apply the selected font and font size to your text view or other relevant UI elements
		textView.font = selectedFont
	}
	
	@IBOutlet var wordCountToggle: NSSwitch!
	
	@IBAction func toggleWordCountDisplay(_ sender: NSButton) {
		if sender.state == .on {
			// Show word count
			updateWordCount()
		} else {
			// Hide word count
			wordCountLabel.stringValue = "Word Count: Off"
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		textView.delegate = self
		// Set the initial state based on your app's default behavior
		wordCountToggle.state = .on
		updateWordCount()
	}

	
	@IBAction func saveDocument(_ sender: Any) {
		// Get a reference to the associated document
		if let document = self.view.window?.windowController?.document as? Document {
			document.text = textView.string // Update the text property with the content from the text view
			document.updateChangeCount(.changeDone) // Mark the document as dirty
			document.save(self) // Save the document
		}
	}
	
	
	func updateWordCount() {
		let text = textView.string
		let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
		let wordCount = words.count
		wordCountLabel.stringValue = "Word Count: \(wordCount)"
	}
	
	func calculateInitialWordCount() {
		if wordCountToggle.state == .on {
			updateWordCount()
		} else {
			wordCountLabel.stringValue = "Word Count: Off"
		}
	}
	
	
	// Add more actions and functionality as needed
}

extension ViewController: NSTextViewDelegate {
	func textDidChange(_ notification: Notification) {
		if wordCountToggle.state == .on {
			updateWordCount()
		}
	}
}


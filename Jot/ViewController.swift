//
//  ViewController.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class ViewController: NSViewController {
	// MARK: - Outlets
	@IBOutlet var textView: NSTextView!
	@IBOutlet var wordCountLabel: NSTextField!
	@IBOutlet var wordCountToggle: NSSwitch!
	
	// MARK: - Properties
	var selectedFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
	
	// MARK: - Font Size Properties
	var currentFontSize: CGFloat = NSFont.systemFontSize // Keep track of the current font size
	
	// MARK: - View Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupTextView()
		setupWordCountToggle()
		
		// Set the initial font size
		textView.font = NSFont.systemFont(ofSize: currentFontSize)
	}
	
	// MARK: - Actions for Text Size Adjustment
	//TODO: Fix this - not working as desired
	func increaseTextSize() {
		currentFontSize += 1.0
		textView.font = NSFont.systemFont(ofSize: currentFontSize)
	}
	
	func decreaseTextSize() {
		currentFontSize -= 1.0
		textView.font = NSFont.systemFont(ofSize: currentFontSize)
	}
	
	// MARK: - Keyboard Shortcuts Handling
	override func keyDown(with event: NSEvent) {
		if event.modifierFlags.contains(.command) {
			switch event.charactersIgnoringModifiers {
			case "+", "=":
				increaseTextSize() // Increase text size
			case "-":
				decreaseTextSize() // Decrease text size
			default:
				break
			}
		} else {
			super.keyDown(with: event) // Pass unhandled key events to the super class
		}
	}
	
	// MARK: - PRINT
	@IBAction func printDocument(_ sender: Any?) {
		let printInfo = NSPrintInfo.shared
		let printOperation = NSPrintOperation(view: textView) // Replace "textView" with your content view
		printOperation.printInfo = printInfo
		printOperation.showsPrintPanel = true
		printOperation.run()
	}

	
	
	// MARK: - Actions
	@IBAction func toggleWordCountDisplay(_ sender: NSButton) {
		if sender.state == .on {
			// Show word count
			updateWordCount()
		} else {
			// Hide word count
			wordCountLabel.stringValue = "Word Count: Off"
		}
	}
	
	@IBAction func saveDocument(_ sender: Any) {
		// Get a reference to the associated document
		if let document = self.view.window?.windowController?.document as? Document {
			document.text = textView.string // Update the text property with the content from the text view
			document.updateChangeCount(.changeDone) // Mark the document as dirty
			document.save(self) // Save the document
		}
	}
	
	// MARK: - Word Count
	func updateWordCount() {
		let text = textView.string
		let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
		let wordCount = words.count
		
		if wordCountToggle.state == .on {
			let formattedWordCount = numberFormatter.string(from: NSNumber(value: wordCount)) ?? ""
			wordCountLabel.stringValue = "Word Count: \(formattedWordCount)"
		} else {
			wordCountLabel.stringValue = "Word Count: Off"
		}
	}
	
	func calculateInitialWordCount() {
		if wordCountToggle.state == .on {
			updateWordCount()
		} else {
			wordCountLabel.stringValue = "Word Count: Off"
		}
	}
	
	// MARK: - Number Formatter
	let numberFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.locale = Locale(identifier: "en_US") // Set the locale to US
		return formatter
	}()
	
	// MARK: - Text View Setup
	private func setupTextView() {
		textView.delegate = self
		updateWordCount()
	}
	
	// MARK: - Word Count Toggle Setup
	private func setupWordCountToggle() {
		// Set the initial state based on your app's default behavior
		wordCountToggle.state = .on
	}
}

// MARK: - NSTextViewDelegate
extension ViewController: NSTextViewDelegate {
	func textDidChange(_ notification: Notification) {
		if wordCountToggle.state == .on {
			updateWordCount()
		}
	}
}

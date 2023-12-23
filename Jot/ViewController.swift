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
	
	@IBOutlet var increaseFontSizeButton: NSButton!
	@IBOutlet var decreaseFontSizeButton: NSButton!

	@IBAction func increaseFontSize(_ sender: Any) {
		// Get the current font from the text view's text storage
		if let currentFont = textView.textStorage?.font {
			// Calculate the new font size (e.g., increase by 2 points)
			let newFontSize = currentFont.pointSize + 2.0
			
			// Create a new font with the adjusted size
			let newFont = NSFont(descriptor: currentFont.fontDescriptor, size: newFontSize)
			
			// Apply the new font to the text view's text storage
			textView.textStorage?.addAttribute(.font, value: newFont, range: NSMakeRange(0, (textView.textStorage?.length ?? 0)))
		}
	}

	@IBAction func decreaseFontSize(_ sender: Any) {
		// Get the current font from the text view's text storage
			if let currentFont = textView.textStorage?.font {
				// Calculate the new font size (e.g., increase by 2 points)
				let newFontSize = currentFont.pointSize - 2.0
				
				// Create a new font with the adjusted size
				let newFont = NSFont(descriptor: currentFont.fontDescriptor, size: newFontSize)
				
				// Apply the new font to the text view's text storage
				textView.textStorage?.addAttribute(.font, value: newFont, range: NSMakeRange(0, (textView.textStorage?.length ?? 0)))
			}
		}


	// Add a property to keep track of the word count update timer
 private var wordCountUpdateTimer: Timer?

 // MARK: - View Lifecycle
 override func viewDidLoad() {
	 super.viewDidLoad()
	 setupTextView()
	 setupWordCountToggle()
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
	 // Invalidate the previous timer
	 wordCountUpdateTimer?.invalidate()

	 // Schedule a new timer to update word count after a delay (e.g., 1 second)
	 wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
		 self?.updateWordCount()
	 }
 }
}

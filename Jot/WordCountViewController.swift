//
//  WordCountViewController.swift
//  Jot
//
//  Created by Brian on 1/8/24.
//

import Cocoa

class WordCountViewController: NSViewController {
	// Text content from the main editor window
	var textContent: String = ""
	
	// Outlets for displaying word count, paragraph count, and file size
	@IBOutlet var WordCountDisplay: NSTextField!
	@IBOutlet var ParagraphCountDisplay: NSTextField!
	@IBOutlet var FileSizeDisplay: NSTextField!
	
	// Called when the view is about to appear
	override func viewWillAppear() {
		super.viewWillAppear()
		updateWordCountDisplay()
		updateParagraphCountDisplay()
		updateSizeDisplay()
	}
	
	// Calculates and returns the number of words in the text
	func calculateWordCount() -> Int {
		let words = textContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
		return words.count
	}
	
	// Calculates and returns the number of paragraphs in the text
	func calculateParagraphCount() -> Int {
		let paragraphs = textContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
		return paragraphs.count
	}
	
	// Calculates and returns the file size of the text as a formatted string
	func calculateDocumentSize() -> String {
		if let text = textContent.data(using: .utf8) {
			let fileSize = text.count  // Size in bytes
			return formatFileSize(fileSize)
		} else {
			return "0 Bytes"
		}
	}
	
	// Updates the word count display
	func updateWordCountDisplay() {
		let wordCount = calculateWordCount()
		WordCountDisplay.stringValue = "\(wordCount)"
	}
	
	// Updates the paragraph count display
	func updateParagraphCountDisplay() {
		let paragraphCount = calculateParagraphCount()
		ParagraphCountDisplay.stringValue = "\(paragraphCount)"
	}
	
	// Formats a file size from bytes to a readable format
	func formatFileSize(_ sizeInBytes: Int) -> String {
		let formatter = ByteCountFormatter()
		formatter.allowedUnits = [.useBytes, .useKB, .useMB]  // Adjust as needed
		formatter.countStyle = .file
		return formatter.string(fromByteCount: Int64(sizeInBytes))
	}
	
	// Updates the file size display
	func updateSizeDisplay() {
		let fileSizeString = calculateDocumentSize()
		FileSizeDisplay.stringValue = "\(fileSizeString)"
	}
}

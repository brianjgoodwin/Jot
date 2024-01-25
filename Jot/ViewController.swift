//
//  ViewController.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa
import Down

class ViewController: NSViewController, NSTextViewDelegate, TextSettingsDelegate {
	
	@IBOutlet var textView: NSTextView!
	@IBOutlet var wordCountLabel: NSTextField!
	@IBOutlet var wordCountToggle: NSSwitch!
//	@IBOutlet var documentStatusLabel: NSTextField!// documentStatusLabel | work in progress
		
	private var wordCountUpdateTimer: Timer?
	
//	var document: Document?// documentStatusLabel | work in progress

	var selectedFont: NSFont?
	var selectedFontSize: CGFloat?
	
	var isUpdatingText = false
	
	let numberFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.locale = Locale(identifier: "en_US") // Set the locale to US
		return formatter
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupTextView()
		setupWordCountToggle()
		loadFontPreferences()
		calculateInitialWordCount() // Calculate the initial word count after setup is complete
//		checkAndUpdateLastModified()
//		updateStatusLabelWith(date: Date())
	}
	
	override func viewWillAppear() {// documentStatusLabel | work in progress
		super.viewWillAppear()
//		checkAndUpdateLastModified()// documentStatusLabel | work in progress
//		updateStatusLabelWith(date: Date())
	}
	
	override var representedObject: Any? {
		didSet {
			// Update the view, if already loaded.
		}
	}
	
	// MARK: - Text Settings Delegate
	func didSelectFont(_ font: NSFont) {
		print("Setting font to: \(font.fontName)")
		selectedFont = font
		updateFont(to: font, size: nil)  // Size is nil, so it retains the current size
		
		// Save the font name to UserDefaults
		UserDefaults.standard.set(font.fontName, forKey: "selectedFontName")
	}
	
	func didSelectFontSize(_ fontSize: CGFloat) {
		selectedFontSize = fontSize
		updateFont(to: nil, size: fontSize)  // Font is nil, so it retains the current font
		
		// Save the font size to UserDefaults
		UserDefaults.standard.set(fontSize, forKey: "selectedFontSize")
	}
	
	// Centralized font management
	func updateFont(to newFont: NSFont?, size newSize: CGFloat?) {
		let fontToSet = newFont ?? selectedFont ?? textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		let sizeToSet = newSize ?? selectedFontSize ?? fontToSet.pointSize
		textView.font = NSFont(descriptor: fontToSet.fontDescriptor, size: sizeToSet)
	}
	
	func loadFontPreferences() {
		// Load the font name from UserDefaults
		if let fontName = UserDefaults.standard.string(forKey: "selectedFontName"),
		   let fontSizeValue = UserDefaults.standard.object(forKey: "selectedFontSize") as? Float { // Check if the key exists
			let fontSize = CGFloat(fontSizeValue)
			selectedFontSize = fontSize
			if let font = NSFont(name: fontName, size: fontSize) {
				selectedFont = font
			}
		} else {
			// Apply default values if not found in UserDefaults
			selectedFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
			selectedFontSize = 12  // or whatever default size you prefer
		}
		
		// Apply the loaded preferences
		updateFont(to: selectedFont, size: selectedFontSize)
	}
	
	func currentFontSize() -> CGFloat {
		return selectedFontSize ?? NSFont.systemFontSize
	}
	
	// MARK: - Document size
	func updateDocumentSize() {
		if let text = textView.string.data(using: .utf8) {
			let fileSize = text.count  // Size in bytes
			let formattedSize = formatFileSize(fileSize)
			// Update the UI or store this value as needed
			print("File Size: \(formattedSize)")
		}
	}

	func formatFileSize(_ sizeInBytes: Int) -> String {
		let formatter = ByteCountFormatter()
		formatter.allowedUnits = [. useBytes, .useKB, .useMB]  // Adjust as needed
		formatter.countStyle = .file
		return formatter.string(fromByteCount: Int64(sizeInBytes))
	}

	// MARK: Document Save Label
	
//	Note to self:
//	Attempting to add document save status.
//	This is for loading saved documents.
//	It currently does not work for a new document -> saved UNLESS minimizing the window
//	print("TESTING5") never fires, so the workaround is the document label is "not saved" which gets overridden by the `documentStatusLabel`.
//
//	
//	func checkAndUpdateLastModified() {// documentStatusLabel | work in progress
//		if let document = self.document, let fileURL = document.fileURL {
//			if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
//			   let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date {
//				updateStatusLabelWith(date: modificationDate)
//			} else {
//				updateStatusLabelWith(date: nil)
//			}
//		}
//		print("checkAndUpdateLastModified func")
//	}
	
//	func updateStatusLabelWith(date: Date?) {// documentStatusLabel | work in progress
//		print("TESTING1")
//		if let document = self.document {
//			print("TESTING2")
//
//			if document.hasBeenSaved {
//				if let date = date {
//					// Format and set the date
//					let dateFormatter = DateFormatter()
//					dateFormatter.dateStyle = .long
//					dateFormatter.timeStyle = .long
//					documentStatusLabel.stringValue = "Last saved: \(dateFormatter.string(from: date))"
//					print("TESTING3")
//				}
//				print("TESTING4")
//			} else {
//				// Handle new documents
//				print("TESTING5")
//				documentStatusLabel.stringValue = "Never saved"
//			}
//			print("updateStatusLabelWith func")
//		}
//	}
	
	
	// MARK: - Word Count Toggle Setup
	private func setupWordCountToggle() {
		wordCountToggle.state = .on
	}
	
	// MARK: Calculate Initial Word Count
	func calculateInitialWordCount() {
		if wordCountToggle.state == .on {
			updateWordCount()
		} else {
			wordCountLabel.stringValue = "Off"
		}
	}
	
	// MARK: - Word Count
	func updateWordCount() {
		let text = textView.string
		let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
		let wordCount = words.count
		
		if wordCountToggle.state == .on {
			let formattedWordCount = numberFormatter.string(from: NSNumber(value: wordCount)) ?? ""
			wordCountLabel.stringValue = "\(formattedWordCount)"
		} else {
			wordCountLabel.stringValue = "Off"
		}
	}
	
	// Markdown / Plain Text modes
	@IBAction func modeChanged(_ sender: NSPopUpButton) {
		if sender.titleOfSelectedItem == "Markdown" {
			let selectedFont = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: selectedFont)
		} else {
			removeMarkdownStyling()
		}
	}

	
	// ... Add other specific styling functions
	
	func isDarkMode(view: NSView) -> Bool {
		if #available(macOS 10.14, *) {
			return view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
		} else {
			// Fallback for earlier macOS versions
			return false
		}
	}

	func removeMarkdownStyling() {
		guard let textStorage = textView.textStorage else { return }
		
		let fullRange = NSRange(location: 0, length: textStorage.length)
		
		// Remove all attributes
		textStorage.removeAttribute(.font, range: fullRange)
		textStorage.removeAttribute(.foregroundColor, range: fullRange)
		textStorage.removeAttribute(.backgroundColor, range: fullRange)
		textStorage.removeAttribute(.strikethroughStyle, range: fullRange)
		textStorage.removeAttribute(.underlineStyle, range: fullRange)
		textStorage.removeAttribute(.link, range: fullRange)  // Remove link attribute
		// ... remove any other attributes you've added for Markdown styling ...

		// Reapply user-default font preferences
		let defaultFont = selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		textStorage.addAttribute(.font, value: defaultFont, range: fullRange)
		
		// Adjust text color based on appearance mode
		let textColor = isDarkMode(view: textView) ? NSColor.white : NSColor.black
		textStorage.addAttribute(.foregroundColor, value: textColor, range: fullRange)
	}


	
	// MARK: - Word Count and Other Actions
	@IBAction func toggleWordCountDisplay(_ sender: NSButton) {
		if sender.state == .on {
			updateWordCount()
		} else {
			wordCountLabel.stringValue = "Off"
		}
	}
	
	// MARK: SAVE
	@IBAction func saveDocument(_ sender: Any) {
		if let document = self.view.window?.windowController?.document as? Document {
			document.text = textView.string // Update the text property with the content from the text view
			document.updateChangeCount(.changeDone) // Mark the document as dirty
			document.save(self) // Save the document
//			checkAndUpdateLastModified()// // documentStatusLabel | work in progress
//			updateStatusLabelWith(date: Date())// // documentStatusLabel | work in progress
		}
//		print("saveDocument IBAction func")// documentStatusLabel | work in progress
	}// END SAVE
	
	// MARK: - Text View Setup
	private func setupTextView() {
		textView.delegate = self
		updateWordCount()
	}
	
	// MARK: - Markdown Formatting
	func applyMarkdownStyles() {
		guard let textStorage = textView.textStorage else { return }

		let fullRange = NSRange(location: 0, length: textStorage.length)
		textStorage.enumerateAttribute(.font, in: fullRange, options: []) { (value, range, stop) in
			guard let font = value as? NSFont else { return }
			let substring = (textStorage.string as NSString).substring(with: range)

			if substring.hasPrefix("# ") {
				// Apply styles for headers
				let hashRange = (substring as NSString).range(of: "#")
				textStorage.addAttribute(.foregroundColor, value: NSColor.gray, range: NSRange(location: range.location + hashRange.location, length: hashRange.length))

				let textRange = NSRange(location: range.location + hashRange.length, length: range.length - hashRange.length)
				let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
				textStorage.addAttribute(.font, value: boldFont, range: textRange)
			}
		}
	}

}

// MARK: - NSTextViewDelegate
extension ViewController {
	func textDidChange(_ notification: Notification) {
		wordCountUpdateTimer?.invalidate()
		wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
			self?.updateWordCount()
//			self?.updateDocumentSize() //TODO: move this to a different, separate timer or tie it so the save function
		}
//		if markdownModeIsActive { // Replace with your actual condition
//			applyMarkdownStyles()
//		}

	}
	// ... [Any other delegate methods] ...
}

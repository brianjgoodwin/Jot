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
	@IBOutlet weak var modePopUpButton: NSPopUpButton!
	
	private var wordCountUpdateTimer: Timer?
	
	var selectedFont: NSFont?
	var selectedFontSize: CGFloat?
	var currentMode: EditorMode = .plainText
	
	var isUpdatingText = false
	
	let numberFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.locale = Locale(identifier: "en_US") // Set the locale to US
		return formatter
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		textView.delegate = self
		setupTextView()
		setupWordCountToggle()
		loadFontPreferences()
		calculateInitialWordCount() // Calculate the initial word count after setup is complete
//		NotificationCenter.default.addObserver(self, selector: #selector(updateSpellChecking), name: .spellCheckingPreferenceChanged, object: nil)
//		updateSpellChecking() // Call this to set the initial state
	}
	
	override func viewWillAppear() {// documentStatusLabel | work in progress
		super.viewWillAppear()
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
	
	@IBAction func toggleEditorMode(_ sender: Any) {
		currentMode = (currentMode == .markdown) ? .plainText : .markdown
		
		if currentMode == .markdown {
			let selectedFont = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: selectedFont)
		} else {
			removeMarkdownStyling()
		}
		
		updateModeUI()
	}
	
	// Additional helper method to update UI elements like NSPopUpButton to reflect the current mode
	func updateModeUI() {
		let modeTitle = (currentMode == .markdown) ? "Markdown" : "Plain Text"
		modePopUpButton.selectItem(withTitle: modeTitle)
	}
	
	// MARK: - Word Count Toggle Setup
	private func setupWordCountToggle() {
		wordCountToggle.state = .on
	}
	
	// MARK: - Calculate Initial Word Count
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
	
	// MARK: - Mode settings
	// Markdown / Plain Text modes
	@IBAction func modeChanged(_ sender: NSPopUpButton) {
		if sender.titleOfSelectedItem == "Markdown" {
			currentMode = .markdown
			let selectedFont = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: selectedFont)
		} else {
			currentMode = .plainText
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
	
	// MARK: - Toggle Word Wrap
	@IBAction func toggleWordWrap(_ sender: Any) {
		guard let textView = textView, let scrollView = textView.enclosingScrollView else { return }

			if textView.textContainer?.widthTracksTextView == true {
				// Disable word wrapping
				textView.textContainer?.widthTracksTextView = false
				textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
				scrollView.hasHorizontalScroller = true
				// Update the text view's frame width to be wider than the scroll view's content size width
				textView.setFrameSize(CGSize(width: scrollView.frame.width * 2, height: textView.frame.height))
			} else {
				// Enable word wrapping
				textView.textContainer?.widthTracksTextView = true
				textView.textContainer?.containerSize = CGSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
				scrollView.hasHorizontalScroller = false
				textView.setFrameSize(CGSize(width: scrollView.contentSize.width, height: textView.frame.height))
			}
		}
	
	// MARK: - SAVE
	@IBAction func saveDocument(_ sender: Any) {
		if let document = self.view.window?.windowController?.document as? Document {
			document.text = textView.string // Update the text property with the content from the text view
			document.updateChangeCount(.changeDone) // Mark the document as dirty
			document.save(self) // Save the document
		}
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
	
//	@objc func updateSpellChecking() {
//		let isEnabled = UserDefaults.standard.bool(forKey: "spellCheckingEnabled")
//		textView.isContinuousSpellCheckingEnabled = isEnabled
//	}
	
	func applyMarkdownStylingAsUserTypes(in textView: NSTextView) {
		guard let selectedRange = textView.selectedRanges.first?.rangeValue,
			  let selectedFont = selectedFont else { return }
		
		let currentLineRange = (textView.string as NSString).lineRange(for: selectedRange)
		
		// Apply markdown styling to the current line or paragraph
		MarkdownProcessor.applyMarkdownStyling(to: textView, using: selectedFont, range: currentLineRange)
	}
}

// MARK: - NSTextViewDelegate
extension ViewController {
	func textDidChange(_ notification: Notification) {
		guard let textView = notification.object as? NSTextView else { return }
		if currentMode == .markdown {
			// Apply Markdown styling as user types
			let selectedFont = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: selectedFont)
		}
		
		wordCountUpdateTimer?.invalidate()
		wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
			self?.updateWordCount()
		}
	}
	// ... [Any other delegate methods] ...
}

//extension Notification.Name {
//	static let spellCheckingPreferenceChanged = Notification.Name("spellCheckingPreferenceChanged")
//}

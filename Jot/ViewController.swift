//
//  ViewController.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class ViewController: NSViewController, NSTextViewDelegate, TextSettingsDelegate {
	
	@IBOutlet var textView: NSTextView!
	@IBOutlet var wordCountLabel: NSTextField!
	@IBOutlet var wordCountToggle: NSSwitch!
	@IBOutlet weak var modePopUpButton: NSPopUpButton!
	
	private var wordCountUpdateTimer: Timer?
	private var markdownStylingTimer: Timer?
	
	var selectedFont: NSFont?
	var selectedFontSize: CGFloat?
	var currentMode: EditorMode = .plainText
	
	private var didApplyRestoredState = false
	private var showInvisibleCharacters = false
	
	let numberFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.locale = Locale(identifier: "en_US") // Set the locale to US
		return formatter
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		logToFile("[\(Date())] 📝 ViewController viewDidLoad() called")
		logToFile("[\(Date())] 📄 Initial NSTextView content length: \(textView.string.count)")

		textView.delegate = self
		setupTextView()
		setupWordCountToggle()
		loadFontPreferences()
		loadLastUsedMode()
		calculateInitialWordCount() // Calculate the initial word count after setup is complete
		//		NotificationCenter.default.addObserver(self, selector: #selector(updateSpellChecking), name: .spellCheckingPreferenceChanged, object: nil)
		//		updateSpellChecking() // Call this to set the initial state
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			if let document = self.view.window?.windowController?.document as? Document, !self.didApplyRestoredState {
				logToFile("[\(Date())] 📄 Document text length before applying: \(document.text.count)")
				if self.textView.string.isEmpty {
					self.textView.string = document.text
					self.didApplyRestoredState = true
					logToFile("[\(Date())] ✅ Applied restored text to NSTextView")
				} else {
					logToFile("[\(Date())] ⚠ Did not overwrite existing text")
				}
			}
		}
	}
	
	override func viewWillAppear() {// documentStatusLabel | work in progress
		super.viewWillAppear()
		logToFile("[\(Date())] 📝 ViewController viewWillAppear() called")

		// Restore cursor position after a brief delay to ensure text is loaded
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			self.restoreCursorPosition()
		}
	}

	override func viewWillDisappear() {
		super.viewWillDisappear()
		saveCursorPosition()
	}
	
	// MARK: - Text Settings Delegate
	func didSelectFont(_ font: NSFont) {
		selectedFont = font
		updateFont(to: font, size: nil)  // Size is nil, so it retains the current size
		
		// Save the font name to UserDefaults
		UserDefaults.standard.set(font.fontName, forKey: "selectedFontName")
	}
	
	func didSelectFontSize(_ fontSize: CGFloat) {
		// Validate font size is within reasonable bounds
		let minFontSize: CGFloat = 6
		let maxFontSize: CGFloat = 144
		let validatedSize = min(max(fontSize, minFontSize), maxFontSize)

		if validatedSize != fontSize {
			logToFile("⚠️ Font size \(fontSize) out of bounds, clamped to \(validatedSize)")
		}

		selectedFontSize = validatedSize
		updateFont(to: nil, size: validatedSize)  // Font is nil, so it retains the current font

		// Save the font size to UserDefaults
		UserDefaults.standard.set(validatedSize, forKey: "selectedFontSize")
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

			// Validate loaded font size
			let minFontSize: CGFloat = 6
			let maxFontSize: CGFloat = 144
			let fontSize = CGFloat(fontSizeValue)
			let validatedSize = min(max(fontSize, minFontSize), maxFontSize)

			if validatedSize != fontSize {
				logToFile("⚠️ Loaded font size \(fontSize) out of bounds, using \(validatedSize)")
			}

			selectedFontSize = validatedSize
			if let font = NSFont(name: fontName, size: validatedSize) {
				selectedFont = font
			} else {
				logToFile("⚠️ Could not load font '\(fontName)', using system font")
				selectedFont = NSFont.systemFont(ofSize: validatedSize)
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
	
	@IBAction func toggleEditorMode(_ sender: Any) {
		currentMode = (currentMode == .markdown) ? .plainText : .markdown

		if currentMode == .markdown {
			let selectedFont = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: selectedFont)
		} else {
			removeMarkdownStyling()
		}

		updateModeUI()
		saveCurrentMode()
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
		let charCount = text.count

		if wordCountToggle.state == .on {
			let formattedWordCount = numberFormatter.string(from: NSNumber(value: wordCount)) ?? ""
			let formattedCharCount = numberFormatter.string(from: NSNumber(value: charCount)) ?? ""
			wordCountLabel.stringValue = "\(formattedWordCount) words • \(formattedCharCount) chars"
		} else {
			wordCountLabel.stringValue = "Off"
		}
	}
	
	// MARK: - Mode settings
	// Markdown / Plain Text modes
	func loadLastUsedMode() {
		let savedMode = UserDefaults.standard.string(forKey: "lastUsedEditorMode") ?? "plainText"
		currentMode = (savedMode == "markdown") ? .markdown : .plainText

		// Apply the mode
		if currentMode == .markdown {
			let selectedFont = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: selectedFont)
		}

		// Update UI to reflect the mode
		updateModeUI()
		logToFile("📝 Restored editor mode: \(currentMode == .markdown ? "Markdown" : "Plain Text")")
	}

	func saveCurrentMode() {
		let modeString = (currentMode == .markdown) ? "markdown" : "plainText"
		UserDefaults.standard.set(modeString, forKey: "lastUsedEditorMode")
	}

	@IBAction func modeChanged(_ sender: NSPopUpButton) {
		if sender.titleOfSelectedItem == "Markdown" {
			currentMode = .markdown
			let selectedFont = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: selectedFont)
		} else {
			currentMode = .plainText
			removeMarkdownStyling()
		}

		// Save the mode preference
		saveCurrentMode()
	}
	
	// ... Add other specific styling functions
	
	func removeMarkdownStyling() {
		guard let textStorage = textView.textStorage else { return }

		let fullRange = NSRange(location: 0, length: textStorage.length)
		let baseFont = selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

		textStorage.beginEditing()
		textStorage.addAttribute(.font, value: baseFont, range: fullRange)
		textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
		textStorage.removeAttribute(.backgroundColor, range: fullRange)
		textStorage.removeAttribute(.strikethroughStyle, range: fullRange)
		textStorage.removeAttribute(.underlineStyle, range: fullRange)
		textStorage.removeAttribute(.link, range: fullRange)
		textStorage.endEditing()
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
		loadSmartQuotesPreference()
		loadInvisibleCharactersPreference()
		loadTabWidthPreference()
	}

	func loadTabWidthPreference() {
		let tabWidth = UserDefaults.standard.integer(forKey: "tabWidth")
		let width = tabWidth == 0 ? 4 : tabWidth // Default to 4
		setTabWidth(width)
	}

	// MARK: - Smart Quotes
	func loadSmartQuotesPreference() {
		// Load smart quotes setting from UserDefaults (default to false for code editing)
		let smartQuotesEnabled = UserDefaults.standard.bool(forKey: "smartQuotesEnabled")
		textView.isAutomaticQuoteSubstitutionEnabled = smartQuotesEnabled
		logToFile("📝 Smart quotes setting loaded: \(smartQuotesEnabled)")
	}

	func setSmartQuotesEnabled(_ enabled: Bool) {
		textView.isAutomaticQuoteSubstitutionEnabled = enabled
		UserDefaults.standard.set(enabled, forKey: "smartQuotesEnabled")
		logToFile("📝 Smart quotes \(enabled ? "enabled" : "disabled")")
	}

	// MARK: - Invisible Characters
	func loadInvisibleCharactersPreference() {
		showInvisibleCharacters = UserDefaults.standard.bool(forKey: "showInvisibleCharacters")
		applyInvisibleCharactersDisplay()
		logToFile("📝 Invisible characters setting loaded: \(showInvisibleCharacters)")
	}

	func setShowInvisibleCharacters(_ enabled: Bool) {
		showInvisibleCharacters = enabled
		UserDefaults.standard.set(enabled, forKey: "showInvisibleCharacters")
		applyInvisibleCharactersDisplay()
		logToFile("📝 Invisible characters \(enabled ? "enabled" : "disabled")")
	}

	private func applyInvisibleCharactersDisplay() {
		guard let textStorage = textView.textStorage else { return }

		let fullRange = NSRange(location: 0, length: textStorage.length)

		textStorage.beginEditing()

		if showInvisibleCharacters {
			// Use UTF-16 offsets for NSRange — String.enumerated() yields Character
			// indices which diverge from UTF-16 offsets for multi-byte characters.
			var utf16Offset = 0
			for char in textStorage.string {
				let charUTF16Length = char.utf16.count
				let range = NSRange(location: utf16Offset, length: charUTF16Length)
				if char == " " {
					textStorage.addAttribute(.backgroundColor, value: NSColor.gray.withAlphaComponent(0.1), range: range)
				} else if char == "\t" {
					textStorage.addAttribute(.backgroundColor, value: NSColor.blue.withAlphaComponent(0.1), range: range)
				}
				utf16Offset += charUTF16Length
			}
		} else {
			textStorage.removeAttribute(.backgroundColor, range: fullRange)
		}

		textStorage.endEditing()
		textView.needsDisplay = true
	}

	// MARK: - Tab Width
	func setTabWidth(_ width: Int) {
		guard let font = textView.font else { return }

		// Calculate the width of a space character
		let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
		let tabInterval = spaceWidth * CGFloat(width)

		// Create a paragraph style with the tab interval
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.defaultTabInterval = tabInterval
		paragraphStyle.tabStops = []

		// Apply to the entire text
		textView.defaultParagraphStyle = paragraphStyle
		textView.typingAttributes[.paragraphStyle] = paragraphStyle

		// Apply to existing text
		if let textStorage = textView.textStorage {
			let fullRange = NSRange(location: 0, length: textStorage.length)
			textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
		}

		logToFile("📝 Tab width set to \(width) spaces")
	}

	// MARK: - Zoom
	@IBAction func zoomIn(_ sender: Any) {
		guard let currentFont = textView.font else { return }
		let newSize = min(currentFont.pointSize + 1, 144) // Max size 144
		textView.font = NSFont(descriptor: currentFont.fontDescriptor, size: newSize)
		logToFile("🔍 Zoomed in to size: \(newSize)")
	}

	@IBAction func zoomOut(_ sender: Any) {
		guard let currentFont = textView.font else { return }
		let newSize = max(currentFont.pointSize - 1, 6) // Min size 6
		textView.font = NSFont(descriptor: currentFont.fontDescriptor, size: newSize)
		logToFile("🔍 Zoomed out to size: \(newSize)")
	}

	@IBAction func resetZoom(_ sender: Any) {
		// Reset to the saved font preference
		updateFont(to: selectedFont, size: selectedFontSize)
		logToFile("🔍 Reset zoom to default size: \(selectedFontSize ?? 12)")
	}

	// MARK: - Cursor Position
	func saveCursorPosition() {
		guard let document = self.view.window?.windowController?.document as? Document else { return }

		let cursorPosition = textView.selectedRange().location
		UserDefaults.standard.set(cursorPosition, forKey: document.cursorPositionKey)
		logToFile("💾 Saved cursor position: \(cursorPosition)")
	}

	func restoreCursorPosition() {
		guard let document = self.view.window?.windowController?.document as? Document else { return }

		let savedPosition = UserDefaults.standard.integer(forKey: document.cursorPositionKey)

		// Only restore if the position is valid and within bounds
		if savedPosition > 0 && savedPosition <= textView.string.count {
			let range = NSRange(location: savedPosition, length: 0)
			textView.setSelectedRange(range)
			textView.scrollRangeToVisible(range)
			logToFile("📍 Restored cursor position: \(savedPosition)")
		}
	}

	// MARK: - Quote Conversion
	@IBAction func convertToStraightQuotes(_ sender: Any) {
		guard let textStorage = textView.textStorage else { return }
		let fullRange = NSRange(location: 0, length: textStorage.length)
		let originalText = textStorage.string

		var convertedText = originalText
		// Convert curly double quotes to straight
		convertedText = convertedText.replacingOccurrences(of: "\u{201C}", with: "\"") // "
		convertedText = convertedText.replacingOccurrences(of: "\u{201D}", with: "\"") // "
		// Convert curly single quotes to straight
		convertedText = convertedText.replacingOccurrences(of: "\u{2018}", with: "'") // '
		convertedText = convertedText.replacingOccurrences(of: "\u{2019}", with: "'") // '

		if convertedText != originalText {
			textStorage.replaceCharacters(in: fullRange, with: convertedText)
			if let document = self.view.window?.windowController?.document as? Document {
				document.updateChangeCount(.changeDone)
			}
			logToFile("✅ Converted curly quotes to straight quotes")
		}
	}

	@IBAction func convertToCurlyQuotes(_ sender: Any) {
		guard let textStorage = textView.textStorage else { return }
		let fullRange = NSRange(location: 0, length: textStorage.length)
		let originalText = textStorage.string

		var convertedText = originalText

		// Convert straight quotes to curly quotes
		// This is a simplified approach - a more sophisticated version would track opening/closing context
		convertedText = convertSmartQuotes(in: convertedText)

		if convertedText != originalText {
			textStorage.replaceCharacters(in: fullRange, with: convertedText)
			if let document = self.view.window?.windowController?.document as? Document {
				document.updateChangeCount(.changeDone)
			}
			logToFile("✅ Converted straight quotes to curly quotes")
		}
	}

	private func convertSmartQuotes(in text: String) -> String {
		var convertedString = ""
		var prevChar: Character = " "

		for char in text {
			if char == "\"" {
				// Opening after whitespace/punctuation/start; closing otherwise
				let isOpening = prevChar.isWhitespace || prevChar.isPunctuation || convertedString.isEmpty
				convertedString.append(isOpening ? "\u{201C}" : "\u{201D}")
			} else if char == "'" {
				// Opening after whitespace/start; apostrophe/closing otherwise
				let isOpening = prevChar.isWhitespace || convertedString.isEmpty
				convertedString.append(isOpening ? "\u{2018}" : "\u{2019}")
			} else {
				convertedString.append(char)
			}
			prevChar = char
		}

		return convertedString
	}
	
	//	@objc func updateSpellChecking() {
	//		let isEnabled = UserDefaults.standard.bool(forKey: "spellCheckingEnabled")
	//		textView.isContinuousSpellCheckingEnabled = isEnabled
	//	}
	
}

// MARK: - NSTextViewDelegate
extension ViewController {
	func textDidChange(_ notification: Notification) {
		guard let textView = notification.object as? NSTextView else { return }

		// Update the document's model with the current text view content.
		if let document = self.view.window?.windowController?.document as? Document {
			document.text = textView.string
			logToFile("✏️ textDidChange: Updated Document text (length: \(document.text.count))")
		}

		markdownStylingTimer?.invalidate()
		markdownStylingTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
			guard let self else { return }
			if self.currentMode == .markdown {
				let font = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
				MarkdownProcessor.applyMarkdownStyling(to: self.textView, using: font)
			}
			if self.showInvisibleCharacters {
				self.applyInvisibleCharactersDisplay()
			}
		}

		wordCountUpdateTimer?.invalidate()
		wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
			self?.updateWordCount()
		}
	}
}

//extension Notification.Name {
//	static let spellCheckingPreferenceChanged = Notification.Name("spellCheckingPreferenceChanged")
//}

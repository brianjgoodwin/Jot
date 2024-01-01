//
//  ViewController.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class ViewController: NSViewController {
	// MARK: - Outlets and Properties
	@IBOutlet var textView: NSTextView!
	@IBOutlet var wordCountLabel: NSTextField!
	@IBOutlet var wordCountToggle: NSSwitch!
	var isMarkdownSelected = false
	private var currentZoomLevel: CGFloat = 1.0
	private var baseFontSize: CGFloat = 12.0
	private var wordCountUpdateTimer: Timer?
	let numberFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.locale = Locale(identifier: "en_US") // Set the locale to US
		return formatter
	}()
	var markdownFormatter: MarkdownFormatter!
	
	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		// Ensure that both zoomLevel and baseFontSize are passed to the initializer
		markdownFormatter = MarkdownFormatter(zoomLevel: currentZoomLevel, baseFontSize: baseFontSize)
		setupTextView()
		setupWordCountToggle()
		// ... Other setup code
	}
	
	@objc func updateTextViewFont() {
		let userDefaults = UserDefaults.standard
		let fontName = userDefaults.string(forKey: "SelectedFont") ?? "SystemDefault"
		// Use the font(forName:) method from the markdownFormatter instance
		textView.font = markdownFormatter.font(forName: fontName)
	}
	
	func applyFontSizePreference(_ fontSize: String) {
		guard let size = Float(fontSize) else { return }
		let newFont = NSFont.systemFont(ofSize: CGFloat(size)) // Adjust as needed for the user's preferred font
		// Update your text views or other UI elements with the new font
	}
	
	// MARK: - Preferences
	func applyUserPreferences() {
		let preferredFontName = PreferencesManager.shared.preferredFontName
		let preferredFontSize = PreferencesManager.shared.preferredFontSize
		if let font = NSFont(name: preferredFontName, size: preferredFontSize) {
			textView.font = font
		}
	}
	
	// MARK: - Syntax Popup Menu Action
	@IBAction func syntaxPopupMenu(_ sender: Any) {
		guard let popupButton = sender as? NSPopUpButton, let textStorage = textView.textStorage else { return }
		isMarkdownSelected = popupButton.selectedItem?.title == "Markdown"
		if isMarkdownSelected {
			// Call applyMarkdownFormatting on the markdownFormatter instance
			markdownFormatter.applyMarkdownFormatting(to: textStorage, zoomLevel: currentZoomLevel)
		} else {
			// Call removeMarkdownFormatting on the markdownFormatter instance
			markdownFormatter.removeMarkdownFormatting(from: textStorage)
		}
	}
	
	// MARK: - Zoom Actions
	@IBAction func zoom100Percent(_ sender: Any) { setZoomLevel(1.0) }
	@IBAction func zoom125Percent(_ sender: Any) { setZoomLevel(1.25) }
	@IBAction func zoom150Percent(_ sender: Any) { setZoomLevel(1.5) }
	@IBAction func decreaseFontSize(_ sender: Any) {
		if currentZoomLevel > 0.5 { // Minimum zoom level
			currentZoomLevel -= 0.25 // Decrease by 25%
			setZoomLevel(currentZoomLevel)
		}
	}
	
	func setZoomLevel(_ zoomLevel: CGFloat) {
		currentZoomLevel = zoomLevel
		let newFontSize = baseFontSize * zoomLevel
		if let currentFont = textView.font {
			let newFont = NSFont(descriptor: currentFont.fontDescriptor, size: newFontSize)
			textView.font = newFont
		}
		// Reapply Markdown formatting with the new zoom level
		if isMarkdownSelected {
			// Ensure you have access to textStorage from the textView
			if let textStorage = textView.textStorage {
				// Call applyMarkdownFormatting on the markdownFormatter instance
				markdownFormatter.applyMarkdownFormatting(to: textStorage, zoomLevel: currentZoomLevel)
			}
		}
	}
	
	// MARK: - Word Count and Other Actions
	// Add a property to keep track of the word count update timer
	//	private var wordCountUpdateTimer: Timer?
	
	@IBAction func toggleWordCountDisplay(_ sender: NSButton) {
		if sender.state == .on {
			// Show word count
			updateWordCount()
		} else {
			// Hide word count
			wordCountLabel.stringValue = "Off"
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
	
	@IBAction func openMarkdownPreview(_ sender: Any) {
		let storyboard = NSStoryboard(name: NSStoryboard.Name("MarkdownPreview"), bundle: nil)
		
		if let markdownPreviewWindowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MarkdownPreviewWindowController")) as? NSWindowController {
			markdownPreviewWindowController.showWindow(self)
		}
	}
	
	// MARK: Open Settings
	@IBAction func openSettings(_ sender: Any) {
		let storyboard = NSStoryboard(name: "Settings", bundle: nil)
		if let windowController = storyboard.instantiateInitialController() as? NSWindowController {
			windowController.showWindow(self)
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
	
	func calculateInitialWordCount() {
		if wordCountToggle.state == .on {
			updateWordCount()
		} else {
			wordCountLabel.stringValue = "Off"
		}
	}
	
	// MARK: - Number Formatter
	
	
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
		guard let textStorage = textView.textStorage else { return }
		if isMarkdownSelected {
			markdownFormatter.applyMarkdownFormatting(to: textStorage, zoomLevel: currentZoomLevel)
		} else {
			markdownFormatter.removeMarkdownFormatting(from: textStorage)
		}
		//		/// moved to MarkdownFormatter ?
		//		if isMarkdownSelected {
		//			markdownFormatter.applyMarkdownFormatting(to: textView.textStorage, zoomLevel: currentZoomLevel)
		//		} else {
		//			markdownFormatter.removeMarkdownFormatting()
		//		}/// moved to MarkdownFormatter ?
		// Schedule a new timer to update word count after a delay (e.g., 0.5 seconds)
		wordCountUpdateTimer?.invalidate()
		wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
			self?.updateWordCount()
		}
	}
	// ... [Any other delegate methods] ...
}

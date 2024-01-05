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
	private var wordCountUpdateTimer: Timer?
	
	var selectedFont: NSFont?
	var selectedFontSize: CGFloat?
	
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
		}
	}// END SAVE
	
	// MARK: - Text View Setup
	private func setupTextView() {
		textView.delegate = self
		updateWordCount()
	}
}

// MARK: - NSTextViewDelegate
extension ViewController {
	func textDidChange(_ notification: Notification) {
		wordCountUpdateTimer?.invalidate()
		wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
			self?.updateWordCount()
		}
	}
	// ... [Any other delegate methods] ...
}

//import Cocoa
//
//class ViewController: NSViewController {
//	// MARK: - Outlets and Properties
//	@IBOutlet var textView: NSTextView!
//	@IBOutlet var wordCountLabel: NSTextField!
//	@IBOutlet var wordCountToggle: NSSwitch!
//	var isMarkdownSelected = false
//	private var wordCountUpdateTimer: Timer?
//	let numberFormatter: NumberFormatter = {
//		let formatter = NumberFormatter()
//		formatter.numberStyle = .decimal
//		formatter.locale = Locale(identifier: "en_US") // Set the locale to US
//		return formatter
//	}()
//	var markdownFormatter = MarkdownFormatter()
//
//	// MARK: - Lifecycle
//	override func viewDidLoad() {
//		super.viewDidLoad()
//		markdownFormatter = MarkdownFormatter()  // No parameters needed now
//
//		setupTextView()
//		setupWordCountToggle()
//		// ... Other setup code
//
//		applyUserFontPreferences()
//
//		NotificationCenter.default.addObserver(self, selector: #selector(updateTextViewStyle(_:)), name: Notification.Name("TextStyleDidChange"), object: nil)
//
//	}
//
//	@objc func updateTextViewStyle(_ notification: Notification) {
//		guard let userInfo = notification.userInfo,
//			  let fontName = userInfo["fontName"] as? String,
//			  let fontSize = userInfo["fontSize"] as? String,
//			  let size = Float(fontSize) else { return }
//
//		let newFont = markdownFormatter.font(forName: fontName, size: size)
//		textView.font = newFont
//		// Optionally, refresh the textView or reapply text formatting if necessary
//	}
//
//
////	@objc func updateTextViewFont(_ notification: Notification) {
////		if let newFont = notification.object as? NSFont {
////			textView.font = newFont
////			// Refresh the textView or reapply text formatting if necessary
////		}
////	}
//
//	func applyUserFontPreferences() {
//		// Retrieve the user's preferred font and size
//		let fontName = UserDefaults.standard.string(forKey: "SelectedFont") ?? "SystemDefault"
//		let fontSize = UserDefaults.standard.string(forKey: "DefaultFontSize") ?? "12"
//
//		// Adjust this as needed to fit how you're managing fonts
//		if let font = NSFont(name: fontName, size: CGFloat(Float(fontSize) ?? 12.0)) {
//			textView.font = font
//		}
//	}
//
//	func applyFontSizePreference(_ fontSize: String) {
//		guard let size = Float(fontSize) else { return }
//		let newFont = NSFont.systemFont(ofSize: CGFloat(size)) // Adjust as needed for the user's preferred font
//		// Update your text views or other UI elements with the new font
//	}
//
//	@objc func updateTextEditorFont() {
//		// Retrieve the font and size from UserDefaults
//		let fontName = UserDefaults.standard.string(forKey: "SelectedFont") ?? "SystemDefault"
//		let fontSize = UserDefaults.standard.string(forKey: "DefaultFontSize") ?? "12"
//
//		// Apply the font and size to your text editor
//		applyUserFontPreferences(fontName: fontName, fontSize: fontSize)
//	}
//
//	func applyUserFontPreferences(fontName: String, fontSize: String) {
//		guard let size = Float(fontSize) else { return }
//		let newFont = markdownFormatter.font(forName: fontName, size: size)
//		textView.font = newFont
//	}
//
//
//
//	// MARK: - Syntax Popup Menu Action
//	@IBAction func syntaxPopupMenu(_ sender: Any) {
//		guard let popupButton = sender as? NSPopUpButton else { return }
//		isMarkdownSelected = popupButton.selectedItem?.title == "Markdown"
//
//		if let textStorage = textView.textStorage {
//			let baseFont = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
//			if isMarkdownSelected {
//				markdownFormatter.applyMarkdownFormatting(to: textStorage, baseFont: baseFont)
//			} else {
//				removeMarkdownFormatting(from: textView.textStorage, using: markdownFormatter)
//			}
//		}
//	}
//
//
//	// MARK: - Word Count and Other Actions
//	@IBAction func toggleWordCountDisplay(_ sender: NSButton) {
//		if sender.state == .on {
//			// Show word count
//			updateWordCount()
//		} else {
//			// Hide word count
//			wordCountLabel.stringValue = "Off"
//		}
//	}
//
//	@IBAction func saveDocument(_ sender: Any) {
//		// Get a reference to the associated document
//		if let document = self.view.window?.windowController?.document as? Document {
//			document.text = textView.string // Update the text property with the content from the text view
//			document.updateChangeCount(.changeDone) // Mark the document as dirty
//			document.save(self) // Save the document
//		}
//	}
//
//	@IBAction func openMarkdownPreview(_ sender: Any) {
//		let storyboard = NSStoryboard(name: NSStoryboard.Name("MarkdownPreview"), bundle: nil)
//
//		if let markdownPreviewWindowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MarkdownPreviewWindowController")) as? NSWindowController {
//			markdownPreviewWindowController.showWindow(self)
//		}
//	}
//
//	// MARK: Open Settings
//	@IBAction func openSettings(_ sender: Any) {
//		let storyboard = NSStoryboard(name: "Settings", bundle: nil)
//		if let windowController = storyboard.instantiateInitialController() as? NSWindowController {
//			windowController.showWindow(self)
//		}
//	}
//
//	// MARK: - Word Count
//	func updateWordCount() {
//		let text = textView.string
//		let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
//		let wordCount = words.count
//
//		if wordCountToggle.state == .on {
//			let formattedWordCount = numberFormatter.string(from: NSNumber(value: wordCount)) ?? ""
//			wordCountLabel.stringValue = "\(formattedWordCount)"
//		} else {
//			wordCountLabel.stringValue = "Off"
//		}
//	}
//
//	func calculateInitialWordCount() {
//		if wordCountToggle.state == .on {
//			updateWordCount()
//		} else {
//			wordCountLabel.stringValue = "Off"
//		}
//	}
//
//	// MARK: - Text View Setup
//	private func setupTextView() {
//		textView.delegate = self
//		updateWordCount()
//	}
//
//	// MARK: - Word Count Toggle Setup
//	private func setupWordCountToggle() {
//		// Set the initial state based on your app's default behavior
//		wordCountToggle.state = .on
//	}
//}
//
//// MARK: - NSTextViewDelegate
//extension ViewController: NSTextViewDelegate {
//	func textDidChange(_ notification: Notification) {
//		if let textStorage = textView.textStorage {
//			let baseFont = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)  // Or fetch from user settings
//			if isMarkdownSelected {
//				markdownFormatter.applyMarkdownFormatting(to: textStorage, baseFont: baseFont)
//			} else {
//				markdownFormatter.removeMarkdownFormatting(from: textStorage, baseFont: baseFont)
//			}
//		}
//
//		// Schedule a new timer to update word count after a delay (e.g., 0.5 seconds)
//		wordCountUpdateTimer?.invalidate()
//		wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
//			self?.updateWordCount()
//		}
//	}
//	// ... [Any other delegate methods] ...
//}
//

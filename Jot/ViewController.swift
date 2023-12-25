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
	
	var isMarkdownSelected = false
	
	// MARK: - Zoom levels
	private var currentZoomLevel: CGFloat = 1.0
	
	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupTextView()
		setupWordCountToggle()
		// Other setup code if needed
	}
	
	// MARK: - Markdown Formatting
	func applyMarkdownFormatting() {
		guard let textStorage = textView.textStorage else { return }
		let entireRange = NSRange(location: 0, length: textStorage.length)
		
		// Remove any previous formatting
		textStorage.removeAttribute(.font, range: entireRange)
		textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: entireRange)
		
		// Define regular expressions for Markdown patterns
		let headerRegex = try! NSRegularExpression(pattern: "^# .*$", options: .anchorsMatchLines)
		let boldRegex = try! NSRegularExpression(pattern: "\\*\\*.*?\\*\\*", options: [])
		let italicRegex = try! NSRegularExpression(pattern: "(\\*|_)(.*?)(\\1)", options: [])
		let linkRegex = try! NSRegularExpression(pattern: "\\[([^\\[]+)\\]\\(([^\\)]+)\\)", options: [])
		let codeInlineRegex = try! NSRegularExpression(pattern: "`(.*?)`", options: [])
		let codeBlockRegex = try! NSRegularExpression(pattern: "```\\s*([^`]+)\\s*```", options: [])

		// Apply header style
		applyStyle(with: headerRegex, to: textStorage, using: NSFont.boldSystemFont(ofSize: 24), range: entireRange)
		
		// Apply bold style
		applyStyle(with: boldRegex, to: textStorage, using: NSFont.boldSystemFont(ofSize: 12), range: entireRange)
		
		// Apply italic style
		applyStyle(with: italicRegex, to: textStorage, using: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 12), toHaveTrait: .italicFontMask), range: entireRange)
		
		// Apply link style (this example just changes color, but you might want to do more)
		applyLinkStyle(with: linkRegex, to: textStorage, range: entireRange)
		
		// Apply inline code style
		applyStyle(with: codeInlineRegex, to: textStorage, using: NSFont.userFixedPitchFont(ofSize: 12) ?? NSFont.systemFont(ofSize: 12), range: entireRange, backgroundColor: NSColor.systemGray)
		
		// Apply code block style
		applyStyle(with: codeBlockRegex, to: textStorage, using: NSFont.userFixedPitchFont(ofSize: 12) ?? NSFont.systemFont(ofSize: 12), range: entireRange, backgroundColor: NSColor.systemGray)
	}

	func applyStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, using font: NSFont, range: NSRange, backgroundColor: NSColor? = nil) {
		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			if let matchRange = match?.range {
				textStorage.addAttribute(.font, value: font, range: matchRange)
				if let bgColor = backgroundColor {
					textStorage.addAttribute(.backgroundColor, value: bgColor, range: matchRange)
				}
			}
		}
	}

	func applyLinkStyle(with regex: NSRegularExpression, to textStorage: NSTextStorage, range: NSRange) {
		regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
			if let matchRange = match?.range(at: 1) { // Change to range(at: 2) to style the URL instead
				textStorage.addAttribute(.foregroundColor, value: NSColor.blue, range: matchRange)
				textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
			}
		}
	}


	func removeMarkdownFormatting() {
		guard let textStorage = textView.textStorage else { return }
		let entireRange = NSRange(location: 0, length: textStorage.length)
		// Remove any Markdown formatting
		textStorage.removeAttribute(.font, range: entireRange)
		// Reset to the default style or whatever you prefer
		textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: entireRange)
	}
	
	// MARK: - Syntax Popup Menu Action
	@IBAction func syntaxPopupMenu(_ sender: Any) {
		guard let popupButton = sender as? NSPopUpButton else { return }
		isMarkdownSelected = popupButton.selectedItem?.title == "Markdown"
		if isMarkdownSelected {
			applyMarkdownFormatting()
		} else {
			removeMarkdownFormatting()
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
		let defaultFontSize: CGFloat = 12.0
		let newFontSize = defaultFontSize * zoomLevel
		if let currentFont = textView.font {
			let newFont = NSFont(descriptor: currentFont.fontDescriptor, size: newFontSize)
			textView.font = newFont
		}
	}

	// MARK: - Word Count and Other Actions
	// Add a property to keep track of the word count update timer
	private var wordCountUpdateTimer: Timer?
	
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
		if isMarkdownSelected {
			applyMarkdownFormatting()
		} else {
			removeMarkdownFormatting()
		}
		// Schedule a new timer to update word count after a delay (e.g., 0.5 seconds)
		wordCountUpdateTimer?.invalidate()
		wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
			self?.updateWordCount()
		}
	}
	// ... [Any other delegate methods] ...
}

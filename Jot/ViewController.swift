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
	
//	"Font size" buttons
//	@IBOutlet var increaseFontSizeButton: NSButton!
//	@IBOutlet var decreaseFontSizeButton: NSButton!
//	end font size buttons
	
//	"Font size" functions
//	@IBAction func increaseFontSize(_ sender: Any) {
//		// Get the current font from the text view's text storage
//		if let currentFont = textView.textStorage?.font {
//			// Calculate the new font size (e.g., increase by 2 points)
//			let newFontSize = currentFont.pointSize + 2.0
//			
//			// Create a new font with the adjusted size
//			let newFont = NSFont(descriptor: currentFont.fontDescriptor, size: newFontSize)
//			
//			// Apply the new font to the text view's text storage
//			textView.textStorage?.addAttribute(.font, value: newFont, range: NSMakeRange(0, (textView.textStorage?.length ?? 0)))
//		}
//	}
//	
//	@IBAction func decreaseFontSize(_ sender: Any) {
//		// Get the current font from the text view's text storage
//		if let currentFont = textView.textStorage?.font {
//			// Calculate the new font size (e.g., increase by 2 points)
//			let newFontSize = currentFont.pointSize - 2.0
//			
//			// Create a new font with the adjusted size
//			let newFont = NSFont(descriptor: currentFont.fontDescriptor, size: newFontSize)
//			
//			// Apply the new font to the text view's text storage
//			textView.textStorage?.addAttribute(.font, value: newFont, range: NSMakeRange(0, (textView.textStorage?.length ?? 0)))
//		}
//	}
//	end font size functions
	
	
	// MARK: - zoom levels
	// Add a property to store the current zoom level
	private var currentZoomLevel: CGFloat = 1.0

	// ...

	@IBAction func zoom100Percent(_ sender: Any) {
		// Set the zoom level to 100%
		setZoomLevel(1.0)
	}

	@IBAction func zoom125Percent(_ sender: Any) {
		// Set the zoom level to 125%
		setZoomLevel(1.25)
	}

	@IBAction func zoom150Percent(_ sender: Any) {
		// Set the zoom level to 150%
		setZoomLevel(1.5)
	}

	@IBAction func decreaseFontSize(_ sender: Any) {
		// Decrease the font size (zoom out)
		if currentZoomLevel > 0.5 { // Minimum zoom level (adjust as needed)
			currentZoomLevel -= 0.25 // Decrease by 25%
			setZoomLevel(currentZoomLevel)
		}
	}

	func setZoomLevel(_ zoomLevel: CGFloat) {
		// Store the current zoom level
		currentZoomLevel = zoomLevel
		
		// Get the default font size (adjust as needed)
		let defaultFontSize: CGFloat = 12.0
		
		// Calculate the new font size based on the zoom level and default font size
		let newFontSize = defaultFontSize * zoomLevel
		
		// Create a new font with the adjusted size
		if let currentFont = textView.textStorage?.font {
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
			//wordCountLabel.stringValue = "Word Count: \(formattedWordCount)"
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
		// Invalidate the previous timer
		wordCountUpdateTimer?.invalidate()
		
		// Schedule a new timer to update word count after a delay (e.g., 1 second)
		wordCountUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
			self?.updateWordCount()
		}
	}
}

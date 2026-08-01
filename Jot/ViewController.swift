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
	private var documentSyncTimer: Timer?
	private var visibleRangeStyleTimer: Timer?
	
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
		calculateInitialWordCount()

		// Restyle visible range when the user scrolls in markdown mode
		if let scrollView = textView.enclosingScrollView {
			NotificationCenter.default.addObserver(
				self,
				selector: #selector(scrollViewDidScroll),
				name: NSView.boundsDidChangeNotification,
				object: scrollView.contentView
			)
			scrollView.contentView.postsBoundsChangedNotifications = true
		}
	}

	@objc private func scrollViewDidScroll(_ notification: Notification) {
		guard currentMode == .markdown else { return }
		visibleRangeStyleTimer?.invalidate()
		visibleRangeStyleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
			guard let self = self,
				  let visibleRange = self.visibleCharacterRange() else { return }
			let font = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: self.textView, using: font, range: visibleRange)
		}
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
		let fontConfig = FontConfiguration.shared
		fontConfig.applyFont(font)
		selectedFont = fontConfig.resolvedFont()
		textView.font = selectedFont
	}

	func didSelectFontSize(_ fontSize: CGFloat) {
		let fontConfig = FontConfiguration.shared
		fontConfig.applySize(fontSize)
		selectedFontSize = fontSize
		selectedFont = fontConfig.resolvedFont()
		textView.font = selectedFont
	}

	func loadFontPreferences() {
		let fontConfig = FontConfiguration.shared
		selectedFont = fontConfig.resolvedFont()
		selectedFontSize = fontConfig.currentSize
		textView.font = selectedFont
	}

	func currentFontSize() -> CGFloat {
		return FontConfiguration.shared.currentSize
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
		if wordCountToggle.state == .on {
			let stats = TextStatistics(text: textView.string)
			let formattedWordCount = numberFormatter.string(from: NSNumber(value: stats.wordCount)) ?? ""
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
	
	func removeMarkdownStyling() {
		guard let textStorage = textView.textStorage else { return }

		let fullRange = NSRange(location: 0, length: textStorage.length)

		textStorage.beginEditing()
		textStorage.removeAttribute(.font, range: fullRange)
		textStorage.removeAttribute(.foregroundColor, range: fullRange)
		textStorage.removeAttribute(.backgroundColor, range: fullRange)
		textStorage.removeAttribute(.strikethroughStyle, range: fullRange)
		textStorage.removeAttribute(.underlineStyle, range: fullRange)
		textStorage.removeAttribute(.link, range: fullRange)

		let defaultFont = selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		textStorage.addAttribute(.font, value: defaultFont, range: fullRange)
		textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
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
	
	// MARK: - Save
	@IBAction func saveDocument(_ sender: Any) {
		if let document = self.view.window?.windowController?.document as? Document {
			// Flush any pending debounced sync before saving
			documentSyncTimer?.invalidate()
			document.text = textView.string
			document.save(self)
		}
	}
	
	// MARK: - Text View Setup
	private func setupTextView() {
		textView.delegate = self
		updateWordCount()
	}
	
	// MARK: - Lazy Markdown Styling

	private func visibleCharacterRange() -> NSRange? {
		guard let layoutManager = textView.layoutManager,
			  let textContainer = textView.textContainer,
			  let scrollView = textView.enclosingScrollView else { return nil }

		let visibleRect = scrollView.contentView.bounds
		let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
		return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
	}

	private func styleCurrentLineAndDeferVisible(in textView: NSTextView) {
		guard let selectedRange = textView.selectedRanges.first?.rangeValue else { return }
		let font = selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

		// Immediately style the line the user is editing
		let currentLineRange = (textView.string as NSString).lineRange(for: selectedRange)
		MarkdownProcessor.applyMarkdownStyling(to: textView, using: font, range: currentLineRange)

		// Debounce a visible-range restyle so surrounding context catches up
		visibleRangeStyleTimer?.invalidate()
		visibleRangeStyleTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
			guard let self = self, let visibleRange = self.visibleCharacterRange() else { return }
			MarkdownProcessor.applyMarkdownStyling(to: self.textView, using: font, range: visibleRange)
		}
	}
}

// MARK: - NSTextViewDelegate
extension ViewController {
	func textDidChange(_ notification: Notification) {
		guard let textView = notification.object as? NSTextView else { return }

		// Debounce the document text sync to avoid copying the entire string
		// on every keystroke. AppKit's undo manager tracks the actual edits.
		documentSyncTimer?.invalidate()
		documentSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
			guard let self = self,
				  let document = self.view.window?.windowController?.document as? Document else { return }
			document.text = self.textView.string
		}

		if currentMode == .markdown {
			styleCurrentLineAndDeferVisible(in: textView)
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

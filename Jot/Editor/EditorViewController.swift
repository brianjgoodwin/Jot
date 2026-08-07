//
//  EditorViewController.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class EditorViewController: NSViewController, NSTextViewDelegate, TextSettingsDelegate {
	
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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		textView.delegate = self
		setupTextView()
		setupWordCountToggle()
		loadFontPreferences()
		updateWordCount()
		configureAccessibility()

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

	override func viewWillDisappear() {
		super.viewWillDisappear()
		// Only stop the timers. Do NOT sync textView back into the document
		// here: any close-time save has already flushed via data(ofType:),
		// and after a "Don't Save" close a late sync would resurrect the
		// text the user just discarded.
		documentSyncTimer?.invalidate()
		documentSyncTimer = nil
		wordCountUpdateTimer?.invalidate()
		wordCountUpdateTimer = nil
		visibleRangeStyleTimer?.invalidate()
		visibleRangeStyleTimer = nil
	}

	@objc private func scrollViewDidScroll(_ notification: Notification) {
		guard currentMode == .markdown else { return }
		visibleRangeStyleTimer?.invalidate()
		// All debounce timers here are added in .common mode so they still
		// fire during event tracking (menus, scrollers, resize), which
		// Timer.scheduledTimer's .default-only registration does not (#128).
		let timer = Timer(timeInterval: 0.1, repeats: false) { [weak self] _ in
			guard let self = self,
				  let visibleRange = self.visibleCharacterRange() else { return }
			let font = self.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: self.textView, using: font, range: visibleRange)
		}
		RunLoop.main.add(timer, forMode: .common)
		visibleRangeStyleTimer = timer
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
	
	func updateModeUI() {
		let modeTitle = (currentMode == .markdown) ? "Markdown" : "Plain Text"
		modePopUpButton.selectItem(withTitle: modeTitle)

		NSAccessibility.post(
			element: modePopUpButton as Any,
			notification: .announcementRequested,
			userInfo: [.announcement: "Switched to \(modeTitle) mode"]
		)
	}
	
	// MARK: - Word Count Toggle Setup
	private func setupWordCountToggle() {
		wordCountToggle.state = .on
	}
	
	// MARK: - Word Count
	func updateWordCount() {
		if wordCountToggle.state == .on {
			let stats = TextStatistics(text: textView.string)
			let formattedWordCount = TextStatistics.integerFormatter.string(from: NSNumber(value: stats.wordCount)) ?? ""
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
		updateModeUI()
	}
	
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
	
	// MARK: - Markdown Bold Toggle

	@IBAction func toggleBoldMarkdown(_ sender: Any) {
		guard let textStorage = textView.textStorage else { return }
		let selectedRange = textView.selectedRange()
		let string = textStorage.string
		let nsString = string as NSString

		if selectedRange.length == 0 {
			// No selection: insert **** and place cursor between them
			let insertion = "****"
			textView.insertText(insertion, replacementRange: selectedRange)
			let cursorPosition = selectedRange.location + 2
			textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))
		} else {
			// Check if selection is already wrapped in **
			let hasRoom = selectedRange.location >= 2
				&& NSMaxRange(selectedRange) + 2 <= nsString.length
			let alreadyBold = hasRoom
				&& nsString.substring(with: NSRange(location: selectedRange.location - 2, length: 2)) == "**"
				&& nsString.substring(with: NSRange(location: NSMaxRange(selectedRange), length: 2)) == "**"

			if alreadyBold {
				// Remove the ** markers
				let fullRange = NSRange(
					location: selectedRange.location - 2,
					length: selectedRange.length + 4
				)
				let innerText = nsString.substring(with: selectedRange)
				textView.insertText(innerText, replacementRange: fullRange)
				textView.setSelectedRange(NSRange(location: selectedRange.location - 2, length: selectedRange.length))
			} else {
				// Wrap selection in **
				let selectedText = nsString.substring(with: selectedRange)
				let wrapped = "**\(selectedText)**"
				textView.insertText(wrapped, replacementRange: selectedRange)
				textView.setSelectedRange(NSRange(location: selectedRange.location + 2, length: selectedRange.length))
			}
		}

		if currentMode == .markdown {
			let font = selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			let updatedString = textStorage.string as NSString
			let lineRange = updatedString.lineRange(for: textView.selectedRange())
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: font, range: lineRange)
		}
	}

	// MARK: - Markdown Italic Toggle

	@IBAction func toggleItalicMarkdown(_ sender: Any) {
		guard let textStorage = textView.textStorage else { return }
		let selectedRange = textView.selectedRange()
		let string = textStorage.string
		let nsString = string as NSString

		if selectedRange.length == 0 {
			// No selection: insert ** and place cursor between them
			let insertion = "**"
			textView.insertText(insertion, replacementRange: selectedRange)
			let cursorPosition = selectedRange.location + 1
			textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))
		} else {
			// Check if selection is already wrapped in *
			let hasRoom = selectedRange.location >= 1
				&& NSMaxRange(selectedRange) + 1 <= nsString.length
			let alreadyItalic = hasRoom
				&& nsString.substring(with: NSRange(location: selectedRange.location - 1, length: 1)) == "*"
				&& nsString.substring(with: NSRange(location: NSMaxRange(selectedRange), length: 1)) == "*"

			if alreadyItalic {
				// Remove the * markers
				let fullRange = NSRange(
					location: selectedRange.location - 1,
					length: selectedRange.length + 2
				)
				let innerText = nsString.substring(with: selectedRange)
				textView.insertText(innerText, replacementRange: fullRange)
				textView.setSelectedRange(NSRange(location: selectedRange.location - 1, length: selectedRange.length))
			} else {
				// Wrap selection in *
				let selectedText = nsString.substring(with: selectedRange)
				let wrapped = "*\(selectedText)*"
				textView.insertText(wrapped, replacementRange: selectedRange)
				textView.setSelectedRange(NSRange(location: selectedRange.location + 1, length: selectedRange.length))
			}
		}

		if currentMode == .markdown {
			let font = selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			let updatedString = textStorage.string as NSString
			let lineRange = updatedString.lineRange(for: textView.selectedRange())
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: font, range: lineRange)
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
	
	// NOTE: No saveDocument override here. Save goes up the responder
	// chain to NSDocument, whose machinery flushes the live text view in
	// Document.data(ofType:) -- one save path, one flush point (#118, #125).

	/// Called by Document after File > Revert to Saved rereads the file.
	/// Cancels the pending debounced sync so it can't re-overwrite the
	/// reverted model, then reloads the editor from the document (#119).
	func documentDidRevert(to text: String) {
		documentSyncTimer?.invalidate()
		documentSyncTimer = nil
		// Pre-revert undo actions would replay stale edits against the
		// reverted text
		textView.undoManager?.removeAllActions()
		textView.string = text
		if currentMode == .markdown {
			let font = selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			MarkdownProcessor.applyMarkdownStyling(to: textView, using: font)
		}
		updateWordCount()
		// Setting textView.string doesn't fire textDidChange, so the
		// floating word-count panel needs telling directly
		NotificationCenter.default.post(name: WordCountPanelController.textDidChangeNotification, object: self)
		NSAccessibility.post(
			element: textView as Any,
			notification: .announcementRequested,
			userInfo: [.announcement: "Reverted to last saved version"]
		)
	}

	// MARK: - Text View Setup
	private func setupTextView() {
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

		// Debounce a visible-range restyle so surrounding context catches up.
		// nonisolated(unsafe) is safe here only because NSFont is immutable;
		// don't copy this pattern for mutable reference types.
		nonisolated(unsafe) let sendableFont = font
		visibleRangeStyleTimer?.invalidate()
		let timer = Timer(timeInterval: 0.3, repeats: false) { [weak self] _ in
			guard let self = self, let visibleRange = self.visibleCharacterRange() else { return }
			MarkdownProcessor.applyMarkdownStyling(to: self.textView, using: sendableFont, range: visibleRange)
		}
		RunLoop.main.add(timer, forMode: .common)
		visibleRangeStyleTimer = timer
	}

	// MARK: - Accessibility

	private func configureAccessibility() {
		wordCountToggle.setAccessibilityLabel("Toggle word count display")
		wordCountLabel.setAccessibilityLabel("Word count")
		modePopUpButton.setAccessibilityLabel("Editor mode")
		textView.setAccessibilityLabel("Document editor")
	}
}

// MARK: - NSTextViewDelegate
extension EditorViewController {
	func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
		if selector == #selector(insertTab(_:)) {
			handleTab()
			return true
		}
		if selector == #selector(insertBacktab(_:)) {
			handleBacktab()
			return true
		}
		return false
	}

	// MARK: - Tab / Indent

	private func handleTab() {
		let selectedRange = textView.selectedRange()
		let nsString = textView.string as NSString

		if selectedRange.length == 0 {
			// No selection: insert a tab at the cursor
			textView.insertText("\t", replacementRange: selectedRange)
		} else {
			// Indent all lines in the selection
			let lineRange = nsString.lineRange(for: selectedRange)
			let lines = nsString.substring(with: lineRange)
			var indented = ""
			lines.enumerateLines { line, _ in
				indented += "\t" + line + "\n"
			}
			// Remove trailing newline if the original didn't end with one
			if !lines.hasSuffix("\n") {
				indented = String(indented.dropLast())
			}
			textView.insertText(indented, replacementRange: lineRange)
			textView.setSelectedRange(NSRange(location: lineRange.location, length: (indented as NSString).length))
		}
	}

	private func handleBacktab() {
		let selectedRange = textView.selectedRange()
		let nsString = textView.string as NSString

		if selectedRange.length == 0 {
			// No selection: remove one level of indentation from the current line
			let lineRange = nsString.lineRange(for: selectedRange)
			let line = nsString.substring(with: lineRange)
			if line.hasPrefix("\t") {
				let trimmed = String(line.dropFirst())
				textView.insertText(trimmed, replacementRange: lineRange)
				textView.setSelectedRange(NSRange(location: max(selectedRange.location - 1, lineRange.location), length: 0))
			}
		} else {
			// Outdent all lines in the selection
			let lineRange = nsString.lineRange(for: selectedRange)
			let lines = nsString.substring(with: lineRange)
			var outdented = ""
			lines.enumerateLines { line, _ in
				if line.hasPrefix("\t") {
					outdented += String(line.dropFirst()) + "\n"
				} else {
					outdented += line + "\n"
				}
			}
			// Remove trailing newline if the original didn't end with one
			if !lines.hasSuffix("\n") {
				outdented = String(outdented.dropLast())
			}
			textView.insertText(outdented, replacementRange: lineRange)
			textView.setSelectedRange(NSRange(location: lineRange.location, length: (outdented as NSString).length))
		}
	}

	func textDidChange(_ notification: Notification) {
		guard let textView = notification.object as? NSTextView else { return }

		// Debounce the document text sync to avoid copying the entire string
		// on every keystroke. AppKit's undo manager tracks the actual edits.
		documentSyncTimer?.invalidate()
		let syncTimer = Timer(timeInterval: 0.3, repeats: false) { [weak self] _ in
			guard let self = self,
				  let document = self.view.window?.windowController?.document as? Document else { return }
			document.text = self.textView.string
		}
		RunLoop.main.add(syncTimer, forMode: .common)
		documentSyncTimer = syncTimer

		if currentMode == .markdown {
			styleCurrentLineAndDeferVisible(in: textView)
		}

		wordCountUpdateTimer?.invalidate()
		let wordCountTimer = Timer(timeInterval: 0.5, repeats: false) { [weak self] _ in
			self?.updateWordCount()
		}
		RunLoop.main.add(wordCountTimer, forMode: .common)
		wordCountUpdateTimer = wordCountTimer

		NotificationCenter.default.post(name: WordCountPanelController.textDidChangeNotification, object: self)
	}
}

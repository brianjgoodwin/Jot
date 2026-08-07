//
//  EditorViewController.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa
import os.signpost

class EditorViewController: NSViewController, NSTextViewDelegate, TextSettingsDelegate {
	
	@IBOutlet var textView: NSTextView!
	@IBOutlet var wordCountLabel: NSTextField!
	@IBOutlet var wordCountToggle: NSSwitch!
	@IBOutlet weak var modePopUpButton: NSPopUpButton!
	
	private var wordCountUpdateTimer: Timer?
	private var documentSyncTimer: Timer?
	private var visibleRangeStyleTimer: Timer?

	// Characters styled since the last edit. Scroll passes consult this so
	// scrolling over already-styled text does no work (#139). Edits reset it
	// because an edit shifts or invalidates everything after itself; font
	// changes reset it because recorded styling carries the old font.
	private var styledCharacters = IndexSet()
	
	var selectedFont: NSFont?
	var selectedFontSize: CGFloat?
	var currentMode: EditorMode = .plainText
	
	override func viewDidLoad() {
		super.viewDidLoad()
		textView.delegate = self
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
			// Styling is a pure function of the text: if scrolling exposed
			// nothing new since the last edit, there is nothing to do (#139)
			if let intRange = Range(visibleRange),
			   self.styledCharacters.contains(integersIn: intRange) { return }
			self.applyStyling(range: visibleRange)
		}
		RunLoop.main.add(timer, forMode: .common)
		visibleRangeStyleTimer = timer
	}

	/// Runs a styling pass and records the covered characters, so scroll
	/// passes over the same text can be skipped until the next edit.
	private func applyStyling(range: NSRange? = nil) {
		let font = selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		MarkdownProcessor.applyMarkdownStyling(to: textView, using: font, range: range)
		let recorded = range ?? NSRange(location: 0, length: (textView.string as NSString).length)
		if let intRange = Range(recorded) {
			styledCharacters.insert(integersIn: intRange)
		}
	}
	
	// MARK: - Text Settings Delegate
	func didSelectFont(_ font: NSFont) {
		let fontConfig = FontConfiguration.shared
		fontConfig.applyFont(font)
		selectedFont = fontConfig.resolvedFont()
		textView.font = selectedFont
		styledCharacters.removeAll()
	}

	func didSelectFontSize(_ fontSize: CGFloat) {
		let fontConfig = FontConfiguration.shared
		fontConfig.applySize(fontSize)
		selectedFontSize = fontSize
		selectedFont = fontConfig.resolvedFont()
		textView.font = selectedFont
		styledCharacters.removeAll()
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
			applyStyling()
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
			let signpostID = OSSignpostID(log: PerformanceLog.log)
			os_signpost(.begin, log: PerformanceLog.log, name: "Word Count", signpostID: signpostID)
			defer { os_signpost(.end, log: PerformanceLog.log, name: "Word Count", signpostID: signpostID) }
			// Count words only — the label shows one number, so building
			// all seven statistics here was wasted work (#138)
			let count = TextStatistics.wordCount(of: textView.string)
			let formattedWordCount = TextStatistics.integerFormatter.string(from: NSNumber(value: count)) ?? ""
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
			applyStyling()
		} else {
			currentMode = .plainText
			removeMarkdownStyling()
		}
		updateModeUI()
	}
	
	func removeMarkdownStyling() {
		guard let textStorage = textView.textStorage else { return }
		styledCharacters.removeAll()

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
	
	// MARK: - Markdown Bold / Italic Toggles

	@IBAction func toggleBoldMarkdown(_ sender: Any) {
		toggleAsteriskMarkers(markerLength: 2)
		restyleSelectionLineIfMarkdown()
	}

	@IBAction func toggleItalicMarkdown(_ sender: Any) {
		toggleAsteriskMarkers(markerLength: 1)
		restyleSelectionLineIfMarkdown()
	}

	/// Adds or removes a marker of `markerLength` asterisks on each side of
	/// the selection. Counts the existing contiguous asterisk runs around the
	/// selection instead of testing single characters, so toggling italic on
	/// `**bold**` produces `***both***` rather than corrupting the bold
	/// markers, and a selection that includes the markers is normalized
	/// instead of double-wrapped (#127).
	private func toggleAsteriskMarkers(markerLength: Int) {
		let selectedRange = textView.selectedRange()
		let nsString = textView.string as NSString
		let asterisk = "*".utf16.first!

		if selectedRange.length == 0 {
			// No selection: insert an empty marker pair, cursor in the middle
			let marker = String(repeating: "*", count: markerLength)
			textView.insertText(marker + marker, replacementRange: selectedRange)
			textView.setSelectedRange(NSRange(location: selectedRange.location + markerLength, length: 0))
			return
		}

		// Normalize the selection: step its edges past any asterisks so a
		// selection that includes the markers behaves like one that doesn't
		var innerStart = selectedRange.location
		var innerEnd = NSMaxRange(selectedRange)
		while innerStart < innerEnd && nsString.character(at: innerStart) == asterisk { innerStart += 1 }
		while innerEnd > innerStart && nsString.character(at: innerEnd - 1) == asterisk { innerEnd -= 1 }

		if innerStart == innerEnd {
			// Selection was nothing but asterisks -- treat it as opaque text
			let wrapped = String(repeating: "*", count: markerLength)
				+ nsString.substring(with: selectedRange)
				+ String(repeating: "*", count: markerLength)
			textView.insertText(wrapped, replacementRange: selectedRange)
			textView.setSelectedRange(NSRange(location: selectedRange.location + markerLength, length: selectedRange.length))
			return
		}

		// Count the contiguous asterisk run on each side of the inner text,
		// capped at 3 (***, the longest meaningful markdown marker)
		var runBefore = 0
		while runBefore < 3 && innerStart - runBefore > 0
			&& nsString.character(at: innerStart - runBefore - 1) == asterisk { runBefore += 1 }
		var runAfter = 0
		while runAfter < 3 && innerEnd + runAfter < nsString.length
			&& nsString.character(at: innerEnd + runAfter) == asterisk { runAfter += 1 }

		// Only a symmetric run is a marker; extra asterisks on one side stay
		// as literal text
		let currentCount = min(runBefore, runAfter)

		// 1 or 3 asterisks contain italic; 2 or 3 contain bold
		let markerPresent: Bool
		if markerLength == 1 {
			markerPresent = currentCount == 1 || currentCount == 3
		} else {
			markerPresent = currentCount >= 2
		}
		let newCount = markerPresent ? currentCount - markerLength : currentCount + markerLength

		let innerText = nsString.substring(with: NSRange(location: innerStart, length: innerEnd - innerStart))
		let newMarker = String(repeating: "*", count: newCount)
		let replaceRange = NSRange(location: innerStart - currentCount,
								   length: currentCount + (innerEnd - innerStart) + currentCount)
		textView.insertText(newMarker + innerText + newMarker, replacementRange: replaceRange)
		textView.setSelectedRange(NSRange(location: innerStart - currentCount + newCount,
										  length: innerEnd - innerStart))
	}

	private func restyleSelectionLineIfMarkdown() {
		guard currentMode == .markdown else { return }
		let lineRange = (textView.string as NSString).lineRange(for: textView.selectedRange())
		applyStyling(range: lineRange)
	}

	// MARK: - Checklist Toggle (#146)

	/// Format > Toggle Checklist: flips `[ ]`/`[x]` on every checklist line
	/// the selection touches. Lines without a checkbox are left alone. Like
	/// the bold/italic commands, this works in both modes — it edits
	/// characters; only the styling is markdown-mode dependent.
	@IBAction func toggleChecklistItem(_ sender: Any) {
		let flips = checklistStateFlips()
		guard !flips.isEmpty else { return }

		let savedSelection = textView.selectedRange()
		for (stateRange, replacement) in flips {
			textView.insertText(replacement, replacementRange: stateRange)
		}
		// Every replacement is one character for one character, so the
		// original selection is still valid.
		textView.setSelectedRange(savedSelection)
		restyleSelectionLineIfMarkdown()
	}

	/// The (range, replacement) pairs that flip the checkbox state character
	/// on each checklist line the selection touches. Computed from one text
	/// snapshot; all replacements are same-length, so applying them in order
	/// leaves the remaining ranges valid.
	private func checklistStateFlips() -> [(NSRange, String)] {
		let nsString = textView.string as NSString
		let lineSpan = nsString.lineRange(for: textView.selectedRange())
		var flips: [(NSRange, String)] = []
		nsString.enumerateSubstrings(in: lineSpan, options: .byLines) { line, lineRange, _, _ in
			guard let line = line,
				  let marker = ListMarker(line: line),
				  let stateOffset = marker.checkboxStateOffset else { return }
			let stateRange = NSRange(location: lineRange.location + stateOffset, length: 1)
			let flipped = nsString.substring(with: stateRange) == " " ? "x" : " "
			flips.append((stateRange, flipped))
		}
		return flips
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

	/// The single place that assigns textView.string. Setting the string
	/// does not fire textDidChange, so the styled-range reset (#139) and
	/// word-count refresh must happen here — funneled so a new call site
	/// can't forget them.
	func loadText(_ text: String) {
		textView.string = text
		styledCharacters.removeAll()
		if currentMode == .markdown {
			applyStyling()
		}
		updateWordCount()
	}

	/// Called by Document after File > Revert to Saved rereads the file.
	/// Cancels the pending debounced sync so it can't re-overwrite the
	/// reverted model, then reloads the editor from the document (#119).
	func documentDidRevert(to text: String) {
		documentSyncTimer?.invalidate()
		documentSyncTimer = nil
		// Pre-revert undo actions would replay stale edits against the
		// reverted text
		textView.undoManager?.removeAllActions()
		loadText(text)
		// Setting textView.string doesn't fire textDidChange, so the
		// floating word-count panel needs telling directly
		NotificationCenter.default.post(name: WordCountPanelController.textDidChangeNotification, object: self)
		NSAccessibility.post(
			element: textView as Any,
			notification: .announcementRequested,
			userInfo: [.announcement: "Reverted to last saved version"]
		)
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

		// Immediately style the line the user is editing
		let currentLineRange = (textView.string as NSString).lineRange(for: selectedRange)
		applyStyling(range: currentLineRange)

		// Debounce a visible-range restyle so surrounding context catches up
		visibleRangeStyleTimer?.invalidate()
		let timer = Timer(timeInterval: 0.3, repeats: false) { [weak self] _ in
			guard let self = self, let visibleRange = self.visibleCharacterRange() else { return }
			self.applyStyling(range: visibleRange)
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
		if selector == #selector(insertNewline(_:)) {
			return continueListOnReturn()
		}
		return false
	}

	// MARK: - List continuation (#143)

	/// Pressing Return inside a markdown list item starts the next line with
	/// the same marker (ordered numbers increment, checkboxes reset to
	/// unchecked); Return on an empty item deletes its marker instead — the
	/// standard way out of a list. Markdown mode only: plain-text mode stays
	/// plain. Returns false to let the text view insert a normal newline.
	private func continueListOnReturn() -> Bool {
		guard currentMode == .markdown else { return false }
		let selectedRange = textView.selectedRange()
		guard selectedRange.length == 0 else { return false }

		switch ListMarker.returnAction(in: textView.string, caret: selectedRange.location) {
		case .continueList(let insert):
			textView.insertText(insert, replacementRange: selectedRange)
			return true
		case .endList(let removeRange):
			textView.insertText("", replacementRange: removeRange)
			return true
		case .none:
			return false
		}
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
			let signpostID = OSSignpostID(log: PerformanceLog.log)
			os_signpost(.begin, log: PerformanceLog.log, name: "Document Sync", signpostID: signpostID)
			defer { os_signpost(.end, log: PerformanceLog.log, name: "Document Sync", signpostID: signpostID) }
			document.text = self.textView.string
		}
		RunLoop.main.add(syncTimer, forMode: .common)
		documentSyncTimer = syncTimer

		// An edit shifts or invalidates everything after itself — forget
		// what was styled before restyling anything (#139)
		styledCharacters.removeAll()
		if currentMode == .markdown {
			styleCurrentLineAndDeferVisible(in: textView)
		}

		// No timer when the toggle is off — the label already says "Off",
		// so the old fire path was scheduled work with nothing to do (#138)
		if wordCountToggle.state == .on {
			wordCountUpdateTimer?.invalidate()
			let wordCountTimer = Timer(timeInterval: 0.5, repeats: false) { [weak self] _ in
				self?.updateWordCount()
			}
			RunLoop.main.add(wordCountTimer, forMode: .common)
			wordCountUpdateTimer = wordCountTimer
		}

		NotificationCenter.default.post(name: WordCountPanelController.textDidChangeNotification, object: self)
	}
}

// MARK: - Menu validation
extension EditorViewController: NSMenuItemValidation {
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(toggleChecklistItem(_:)) {
			// Only meaningful when the selection touches a checklist line
			return !checklistStateFlips().isEmpty
		}
		// Every other action this controller exposes stays enabled, which
		// is what AppKit did before this method existed.
		return true
	}
}

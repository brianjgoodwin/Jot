//
//  AppDelegate.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
	
	var aboutWindowController: AboutWindowControllerProgrammatic?
	var settingsPanelController: SettingsPanelController?
	var wordCountPanelController: WordCountPanelController?
	var helpWindowController: HelpWindowController?
	var previewWindowController: MarkdownPreviewWindowController?
	var acknowledgementsWindowController: AcknowledgementsWindowController?
	
	@IBAction func showAboutWindow(_ sender: Any) {
		if aboutWindowController == nil {
			aboutWindowController = AboutWindowControllerProgrammatic()
		}
		aboutWindowController?.showWindow(sender)
	}

	@IBAction func showHelpWindow(_ sender: Any) {
		if helpWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			helpWindowController = storyboard.instantiateController(withIdentifier: "HelpWindowController") as? HelpWindowController
		}
		
		helpWindowController?.showWindow(sender)
	}

	@IBAction func showMarkdownPreview(_ sender: Any) {
		if previewWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			previewWindowController = storyboard.instantiateController(withIdentifier: "MarkdownPreviewWindowController") as? MarkdownPreviewWindowController
		}

		if let vc = NSApp.mainWindow?.contentViewController as? EditorViewController {
			previewWindowController?.loadMarkdown(markdown: vc.textView.string)
		}
		previewWindowController?.showWindow(self)
	}
	
	@IBAction func showSettingsWindow(_ sender: Any) {
		if settingsPanelController == nil {
			settingsPanelController = SettingsPanelController()
		}
		// No per-window wiring: font changes broadcast via
		// FontConfiguration.didChangeNotification to every editor (#124)
		settingsPanelController?.showWindow(sender)
	}
	
	/// Show/Hide toggle: the panel is built with becomesKeyOnlyIfNeeded and
	/// holds only non-selectable labels, so nothing in it ever needs key
	/// input and it does not take key status in normal use — which leaves
	/// Cmd-W acting on the document window behind it. Without this toggle a
	/// keyboard-only user can summon a floating panel and then has only the
	/// mouse to dismiss it (#152). The menu title tracks state in
	/// validateMenuItem.
	@IBAction func showWordCountWindow(_ sender: Any) {
		if wordCountPanelController == nil {
			wordCountPanelController = WordCountPanelController()
		}
		if wordCountPanelController?.window?.isVisible == true {
			wordCountPanelController?.window?.orderOut(sender)
		} else {
			wordCountPanelController?.showWindow(sender)
		}
	}
	
	/// View > Show/Hide Line Numbers. Lives here rather than on the editor
	/// because it only writes the shared preference — every open editor
	/// observes that and updates itself (#106), and the command stays
	/// meaningful with no document window open. Same Show/Hide title
	/// pattern as Word Count (#152), handled in validateMenuItem.
	@IBAction func toggleLineNumbers(_ sender: Any) {
		PreferencesManager.shared.showLineNumbers.toggle()
	}

	@IBAction func openHelpWebsite(_ sender: Any) {
		if let url = URL(string: "https://github.com/brianjgoodwin/Jot/wiki/Feedback-and-Support") {
			NSWorkspace.shared.open(url)
		}
	}
	
	@IBAction func openPrivacyWebsite(_ sender: Any) {
		if let url = URL(string: "https://github.com/brianjgoodwin/Jot/wiki/Privacy") {
			NSWorkspace.shared.open(url)
		}
	}
	
	@IBAction func openAcknowledgements(_ sender: Any) {
		if acknowledgementsWindowController == nil {
			acknowledgementsWindowController = AcknowledgementsWindowController()
		}
		acknowledgementsWindowController?.showWindow(sender)
	}

	
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(showWordCountWindow(_:)) {
			menuItem.title = (wordCountPanelController?.window?.isVisible == true)
				? "Hide Word Count"
				: "Show Word Count"
		}
		if menuItem.action == #selector(toggleLineNumbers(_:)) {
			menuItem.title = PreferencesManager.shared.showLineNumbers
				? "Hide Line Numbers"
				: "Show Line Numbers"
		}
		return true
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// One-time recovery of drafts left by the pre-1.0.9 hand-rolled
		// crash-recovery system. NSDocument autosave owns crash recovery
		// now (#121), so there is no terminate-time state saving.
		Document.migrateLegacyUnsavedStates()
	}

	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
	
	// NOTE: Print… targets First Responder in the storyboard, so
	// NSDocument's printDocument: handles it via
	// Document.printOperation(withSettings:). A parallel print path here
	// mutated the shared NSPrintInfo and was reachable with no document
	// open (#125).
}

//
//  AppDelegate.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa
import Down

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	
	var aboutWindowController: AboutWindowControllerProgrammatic?
	var settingsPanelController: SettingsPanelController?
	var wordCountPanelController: WordCountPanelController?
	var helpWindowController: HelpWindowController?
	var previewWindowController: MarkdownPreviewWindowController?
	
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
		if let mainViewController = NSApplication.shared.mainWindow?.contentViewController as? EditorViewController {
			settingsPanelController?.delegate = mainViewController
		}
		settingsPanelController?.showWindow(sender)
	}
	
	@IBAction func showWordCountWindow(_ sender: Any) {
		if wordCountPanelController == nil {
			wordCountPanelController = WordCountPanelController()
		}
		wordCountPanelController?.showWindow(sender)
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
		guard let acknowledgementsURL = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt") else { return }
		NSWorkspace.shared.open(acknowledgementsURL)
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
	
	func getCurrentViewController() -> EditorViewController? {
		return NSApplication.shared.mainWindow?.contentViewController as? EditorViewController
	}

	// NOTE: Print… targets First Responder in the storyboard, so
	// NSDocument's printDocument: handles it via
	// Document.printOperation(withSettings:). A parallel print path here
	// mutated the shared NSPrintInfo and was reachable with no document
	// open (#125).
}

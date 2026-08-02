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

		if let vc = NSApp.mainWindow?.contentViewController as? ViewController {
			previewWindowController?.loadMarkdown(markdown: vc.textView.string)
		}
		previewWindowController?.showWindow(self)
	}
	
	@IBAction func showSettingsWindow(_ sender: Any) {
		if settingsPanelController == nil {
			settingsPanelController = SettingsPanelController()
		}
		if let mainViewController = NSApplication.shared.mainWindow?.contentViewController as? ViewController {
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
		ProcessInfo.processInfo.disableSuddenTermination()
		Document.restoreUnsavedStates()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		for document in NSDocumentController.shared.documents {
			guard let doc = document as? Document, doc.isDocumentEdited else { continue }
			// Flush any pending debounced text sync before saving state
			if let vc = doc.windowControllers.first?.contentViewController as? ViewController {
				vc.flushDocumentSync()
			}
			doc.saveUnsavedState()
		}
	}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
	
	func getCurrentViewController() -> ViewController? {
		return NSApplication.shared.mainWindow?.contentViewController as? ViewController
	}
	
	// MARK: - Printing
	@IBAction func printDocument(_ sender: Any?) {
		if let viewController = NSApp.mainWindow?.contentViewController as? ViewController,
		   let document = viewController.view.window?.windowController?.document as? Document {
			let printInfo = NSPrintInfo.shared
			printInfo.jobDisposition = .spool
			let printOperation = NSPrintOperation(view: document.printableView(), printInfo: printInfo)
			printOperation.run()
		}
	}
	
}

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
	
	var aboutWindowController: AboutWindowController?
	var settingsWindowController: SettingsWindowController?
	var wordCountWindowController: WordCountWindowController?
	var helpWindowController: HelpWindowController?
	var previewWindowController: MarkdownPreviewWindowController?
	
	@IBAction func showAboutWindow(_ sender: Any) {
		if aboutWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			aboutWindowController = storyboard.instantiateController(withIdentifier: "AboutWindowController") as? AboutWindowController
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
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		if let previewWindowController = storyboard.instantiateController(withIdentifier: "MarkdownPreviewWindowController") as? MarkdownPreviewWindowController,
		   let ViewController = NSApp.mainWindow?.contentViewController as? ViewController {
			
			let markdownString = ViewController.textView.string
			previewWindowController.loadMarkdown(markdown: markdownString)
			previewWindowController.showWindow(self)
		}
	}
	
	@IBAction func showSettingsWindow(_ sender: Any) {
		if settingsWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			settingsWindowController = storyboard.instantiateController(withIdentifier: "SettingsWindowController") as? SettingsWindowController
		}
		
		if let mainViewController = NSApplication.shared.mainWindow?.contentViewController as? ViewController,
		   let settingsViewController = settingsWindowController?.contentViewController as? SettingsViewController {
			settingsViewController.delegate = mainViewController
			settingsViewController.selectedFontSize = mainViewController.selectedFontSize
			settingsViewController.selectedFontName = mainViewController.selectedFont?.fontName
		}
		
		settingsWindowController?.showWindow(self)
	}
	
	@IBAction func showWordCountWindow(_ sender: Any) {
		if wordCountWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			wordCountWindowController = storyboard.instantiateController(withIdentifier: "WordCountWindowController") as? WordCountWindowController
		}
		
		if let viewController = NSApplication.shared.mainWindow?.contentViewController as? ViewController,
		   let wordCountViewController = wordCountWindowController?.contentViewController as? WordCountViewController {
			let currentText = viewController.textView.string
			wordCountViewController.updateStatistics(withText: currentText)
		}
		
		wordCountWindowController?.showWindow(self)
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

	
	func applicationDidFinishLaunching(_ aNotification: Notification) {}

	func applicationWillTerminate(_ aNotification: Notification) {}
	
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

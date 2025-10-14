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
		// Check if the window controller already exists
		if aboutWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			aboutWindowController = storyboard.instantiateController(withIdentifier: "AboutWindowController") as? AboutWindowController
		}

		// Show the About window
		aboutWindowController?.showWindow(sender)
	}
	
	// Help Window
	@IBAction func showHelpWindow(_ sender: Any) {
		// Check if the window controller already exists
		if helpWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			helpWindowController = storyboard.instantiateController(withIdentifier: "HelpWindowController") as? HelpWindowController
		}

		// Show the Help window
		helpWindowController?.showWindow(sender)
	}
	
	// Show Markdown Preview window
	@IBAction func showMarkdownPreview(_ sender: Any) {
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		if let previewWindowController = storyboard.instantiateController(withIdentifier: "MarkdownPreviewWindowController") as? MarkdownPreviewWindowController,
		   let ViewController = NSApp.mainWindow?.contentViewController as? ViewController {
			
			let markdownString = ViewController.textView.string // Fetch the Markdown content
			previewWindowController.loadMarkdown(markdown: markdownString)
			previewWindowController.showWindow(self)
		}
	}
	
	@IBAction func showSettingsWindow(_ sender: Any) {
		// Check if the window controller already exists
		if settingsWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			settingsWindowController = storyboard.instantiateController(withIdentifier: "SettingsWindowController") as? SettingsWindowController
		}
		
		if let mainViewController = NSApplication.shared.mainWindow?.contentViewController as? ViewController,
		   let settingsViewController = settingsWindowController?.contentViewController as? SettingsViewController {
			settingsViewController.delegate = mainViewController
			settingsViewController.selectedFontSize = mainViewController.selectedFontSize  // Pass the current selected font size
			settingsViewController.selectedFontName = mainViewController.selectedFont?.fontName  // Pass the current selected font name
		}
		
		settingsWindowController?.showWindow(self)
	}
	
	@IBAction func showWordCountWindow(_ sender: Any) {
		// Check if the window controller already exists
		if wordCountWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			wordCountWindowController = storyboard.instantiateController(withIdentifier: "WordCountWindowController") as? WordCountWindowController
		}
		
		// Set the text content for WordCountViewController from the NSTextView
		if let viewController = NSApplication.shared.mainWindow?.contentViewController as? ViewController,
		   let wordCountViewController = wordCountWindowController?.contentViewController as? WordCountViewController {
			let currentText = viewController.textView.string
			wordCountViewController.updateStatistics(withText: currentText)
		}
		
		// Show the WordCount window
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
		guard let acknowledgementsURL = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt") else {
			print("Acknowledgements file not found")
			return
		}

		NSWorkspace.shared.open(acknowledgementsURL)
	}

	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		logToFile("Test log message")
		logToFile("[\(Date())] 📝 App did finish launching")
		let fm = FileManager.default
		if let supportFolder = try? fm.url(for: .applicationSupportDirectory,
										   in: .userDomainMask,
										   appropriateFor: nil,
										   create: true) {
			let unsavedFolder = supportFolder.appendingPathComponent("Jot/UnsavedStates", isDirectory: true)
			if fm.fileExists(atPath: unsavedFolder.path) {
				do {
					let files = try fm.contentsOfDirectory(at: unsavedFolder, includingPropertiesForKeys: nil, options: [])
					for fileURL in files {
						// Validate file size before attempting to restore
						let attributes = try? fm.attributesOfItem(atPath: fileURL.path)
						if let fileSize = attributes?[.size] as? Int64 {
							if fileSize > 100 * 1024 * 1024 { // 100MB
								logToFile("⚠️ Skipping unsaved state file (too large): \(fileURL.path)")
								continue
							}
						}

						// For each unsaved state file, open a new document and restore state.
						let newDoc = Document()
						if let restoredText = try? String(contentsOf: fileURL, encoding: .utf8) {
							newDoc.text = restoredText
							NSDocumentController.shared.addDocument(newDoc)
							newDoc.makeWindowControllers()
							newDoc.showWindows()
							logToFile("✅ Restored unsaved state from \(fileURL.path)")
							// Remove the unsaved state file after restoration.
							try? fm.removeItem(at: fileURL)
						} else {
							logToFile("❌ Failed to decode unsaved state file: \(fileURL.path)")
						}
					}
				} catch {
					logToFile("❌ Error handling unsaved state files: \(error)")
				}
			}
		}
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		logToFile("[\(Date())] 📝 App will terminate; saving unsaved states")
		for document in NSDocumentController.shared.documents {
				if let doc = document as? Document, doc.isDocumentEdited {
					// Log metadata only - no document content
					logToFile("📄 Document unsaved changes detected. Text length: \(doc.text.count)")

					// Now save the unsaved state
					doc.saveUnsavedState()
				}
			}
		}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
	
	func getCurrentViewController() -> ViewController? {
		return NSApplication.shared.mainWindow?.contentViewController as? ViewController
	}
	
		// MARK: Printing
		@IBAction func printDocument(_ sender: Any?) {
			if let viewController = NSApp.mainWindow?.contentViewController as? ViewController,
			   let document = viewController.view.window?.windowController?.document as? Document {
				let printInfo = NSPrintInfo.shared
				printInfo.jobDisposition = .spool
				let printOperation = NSPrintOperation(view: document.printableView(), printInfo: printInfo)
				printOperation.run()
			}
		}// End Printing
	
}

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
		aboutWindowController!.showWindow(sender)
	}
	
	// Help Window
	@IBAction func showHelpWindow(_ sender: Any) {
		// Check if the window controller already exists
		if helpWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			helpWindowController = storyboard.instantiateController(withIdentifier: "HelpWindowController") as? HelpWindowController
		}
		
		// Show the Help window
		helpWindowController!.showWindow(sender)
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
		
		// Set the text content for WordCountViewController
		if let wordCountViewController = wordCountWindowController?.contentViewController as? WordCountViewController,
		   let document = NSApplication.shared.mainWindow?.windowController?.document as? Document {
			wordCountViewController.textContent = document.text
		}

		// Show the WordCount window
		wordCountWindowController?.showWindow(self)
	}

	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
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




//import Cocoa
//import SwiftUI
//
//@main
//class AppDelegate: NSObject, NSApplicationDelegate {
//	var window: NSWindow!
//	var aboutWindow: NSWindow?
//	var settingsWindowController: NSWindowController?
//	
//	func applicationDidFinishLaunching(_ aNotification: Notification) {
//		// Initialize your application here
//	}
//	
//	func applicationWillTerminate(_ aNotification: Notification) {
//		// Perform cleanup and tear down your application
//	}
//	
//	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
//		return true
//	}
//	
//	// MARK: Printing
//	@IBAction func printDocument(_ sender: Any?) {
//		if let viewController = NSApp.mainWindow?.contentViewController as? ViewController,
//		   let document = viewController.view.window?.windowController?.document as? Document {
//			let printInfo = NSPrintInfo.shared
//			printInfo.jobDisposition = .spool
//			let printOperation = NSPrintOperation(view: document.printableView(), printInfo: printInfo)
//			printOperation.run()
//		}
//	}// End Printing
//	
//	//	MARK: - About Window
//	@objc func showAboutWindow(_ sender: Any?) {
//		if aboutWindow == nil {
//			let storyboard = NSStoryboard(name: NSStoryboard.Name("AboutWindow"), bundle: nil)
//			if let aboutViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("AboutViewController")) as? NSViewController {
//				aboutWindow = NSWindow(contentViewController: aboutViewController)
//				aboutWindow?.title = "About Jot"
//				aboutWindow?.styleMask = [.titled, .closable]
//				aboutWindow?.center()
//				aboutWindow?.setIsVisible(true)
//			}
//		} else {
//			aboutWindow?.makeKeyAndOrderFront(self)
//		}
//	}
//	
//	@objc func aboutWindowDidClose(_ notification: Notification) {
//		if aboutWindow != nil {
//			NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: aboutWindow)
//			aboutWindow = nil
//		}
//	}
//	
//	@IBAction func showAbout(_ sender: Any?) {
//		showAboutWindow(sender)
//	}// End About Window
//
//	// MARK: Settings window
//	@IBAction func openSettingsWindow(_ sender: Any) {
//		if settingsWindowController == nil {
//			let storyboard = NSStoryboard(name: "Main", bundle: nil) // Replace "Main" with your storyboard name if different
//			settingsWindowController = storyboard.instantiateController(withIdentifier: "SettingsWindowController") as? NSWindowController
//		}
//		
//		settingsWindowController?.showWindow(nil)
//	}// End Settings window
//	
//	// MARK: Help menu link to website
//	@IBAction func OpenWebsite(_ sender: Any) {
//		print("OpenWebsite Menu clicked")
//		// Define the URL you want to open
//		if let url = URL(string: "https://example.com") {
//			// Use NSWorkspace to open the URL
//			if NSWorkspace.shared.open(url) {
//				print("URL opened successfully.")
//			} else {
//				print("Failed to open URL.")
//			}
//		} else {
//			print("Invalid URL.")
//		}
//	}// End open website
//		
//}// end AppDelegate

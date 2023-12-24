//
//  AppDelegate.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	var window: NSWindow!
	var aboutWindow: NSWindow?
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Initialize your application here
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		// Perform cleanup and tear down your application
	}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
	
	@IBAction func printDocument(_ sender: Any?) {
		if let viewController = NSApp.mainWindow?.contentViewController as? ViewController,
		   let document = viewController.view.window?.windowController?.document as? Document {
			let printInfo = NSPrintInfo.shared
			printInfo.jobDisposition = .spool
			let printOperation = NSPrintOperation(view: document.printableView(), printInfo: printInfo)
			printOperation.run()
		}
	}
	
	//	MARK: - About Window
	@objc func showAboutWindow(_ sender: Any?) {
		if aboutWindow == nil {
			let storyboard = NSStoryboard(name: NSStoryboard.Name("AboutWindow"), bundle: nil)
			if let aboutViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("AboutViewController")) as? NSViewController {
				aboutWindow = NSWindow(contentViewController: aboutViewController)
				aboutWindow?.title = "About Jot"
				aboutWindow?.styleMask = [.titled, .closable]
				aboutWindow?.center()
				aboutWindow?.setIsVisible(true)
			}
		} else {
			aboutWindow?.makeKeyAndOrderFront(self)
		}
	}
	
	@objc func aboutWindowDidClose(_ notification: Notification) {
		if aboutWindow != nil {
			NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: aboutWindow)
			aboutWindow = nil
		}
	}
	
	@IBAction func showAbout(_ sender: Any?) {
		showAboutWindow(sender)
	}
	// End About Window
	

	
	@IBAction func OpenWebsite(_ sender: Any) {
		print("OpenWebsite Menu clicked")
		// Define the URL you want to open
		if let url = URL(string: "https://example.com") {
			// Use NSWorkspace to open the URL
			if NSWorkspace.shared.open(url) {
				print("URL opened successfully.")
			} else {
				print("Failed to open URL.")
			}
		} else {
			print("Invalid URL.")
		}
	}
		
}

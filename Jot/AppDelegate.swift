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
	
	@objc func showAboutWindow(_ sender: Any?) {
		if aboutWindow == nil {
			let contentView = AboutView() // Create your custom SwiftUI AboutView
			
			// Create and configure the About window
			aboutWindow = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
				styleMask: [.titled, .closable],
				backing: .buffered,
				defer: false
			)
			
			aboutWindow?.center()
			aboutWindow?.setIsVisible(true)
			aboutWindow?.contentView = NSHostingView(rootView: contentView)
			
			// Add an observer for the window close notification
			NotificationCenter.default.addObserver(self, selector: #selector(aboutWindowDidClose(_:)), name: NSWindow.willCloseNotification, object: aboutWindow)
		} else {
			aboutWindow?.makeKeyAndOrderFront(self) // Bring the About window to the front
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
}

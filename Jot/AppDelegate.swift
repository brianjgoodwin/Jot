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
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
	
	@objc func showAboutWindow(_ sender: Any?) {
		let contentView = AboutView() // Create your custom SwiftUI AboutView
		window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.center()
		window.setIsVisible(true)
		window.contentView = NSHostingView(rootView: contentView)
		
	}
	
	@IBAction func showAbout(_ sender: Any?) {
		showAboutWindow(sender)
	}
	
	
}


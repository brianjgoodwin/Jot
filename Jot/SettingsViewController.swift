//
//  SettingsViewController.swift
//  Jot
//
//  Created by Brian on 12/25/23.
//

import Cocoa

class SettingsViewController: NSViewController {
	
	@IBOutlet weak var fontPopUpButton: NSPopUpButton!
	
	@IBOutlet weak var fontSizePopUpButton: NSPopUpButton!

	override func viewDidLoad() {
		super.viewDidLoad()
		setupFontPopUpButton()
	}
	
	func setupFontPopUpButton() {
		// Remove all existing items
		fontPopUpButton.removeAllItems()
		
		// Define the titles and fonts for your items
		let fonts: [(title: String, font: NSFont)] = [
			("System Default", NSFont.systemFont(ofSize: NSFont.systemFontSize)),
			("System Mono", NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)),
			("Serif", NSFont(name: "New York", size: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize))
		]
		
		// Create and add menu items
		for (title, font) in fonts {
			let menuItem = NSMenuItem()
			menuItem.title = title
			menuItem.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])
			menuItem.action = #selector(changeFont(_:))
			menuItem.target = self  // Don't forget to set the target to self
			fontPopUpButton.menu?.addItem(menuItem)
		}
	}
	
	@IBAction func fontSizeChanged(_ sender: NSPopUpButton) {
		let selectedFontSize = sender.selectedItem?.title ?? "12"
		saveFontSizePreference(selectedFontSize)
		applyFontSizePreference(selectedFontSize)
	}
	
	func saveFontSizePreference(_ fontSize: String) {
		UserDefaults.standard.set(fontSize, forKey: "DefaultFontSize")
	}
	
	func applyFontSizePreference(_ fontSize: String) {
		guard let size = Float(fontSize) else { return }
		let newFont = NSFont.systemFont(ofSize: CGFloat(size)) // Adjust as needed for the user's preferred font
		// Update your text views or other UI elements with the new font
	}

	
	@objc func changeFont(_ sender: NSMenuItem) {
		let userDefaults = UserDefaults.standard

		switch sender.title {
		case "System Default":
			userDefaults.set("SystemDefault", forKey: "SelectedFont")
		case "System Mono":
			userDefaults.set("SystemMono", forKey: "SelectedFont")
		case "Serif":
			userDefaults.set("Serif", forKey: "SelectedFont")
		default:
			break
		}
		
		// Notify any interested parts of your app that the font setting has changed
		NotificationCenter.default.post(name: Notification.Name("FontSettingChanged"), object: nil)
	}

}

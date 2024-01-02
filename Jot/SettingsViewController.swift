//
//  SettingsViewController.swift
//  Jot
//
//  Created by Brian on 12/25/23.
//

import Cocoa

class SettingsViewController: NSViewController {
	// MARK: - Outlets
	@IBOutlet weak var fontPopUpButton: NSPopUpButton!
	@IBOutlet weak var fontSizePopUpButton: NSPopUpButton!

	// MARK: - View Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupFontPopUpButton()
		setupFontSizePopUpButton()  // Add this line
		// Consider adding setup for fontSizePopUpButton if needed
	}
	
	// MARK: - Setup Functions
	/// Sets up the font selection popup button with available fonts.
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
			menuItem.target = self  // Ensures the changeFont(_:) action is called on this instance
			fontPopUpButton.menu?.addItem(menuItem)
		}
	}
	
	func setupFontSizePopUpButton() {
		fontSizePopUpButton.removeAllItems()
		
		// Define the range and step for font sizes
		let fontSizeRange = Array(stride(from: 10, through: 20, by: 1))
		
		for size in fontSizeRange {
			fontSizePopUpButton.addItem(withTitle: String(size))
		}
		
		// Set the currently selected item based on user defaults
		let selectedSize = UserDefaults.standard.string(forKey: "DefaultFontSize") ?? "12"
		fontSizePopUpButton.selectItem(withTitle: selectedSize)
	}


	// MARK: - Actions
	
	/// Called when the user changes the font size preference.
	/// - Parameter sender: The NSPopUpButton that triggered the action.
	@IBAction func fontSizeChanged(_ sender: NSPopUpButton) {
		let selectedFontSize = sender.selectedItem?.title ?? "12"
		saveFontSizePreference(selectedFontSize)
		applyFontSizePreference(selectedFontSize)
	}
	
	/// Saves the user's font size preference to UserDefaults.
	/// - Parameter fontSize: The font size to save.
	func saveFontSizePreference(_ fontSize: String) {
		UserDefaults.standard.set(fontSize, forKey: "DefaultFontSize")
	}
	
	/// Applies the font size preference to relevant UI elements.
	/// - Parameter fontSize: The font size to apply.
	func applyFontSizePreference(_ fontSize: String) {
		guard let size = Float(fontSize) else { return }
		let newFont = NSFont.systemFont(ofSize: CGFloat(size)) // Use FontManager if you have different fonts
		// Update your text views or other UI elements with the new font
	}
	
	/// Called when the user changes the font type preference.
	/// - Parameter sender: The NSMenuItem that triggered the action.
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
		
		// Broadcast a notification indicating the font setting has changed.
		NotificationCenter.default.post(name: Notification.Name("FontSettingChanged"), object: nil)
	}
}

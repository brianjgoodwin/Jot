//
//  SettingsViewController.swift
//  Jot
//
//  Created by Brian on 12/25/23.
//

import Cocoa

import Cocoa

class SettingsViewController: NSViewController {
	
	// 1. Add a button or another trigger to open the font panel
	@IBAction func openFontPicker(_ sender: Any) {
		let fontManager = NSFontManager.shared
		fontManager.target = self
		fontManager.action = #selector(fontChanged(_:))
		fontManager.orderFrontFontPanel(self)
	}
	
	// 2. This method will be called when the user changes the font
	@objc func fontChanged(_ sender: NSFontManager) {
		let newFont = sender.convert(NSFont.systemFont(ofSize: NSFont.systemFontSize))
		updateFont(with: newFont)
	}
	
	// 3. Update the font in the user interface and save the preference
	func updateFont(with font: NSFont) {
		// Update any UI elements that should display the new font
		// ...

		// Save the font name and size to UserDefaults
		PreferencesManager.shared.preferredFontName = font.fontName
		PreferencesManager.shared.preferredFontSize = font.pointSize
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Apply the current preferred font when the view loads
		applySavedFontPreferences()
	}
	
	func applySavedFontPreferences() {
		let fontName = PreferencesManager.shared.preferredFontName
		let fontSize = PreferencesManager.shared.preferredFontSize
		if let font = NSFont(name: fontName, size: fontSize) {
			// Update your UI with this font
			// ...
		}
	}
}

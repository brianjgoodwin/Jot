//
//  SettingsViewController.swift
//  Jot
//
//  Created by Brian on 12/25/23.
//

import Cocoa

protocol TextSettingsDelegate: AnyObject {
	func didSelectFont(_ font: NSFont)
	func didSelectFontSize(_ fontSize: CGFloat)
	func currentFontSize() -> CGFloat
}

class SettingsViewController: NSViewController {
	
	@IBOutlet weak var fontPopUpButton: NSPopUpButton!
	@IBOutlet weak var fontSizePopupButton: NSPopUpButton!
	@IBOutlet var autosaveIntervalPopup: NSPopUpButton!
//	@IBOutlet weak var spellCheckingCheckbox: NSButton!
	
	weak var delegate: TextSettingsDelegate?
	var selectedFontSize: CGFloat?
	var selectedFontName: String?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupFontPopUpButton()
		setupFontSizePopUpButton()
		selectCurrentFont()
		selectCurrentFontSize()
//		let spellCheckingEnabled = UserDefaults.standard.bool(forKey: "spellCheckingEnabled")
//			spellCheckingCheckbox.state = spellCheckingEnabled ? .on : .off
	}
	
	func setupFontPopUpButton() {
		fontPopUpButton.removeAllItems()
		
		let fonts: [(title: String, actualName: String, font: NSFont)] = [
			("System Default", NSFont.systemFont(ofSize: NSFont.systemFontSize).fontName, NSFont.systemFont(ofSize: NSFont.systemFontSize)),
			("System Mono", NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular).fontName, NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)),
			("Serif", "New York", NSFont(name: "New York", size: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)),
			("Typewriter", "American Typewriter", NSFont(name: "American Typewriter", size: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)),
			("Courier New", "Courier New", NSFont(name: "Courier New", size: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize))
		]
		
		for (title, actualName, font) in fonts {
			let menuItem = NSMenuItem()
			menuItem.title = title
			menuItem.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])
			menuItem.action = #selector(changeFont(_:))
			menuItem.target = self
			menuItem.representedObject = actualName
			fontPopUpButton.menu?.addItem(menuItem)
		}
	}
	
	func setupFontSizePopUpButton() {
		fontSizePopupButton.removeAllItems()
		
		for size in stride(from: 6, through: 48, by: 1) {
			let menuItem = NSMenuItem(title: "\(size)", action: #selector(changeFontSize(_:)), keyEquivalent: "")
			menuItem.representedObject = size  // Store the font size as an Int
			menuItem.target = self
			fontSizePopupButton.menu?.addItem(menuItem)
		}
	}
	
	func selectCurrentFont() {
		let currentFontName = selectedFontName ?? UserDefaults.standard.string(forKey: "selectedFontName") ?? NSFont.systemFont(ofSize: NSFont.systemFontSize).fontName
		if let items = fontPopUpButton.menu?.items {
			for item in items {
				if let actualName = item.representedObject as? String, actualName == currentFontName {
					fontPopUpButton.select(item)
					break
				}
			}
		}
	}
	
	func selectCurrentFontSize() {
		let currentFontSize = CGFloat(UserDefaults.standard.float(forKey: "selectedFontSize"))
		if currentFontSize != 0, let item = fontSizePopupButton.item(withTitle: "\(Int(currentFontSize))") {
			fontSizePopupButton.select(item)
		}
	}
	
	// MARK: Spell Check Toggle
	@IBAction func toggleSpellChecking(_ sender: NSButton) {
		let isEnabled = sender.state == .on
		UserDefaults.standard.set(isEnabled, forKey: "spellCheckingEnabled")
		NotificationCenter.default.post(name: .spellCheckingPreferenceChanged, object: nil)
	}
	
	@objc func changeFontSize(_ sender: NSMenuItem) {
		guard let size = sender.representedObject as? Int else { return }
		delegate?.didSelectFontSize(CGFloat(size))
	}
	
	
	@objc func changeFont(_ sender: NSMenuItem) {
		// Retrieve the actual font name from the representedObject
		guard let actualFontName = sender.representedObject as? String else { return }
		print("Font selected: \(actualFontName)") // Debugging output
		
		// Attempt to create a font with this name and the selected size
		let fontSize = delegate?.currentFontSize() ?? NSFont.systemFontSize
		guard let font = NSFont(name: actualFontName, size: fontSize) else {
			print("Failed to create font with name: \(actualFontName)")
			return
		}
		
		// Update the selected font and notify the delegate
		delegate?.didSelectFont(font)
		
		// Save the actual font name to UserDefaults
		UserDefaults.standard.set(actualFontName, forKey: "selectedFontName")
	}
	
	// Any additional code needed for your settings view controller...
}

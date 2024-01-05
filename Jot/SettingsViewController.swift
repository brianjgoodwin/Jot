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
	func currentFontSize() -> CGFloat  // Add this line
}

class SettingsViewController: NSViewController {
	
	@IBOutlet weak var fontPopUpButton: NSPopUpButton!
	@IBOutlet weak var fontSizePopupButton: NSPopUpButton!
	weak var delegate: TextSettingsDelegate?
	var selectedFontSize: CGFloat?  // Add this line
	var selectedFontName: String?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupFontPopUpButton()
		setupFontSizePopUpButton()
		selectCurrentFont()
		selectCurrentFontSize()
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
		
		for size in stride(from: 8, through: 24, by: 2) {
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


//import Cocoa
//
//class SettingsViewController: NSViewController {
//	// MARK: - Outlets
//	@IBOutlet weak var fontPopUpButton: NSPopUpButton!
//	@IBOutlet weak var fontSizePopUpButton: NSPopUpButton!
//
//	// MARK: - View Lifecycle
//	override func viewDidLoad() {
//		super.viewDidLoad()
//		setupFontPopUpButton()
//		setupFontSizePopUpButton()
//	}
//
//	// MARK: - Setup Functions
//	func setupFontPopUpButton() {
//		fontPopUpButton.removeAllItems()
//
//		let fonts: [(title: String, font: NSFont)] = [
//			("System Default", NSFont.systemFont(ofSize: NSFont.systemFontSize)),
//			("System Mono", NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)),
//			("Serif", NSFont(name: "New York", size: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize))
//		]
//
//		for (title, font) in fonts {
//			let menuItem = NSMenuItem()
//			menuItem.title = title
//			menuItem.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])
//			menuItem.action = #selector(changeFont(_:))
//			menuItem.target = self
//			fontPopUpButton.menu?.addItem(menuItem)
//		}
//	}
//
//	func setupFontSizePopUpButton() {
//		fontSizePopUpButton.removeAllItems()
//
//		let fontSizeRange = Array(stride(from: 10, through: 20, by: 1))
//		for size in fontSizeRange {
//			fontSizePopUpButton.addItem(withTitle: String(size))
//		}
//
//		let selectedSize = UserDefaults.standard.string(forKey: "DefaultFontSize") ?? "12"
//		fontSizePopUpButton.selectItem(withTitle: selectedSize)
//		fontSizePopUpButton.target = self
//		fontSizePopUpButton.action = #selector(changeFontSize(_:)) // Linking the action
//	}
//
//	// MARK: - Font Style Change Handling
//	@objc func changeFontSize(_ sender: NSPopUpButton) {
//		guard let selectedFontSize = sender.selectedItem?.title else { return }
//		saveFontSizePreference(selectedFontSize)
//		notifyTextStyleChange()
//	}
//
//	@objc func changeFont(_ sender: NSMenuItem) {
//		let userDefaults = UserDefaults.standard
//
//		switch sender.title {
//		case "System Default":
//			userDefaults.set("SystemDefault", forKey: "SelectedFont")
//		case "System Mono":
//			userDefaults.set("SystemMono", forKey: "SelectedFont")
//		case "Serif":
//			userDefaults.set("Serif", forKey: "SelectedFont")
//		default:
//			break
//		}
//
//		notifyTextStyleChange()
//	}
//
//	func saveFontSizePreference(_ fontSize: String) {
//		UserDefaults.standard.set(fontSize, forKey: "DefaultFontSize")
//	}
//
//	func notifyTextStyleChange() {
//		let currentFontName = UserDefaults.standard.string(forKey: "SelectedFont") ?? "SystemDefault"
//		let currentFontSize = UserDefaults.standard.string(forKey: "DefaultFontSize") ?? "12"
//		let userInfo = ["fontName": currentFontName, "fontSize": currentFontSize]
//
//		NotificationCenter.default.post(name: Notification.Name("TextStyleDidChange"), object: nil, userInfo: userInfo)
//	}
//}

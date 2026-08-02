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
	
	weak var delegate: TextSettingsDelegate?
	var selectedFontSize: CGFloat?
	var selectedFontName: String?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupFontPopUpButton()
		setupFontSizePopUpButton()
		setupAutosavePopup()
		selectCurrentFont()
		selectCurrentFontSize()
		configureAccessibility()
	}

	private func configureAccessibility() {
		fontPopUpButton.setAccessibilityLabel("Font")
		fontSizePopupButton.setAccessibilityLabel("Font size")
		autosaveIntervalPopup?.setAccessibilityLabel("Autosave")
	}

	func setupAutosavePopup() {
		guard let popup = autosaveIntervalPopup else { return }
		popup.removeAllItems()
		popup.addItems(withTitles: ["On", "Off"])
		popup.selectItem(withTitle: PreferencesManager.shared.autosaveEnabled ? "On" : "Off")
	}

	@IBAction func autosaveIntervalChanged(_ sender: NSPopUpButton) {
		PreferencesManager.shared.autosaveEnabled = (sender.titleOfSelectedItem == "On")
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
		let currentFontName = selectedFontName ?? PreferencesManager.shared.fontName ?? NSFont.systemFont(ofSize: NSFont.systemFontSize).fontName
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
		let currentFontSize = PreferencesManager.shared.fontSize ?? 0
		if currentFontSize != 0, let item = fontSizePopupButton.item(withTitle: "\(Int(currentFontSize))") {
			fontSizePopupButton.select(item)
		}
	}
	
	@objc func changeFontSize(_ sender: NSMenuItem) {
		guard let size = sender.representedObject as? Int else { return }
		delegate?.didSelectFontSize(CGFloat(size))
	}
	
	
	@objc func changeFont(_ sender: NSMenuItem) {
		guard let actualFontName = sender.representedObject as? String else { return }
		let fontSize = delegate?.currentFontSize() ?? NSFont.systemFontSize
		guard let font = NSFont(name: actualFontName, size: fontSize) else { return }
		delegate?.didSelectFont(font)
	}
	
}

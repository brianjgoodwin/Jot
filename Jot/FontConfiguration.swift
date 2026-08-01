//
//  FontConfiguration.swift
//  Jot
//
//  Shared font loading, saving, and application logic used by
//  ViewController and SettingsViewController.
//

import Cocoa

class FontConfiguration {

    static let shared = FontConfiguration()

    private(set) var currentFont: NSFont
    private(set) var currentSize: CGFloat

    static let defaultSize: CGFloat = 12

    // The font choices available in the Settings popup
    static let availableFonts: [(title: String, fontName: String)] = [
        ("System Default", NSFont.systemFont(ofSize: NSFont.systemFontSize).fontName),
        ("System Mono", NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular).fontName),
        ("Serif", "New York"),
        ("Typewriter", "American Typewriter"),
        ("Courier New", "Courier New")
    ]

    private init() {
        let prefs = PreferencesManager.shared
        let size = prefs.fontSize ?? FontConfiguration.defaultSize
        let font: NSFont

        if let name = prefs.fontName, let loaded = NSFont(name: name, size: size) {
            font = loaded
        } else {
            font = NSFont.systemFont(ofSize: size)
        }

        self.currentFont = font
        self.currentSize = size
    }

    func applyFont(_ font: NSFont) {
        currentFont = NSFont(descriptor: font.fontDescriptor, size: currentSize)
            ?? NSFont.systemFont(ofSize: currentSize)
        PreferencesManager.shared.fontName = font.fontName
    }

    func applySize(_ size: CGFloat) {
        currentSize = size
        currentFont = NSFont(descriptor: currentFont.fontDescriptor, size: size)
            ?? NSFont.systemFont(ofSize: size)
        PreferencesManager.shared.fontSize = size
    }

    func resolvedFont() -> NSFont {
        return NSFont(descriptor: currentFont.fontDescriptor, size: currentSize)
            ?? NSFont.systemFont(ofSize: currentSize)
    }
}

//
//  FontConfiguration.swift
//  Jot
//
//  Shared font loading, saving, and application logic used by
//  EditorViewController and SettingsPanelController.
//

import Cocoa

@MainActor
class FontConfiguration {

    static let shared = FontConfiguration()

    private(set) var currentFont: NSFont
    private(set) var currentSize: CGFloat

    static let defaultSize: CGFloat = 12

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

    /// Posted after any font or size change. Every editor window and the
    /// Settings preview observe this — the old 1:1 delegate reached only
    /// whichever window was main when Settings opened (#124).
    static let didChangeNotification = Notification.Name("JotFontConfigurationDidChange")

    /// Adopts the font and its own point size in one change (a font-panel
    /// pick carries both), posting a single notification.
    func applyFont(_ font: NSFont) {
        PreferencesManager.shared.fontName = font.fontName
        apply(font: font, size: font.pointSize)
    }

    func applySize(_ size: CGFloat) {
        apply(font: currentFont, size: size)
    }

    /// Single mutation point. fontName persistence stays in applyFont —
    /// a size-only change must not write the system font's dot-prefixed
    /// name into preferences, because NSFont(name:) round-trips those
    /// unreliably across OS versions.
    private func apply(font: NSFont, size: CGFloat) {
        currentSize = size
        currentFont = NSFont(descriptor: font.fontDescriptor, size: size)
            ?? NSFont.systemFont(ofSize: size)
        PreferencesManager.shared.fontSize = size
        NotificationCenter.default.post(name: FontConfiguration.didChangeNotification, object: self)
    }

    func resolvedFont() -> NSFont {
        return NSFont(descriptor: currentFont.fontDescriptor, size: currentSize)
            ?? NSFont.systemFont(ofSize: currentSize)
    }
}

//
//  PreferencesManager.swift
//  Jot
//
//  Centralized access to UserDefaults preferences.
//  Eliminates scattered raw string keys across ViewControllers.
//

import Cocoa

@MainActor
class PreferencesManager {

    static let shared = PreferencesManager()
    private init() {}

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key {
        static let selectedFontName = "selectedFontName"
        static let selectedFontSize = "selectedFontSize"
        static let autosaveEnabled = "autosaveEnabled"
        static let loadRemoteImages = "loadRemoteImages"
        static let showLineNumbers = "showLineNumbers"
    }

    // MARK: - Font

    var fontName: String? {
        get { defaults.string(forKey: Key.selectedFontName) }
        set { defaults.set(newValue, forKey: Key.selectedFontName) }
    }

    var fontSize: CGFloat? {
        get {
            let value = defaults.float(forKey: Key.selectedFontSize)
            return value != 0 ? CGFloat(value) : nil
        }
        set {
            if let size = newValue {
                defaults.set(Float(size), forKey: Key.selectedFontSize)
            } else {
                defaults.removeObject(forKey: Key.selectedFontSize)
            }
        }
    }

    // MARK: - Autosave

    var autosaveEnabled: Bool {
        get { defaults.object(forKey: Key.autosaveEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autosaveEnabled) }
    }

    // MARK: - Preview

    var loadRemoteImages: Bool {
        get { defaults.object(forKey: Key.loadRemoteImages) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.loadRemoteImages) }
    }

    // MARK: - Editor

    var showLineNumbers: Bool {
        get { defaults.object(forKey: Key.showLineNumbers) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showLineNumbers) }
    }
}

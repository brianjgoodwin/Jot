//
//  PreferencesManager.swift
//  Jot
//
//  Centralized access to UserDefaults preferences.
//  Eliminates scattered raw string keys across ViewControllers.
//

import Cocoa

class PreferencesManager {

    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key {
        static let selectedFontName = "selectedFontName"
        static let selectedFontSize = "selectedFontSize"
        static let autosaveEnabled = "autosaveEnabled"
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
}

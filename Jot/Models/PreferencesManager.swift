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

    // MARK: - Preview

    var loadRemoteImages: Bool {
        get { defaults.object(forKey: Key.loadRemoteImages) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.loadRemoteImages) }
    }

    // MARK: - Editor

    /// Posted when showLineNumbers changes, so open editors update live.
    static let showLineNumbersDidChangeNotification = Notification.Name("JotShowLineNumbersDidChange")

    /// Single source of truth for the line number gutter. The View menu
    /// toggle, the Settings popup, and every editor window all read and
    /// write this one value — the first gutter branch kept a per-window
    /// flag, this preference, and the Settings UI as three states that
    /// never reconciled (#106). Same broadcast shape as
    /// FontConfiguration.didChangeNotification (#124).
    var showLineNumbers: Bool {
        get { defaults.object(forKey: Key.showLineNumbers) as? Bool ?? true }
        set {
            guard newValue != showLineNumbers else { return }
            defaults.set(newValue, forKey: Key.showLineNumbers)
            NotificationCenter.default.post(
                name: Self.showLineNumbersDidChangeNotification, object: self)
        }
    }
}

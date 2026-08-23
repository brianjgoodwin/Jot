//
//  PreferencesManager.swift
//  Jot
//
//  Created on 8/9/26.
//
//  Centralized access to UserDefaults preferences.
//  Eliminates scattered raw string keys across ViewControllers.
//

import Cocoa

@MainActor
class PreferencesManager {

    static let shared = PreferencesManager()

    /// The backing store. Injectable so tests run against a throwaway
    /// suite instead of the developer's real preferences (#174). `var`
    /// rather than `let` solely so integration tests that must go
    /// through the shared singleton can repoint it for a test's
    /// duration — app code never reassigns it.
    var defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Key {
        static let selectedFontName = "selectedFontName"
        static let selectedFontSize = "selectedFontSize"
        static let loadRemoteImages = "loadRemoteImages"
        static let showLineNumbers = "showLineNumbers"
        static let lastSeenVersion = "lastSeenVersion"
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

    // MARK: - Version tracking (#99)

    /// What the launch version comparison found. Infrastructure for the
    /// future onboarding and what's-new windows — no UI reads this yet.
    enum VersionState: Equatable {
        /// No version ever recorded: the app has never launched.
        case firstLaunch
        /// The recorded version is older than the running one.
        case updated(from: String)
        /// Nothing to show.
        case current
    }

    /// The marketing version of the running app (CFBundleShortVersionString).
    /// nonisolated: it only reads the bundle's Info.plist, and the
    /// default argument below is evaluated outside the actor.
    nonisolated static var currentBundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// The last version this user launched. nil until the first launch
    /// records one.
    var lastSeenVersion: String? {
        get { defaults.string(forKey: Key.lastSeenVersion) }
        set { defaults.set(newValue, forKey: Key.lastSeenVersion) }
    }

    /// Compares the recorded version against the running one. The caller
    /// decides what to show, then records the current version via
    /// lastSeenVersion — the check never writes, so the state survives
    /// until whatever window it drives has actually been shown.
    ///
    /// The comparison is numeric ("1.0.9" < "1.0.10"; a plain string
    /// compare gets that wrong). A recorded version NEWER than the
    /// running one (a downgrade) reports .current, and the caller's
    /// no-op keeps the newer value recorded — so re-upgrading later
    /// does not re-show news the user has already seen.
    func versionState(currentVersion: String = PreferencesManager.currentBundleVersion) -> VersionState {
        guard let seen = lastSeenVersion else { return .firstLaunch }
        if seen.compare(currentVersion, options: .numeric) == .orderedAscending {
            return .updated(from: seen)
        }
        return .current
    }
}

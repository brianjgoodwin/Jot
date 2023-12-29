//
//  PreferencesManager.swift
//  Jot
//
//  Created by Brian on 12/25/23.
//

import Cocoa

struct PreferencesManager {
	static var shared = PreferencesManager()

	private let userDefaults = UserDefaults.standard

	private struct Keys {
		static let preferredFontName = "preferredFontName"
		static let preferredFontSize = "preferredFontSize"
	}

	var preferredFontName: String {
		get { userDefaults.string(forKey: Keys.preferredFontName) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize).fontName }
		set { userDefaults.set(newValue, forKey: Keys.preferredFontName) }
	}

	var preferredFontSize: CGFloat {
		get { CGFloat(userDefaults.float(forKey: Keys.preferredFontSize)) }
		set { userDefaults.set(Float(newValue), forKey: Keys.preferredFontSize) }
	}
}

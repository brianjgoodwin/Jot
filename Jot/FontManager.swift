////
////  FontManager.swift
////  Jot
////
////  Created by Brian on 12/31/23.
////
//
//import Cocoa
//
//class FontManager {
//	static let shared = FontManager()
//
//	func currentFont() -> NSFont {
//		let userDefaults = UserDefaults.standard
//		let fontName = userDefaults.string(forKey: "SelectedFont") ?? "SystemDefault"
//		return font(forName: fontName)
//	}
//	
//	private func font(forName fontName: String) -> NSFont {
////		let systemFontSize = NSFont.systemFontSize
//		switch fontName {
//		case "SystemMono":
//			return NSFont.monospacedSystemFont(ofSize: systemFontSize, weight: .regular)
//		case "Serif":
//			return NSFont(name: "New York", size: systemFontSize) ?? NSFont.systemFont(ofSize: systemFontSize)
//		default:
//			return NSFont.systemFont(ofSize: systemFontSize)
//		}
//	}
//}

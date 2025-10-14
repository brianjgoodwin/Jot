//
//  Logger.swift
//  Jot
//
//  Created by Brian on 3/3/25.
//

import Foundation

public func logToFile(_ message: String) {
	let fm = FileManager.default
	guard let downloadsURL = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
		print("❌ Could not locate Downloads folder")
		return
	}
	
	let logFileURL = downloadsURL.appendingPathComponent("Jot_Debug.log")
	
	let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .long)
	let logMessage = "\(timestamp): \(message)\n"
	
	guard let data = logMessage.data(using: .utf8) else {
		print("❌ Failed to convert log message to data")
		return
	}
	
	do {
		if fm.fileExists(atPath: logFileURL.path) {
			let fileHandle = try FileHandle(forWritingTo: logFileURL)
			fileHandle.seekToEndOfFile()
			fileHandle.write(data)
			fileHandle.closeFile()
		} else {
			try data.write(to: logFileURL)
		}
		print("✅ Log written to \(logFileURL.path)")
	} catch {
		print("❌ Error writing log: \(error)")
	}
}

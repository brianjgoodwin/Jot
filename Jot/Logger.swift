//
//  Logger.swift
//  Jot
//
//  Created by Brian on 3/3/25.
//

import Foundation

public func logToFile(_ message: String) {
#if DEBUG
	let fm = FileManager.default
	guard let supportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

	let logDir = supportURL.appendingPathComponent("Jot", isDirectory: true)
	try? fm.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)

	let logFileURL = logDir.appendingPathComponent("Jot_Debug.log")

	// Rotate log if it exceeds 5MB
	if let attrs = try? fm.attributesOfItem(atPath: logFileURL.path),
	   let size = attrs[.size] as? Int64, size > 5 * 1024 * 1024 {
		try? fm.removeItem(at: logFileURL)
	}

	let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .long)
	let logMessage = "\(timestamp): \(message)\n"

	guard let data = logMessage.data(using: .utf8) else { return }

	if fm.fileExists(atPath: logFileURL.path),
	   let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
		fileHandle.seekToEndOfFile()
		fileHandle.write(data)
		fileHandle.closeFile()
	} else {
		try? data.write(to: logFileURL)
	}
#endif
}

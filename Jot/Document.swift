//
//  Document.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class Document: NSDocument {
	// Store the plain text content of the document
	var text = ""
	
	// Enables autosaving for the document
	override class var autosavesInPlace: Bool {
		return true
	}
	
	// MARK: - Window Controller Management
	// Creates and configures the window controller for the document
	override func makeWindowControllers() {
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		guard let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as? NSWindowController else {
			return
		}
		self.addWindowController(windowController)
		
		if let contentViewController = windowController.contentViewController as? ViewController {
			contentViewController.textView.string = text // Set the text in the text view
			contentViewController.calculateInitialWordCount() // Calculate the initial word count
		}
	}
	
	// MARK: - Data Management
	// Converts the document's text to data for saving
	override func data(ofType typeName: String) throws -> Data {
		guard let data = text.data(using: .utf8) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		return data
	}
	
	// Reads data and converts it to plain text for the document
	override func read(from data: Data, ofType typeName: String) throws {
		logToFile("📂 Document.read(from:ofType:) started (data length: \(data.count))")

		// Validate file size (warn if > 10MB, reject if > 100MB)
		let maxFileSize = 100 * 1024 * 1024 // 100MB
		let warningFileSize = 10 * 1024 * 1024 // 10MB

		if data.count > maxFileSize {
			logToFile("❌ Document.read(from:ofType:) failed: File too large (\(data.count) bytes)")
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
						  userInfo: [NSLocalizedDescriptionKey: "File is too large (maximum 100MB)"])
		}

		if data.count > warningFileSize {
			logToFile("⚠️ Large file detected: \(data.count) bytes")
		}

		// Validate UTF-8 encoding
		guard let loadedText = String(data: data, encoding: .utf8) else {
			logToFile("❌ Document.read(from:ofType:) failed: Could not decode text")
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
						  userInfo: [NSLocalizedDescriptionKey: "File is not valid UTF-8 text"])
		}

		text = loadedText
		logToFile("✅ Document.read(from:ofType:) succeeded: loaded text length: \(loadedText.count)")
	}
	
	// MARK: - Saving and Writing
	// Converts the text to data and writes it to the specified URL
	override func write(to url: URL, ofType typeName: String) throws {
		// Validate text can be encoded as UTF-8
		guard let data = text.data(using: .utf8) else {
			logToFile("❌ Document.write(to:ofType:) failed: Could not encode text as UTF-8")
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
						  userInfo: [NSLocalizedDescriptionKey: "Failed to encode document as UTF-8"])
		}

		// Validate file size before writing
		if data.count > 100 * 1024 * 1024 {
			logToFile("❌ Document.write(to:ofType:) failed: Document too large (\(data.count) bytes)")
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
						  userInfo: [NSLocalizedDescriptionKey: "Document is too large to save (maximum 100MB)"])
		}

		try data.write(to: url, options: .atomic)
		logToFile("✅ Document saved successfully: \(data.count) bytes")
	}
	
	// MARK: - Printing
	// Creates a print operation for the document
	override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
		let printInfo = NSPrintInfo(dictionary: printSettings)
		let printOperation = NSPrintOperation(view: printableView(), printInfo: printInfo)
		return printOperation
	}
	
	// Creates a view representing the content to print
	internal func printableView() -> NSView {
		let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
		printView.string = text // Set the content to the document's text
		return printView
	}
	
	// MARK: - Duplication
	// Handle duplication of the document
	override func duplicate() throws -> NSDocument {
		guard let newDocument = try super.duplicate() as? Document else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
						  userInfo: [NSLocalizedDescriptionKey: "Failed to duplicate document"])
		}
		newDocument.text = self.text // Pass the document's text to the new document
		return newDocument
	}
	
	// Additional methods and features...
}

extension Document {
	var unsavedStateURL: URL {
		let fm = FileManager.default
		let supportFolder = try? fm.url(for: .applicationSupportDirectory,
										in: .userDomainMask,
										appropriateFor: nil,
										create: true)
		let unsavedFolder = supportFolder?.appendingPathComponent("Jot/UnsavedStates", isDirectory: true)
		if let folder = unsavedFolder {
			if !fm.fileExists(atPath: folder.path) {
				try? fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
			}
			// Use the file name from fileURL if available; otherwise, a UUID.
			let fileName: String
			if let fileURL = self.fileURL {
				// Sanitize filename to prevent path traversal attacks
				let sanitizedName = fileURL.lastPathComponent
					.replacingOccurrences(of: "..", with: "_")
					.replacingOccurrences(of: "/", with: "_")
					.replacingOccurrences(of: "\\", with: "_")
				fileName = sanitizedName + ".unsaved"
			} else {
				fileName = UUID().uuidString + ".unsaved"
			}
			return folder.appendingPathComponent(fileName)
		} else {
			return fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".unsaved")
		}
	}

	var cursorPositionKey: String {
		if let fileURL = self.fileURL {
			return "cursorPosition_\(fileURL.path)"
		} else {
			// Use a persistent identifier for unsaved documents
			return "cursorPosition_unsaved_\(unsavedStateURL.lastPathComponent)"
		}
	}
	
	func saveUnsavedState() {
		guard !self.text.isEmpty else {
			logToFile("[\(Date())] ⚠ Skipping unsaved state save: text is empty")
			return
		}

		// Validate text size before saving
		if self.text.count > 50 * 1024 * 1024 { // 50MB limit for unsaved states
			logToFile("[\(Date())] ⚠ Skipping unsaved state save: text too large (\(self.text.count) chars)")
			return
		}

		do {
			try self.text.write(to: unsavedStateURL, atomically: true, encoding: .utf8)
			logToFile("[\(Date())] ✅ Saved unsaved state to \(unsavedStateURL.path) (length: \(self.text.count))")
		} catch {
			logToFile("[\(Date())] ❌ Error saving unsaved state: \(error)")
		}
	}

	func restoreUnsavedState() -> Bool {
		let fm = FileManager.default
		if fm.fileExists(atPath: unsavedStateURL.path) {
			do {
				// Check file size before reading
				let attributes = try fm.attributesOfItem(atPath: unsavedStateURL.path)
				if let fileSize = attributes[.size] as? Int64 {
					if fileSize > 100 * 1024 * 1024 { // 100MB
						logToFile("[\(Date())] ❌ Unsaved state file too large: \(fileSize) bytes")
						return false
					}
				}

				let restoredText = try String(contentsOf: unsavedStateURL, encoding: .utf8)
				logToFile("[\(Date())] ✅ Read unsaved state from \(unsavedStateURL.path) (length: \(restoredText.count))")
				self.text = restoredText
				return true
			} catch {
				logToFile("[\(Date())] ❌ Error restoring unsaved state: \(error)")
			}
		} else {
			logToFile("[\(Date())] ⚠ No unsaved state file exists at \(unsavedStateURL.path)")
		}
		return false
	}

}


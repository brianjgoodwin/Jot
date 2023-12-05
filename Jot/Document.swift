//
//  Document.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class Document: NSDocument {
	var text = "" // Store the plain text content here

	override class var autosavesInPlace: Bool {
		return true // Enable autosave for the document
	}

	override func makeWindowControllers() {
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
		self.addWindowController(windowController)

		if let contentViewController = windowController.contentViewController as? ViewController {
			contentViewController.textView.string = text // Set the text in your text view
		}
	}

	override func data(ofType typeName: String) throws -> Data {
		// Convert the text to data for saving
		if let data = text.data(using: .utf8) {
			return data
		} else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
	}

	override func read(from data: Data, ofType typeName: String) throws {
		// Read data and convert it to plain text
		if let loadedText = String(data: data, encoding: .utf8) {
			text = loadedText
		} else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
	}
	
	// Implement saving functionality
	override func write(to url: URL, ofType typeName: String) throws {
		// Convert the text to data
		if let data = text.data(using: .utf8) {
			try data.write(to: url, options: .atomic)
		} else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
	}
}

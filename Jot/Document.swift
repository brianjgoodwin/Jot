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
			contentViewController.calculateInitialWordCount() // Calculate initial word count
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
	
// MARK: Printing
//	override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey : Any]) throws -> NSPrintOperation {
//		// Create an NSPrintOperation with your print settings
//		let printInfo = NSPrintInfo(dictionary: printSettings)
//		let printOperation = NSPrintOperation(view: printableView(), printInfo: printInfo)
//
//		return printOperation
//	}
//
//	internal func printableView() -> NSView {
//		// Create a view that represents the content you want to print
//		// In your case, it could be a view that contains the text you want to print
//		let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
//
//		// Set the content of the print view to your document's text
//		printView.string = text
//
//		return printView
//	}

}

//import Cocoa
//
//class Document: NSDocument {
//	var text = "" // Store the plain text content here
//	
//	override class var autosavesInPlace: Bool {
//		return true // Enable autosave for the document
//	}
//	
//	override func makeWindowControllers() {
//		let storyboard = NSStoryboard(name: "Main", bundle: nil)
//		let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
//		self.addWindowController(windowController)
//
//		if let contentViewController = windowController.contentViewController as? ViewController {
//			contentViewController.textView.string = text // Set the text in your text view
//			contentViewController.calculateInitialWordCount() // Calculate initial word count
//		}
//	}
//
//	
//	override func data(ofType typeName: String) throws -> Data {
//		// Convert the text to data for saving
//		if let data = text.data(using: .utf8) {
//			return data
//		} else {
//			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
//		}
//	}
//	
//	override func read(from data: Data, ofType typeName: String) throws {
//		// Read data and convert it to plain text
//		if let loadedText = String(data: data, encoding: .utf8) {
//			text = loadedText
//		} else {
//			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
//		}
//	}
//	
//	// Implement saving functionality
//	override func write(to url: URL, ofType typeName: String) throws {
//		// Convert the text to data
//		if let data = text.data(using: .utf8) {
//			try data.write(to: url, options: .atomic)
//		} else {
//			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
//		}
//	}
//	
//	override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey : Any]) throws -> NSPrintOperation {
//		// Create an NSPrintOperation with your print settings
//		let printInfo = NSPrintInfo(dictionary: printSettings)
//		let printOperation = NSPrintOperation(view: printableView(), printInfo: printInfo)
//
//		return printOperation
//	}
//
//	internal func printableView() -> NSView {
//		// Create a view that represents the content you want to print
//		// In your case, it could be a view that contains the text you want to print
//		let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
//		
//		// Set the content of the print view to your document's text
//		printView.string = text
//
//		return printView
//	}
//
//}

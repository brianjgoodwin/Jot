//
//  Document.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class Document: NSDocument {
	
	// Store the document's content as a simple string
	var content = ""
	
	// Enables autosaving in place for the document
	override class var autosavesInPlace: Bool {
		return true
	}
	
	// MARK: - Window Controller Management
	
	// Creates and configures the window controller for the document
	override func makeWindowControllers() {
		// Here you should initialize your window controller and set it up
		let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
		if let windowController = storyboard.instantiateController(withIdentifier: "DocumentWindowController") as? NSWindowController {
			self.addWindowController(windowController)
			
			// Pass the document content to the view controller if needed
			if let viewController = windowController.contentViewController as? ViewController {
				viewController.textView.string = self.content
			}
		}
	}
	
	// MARK: - Data Management
	
	// Saves the document's content to a file
	override func data(ofType typeName: String) throws -> Data {
		// Here, convert your document's content to Data
		guard let data = self.content.data(using: .utf8) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		return data
	}
	
	// Loads the document's content from a file
	override func read(from data: Data, ofType typeName: String) throws {
		// Here, convert the loaded Data to your document's content format
		guard let loadedContent = String(data: data, encoding: .utf8) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		self.content = loadedContent
	}
	
	// MARK: - Duplication
	
	// Handle duplication of the document
	override func duplicate() throws -> NSDocument {
		let newDocument = try super.duplicate() as! Document
		newDocument.content = self.content
		return newDocument
	}
	
	// Additional required initializers for NSDocument subclassing
	override init() {
		super.init()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}


////Pre-testing
//import Cocoa
//
//class Document: NSDocument {
//	// Store the plain text content of the document
//	var text = ""
//
//	// Enables autosaving for the document
//	override class var autosavesInPlace: Bool {
//		return true
//	}
//
//	// MARK: - Window Controller Management
//	// Creates and configures the window controller for the document
//	override func makeWindowControllers() {
//		let storyboard = NSStoryboard(name: "Main", bundle: nil)
//		guard let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as? NSWindowController else {
//			return
//		}
//		self.addWindowController(windowController)
//
//		if let contentViewController = windowController.contentViewController as? ViewController {
//			contentViewController.textView.string = text // Set the text in the text view
//			contentViewController.calculateInitialWordCount() // Calculate the initial word count
//		}
//	}
//
//	// MARK: - Data Management
//	// Converts the document's text to data for saving
//	override func data(ofType typeName: String) throws -> Data {
//		guard let data = text.data(using: .utf8) else {
//			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
//		}
//		return data
//	}
//
//	// Reads data and converts it to plain text for the document
//	override func read(from data: Data, ofType typeName: String) throws {
//		guard let loadedText = String(data: data, encoding: .utf8) else {
//			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
//		}
//		text = loadedText
//	}
//
//	// MARK: - Saving and Writing
//	// Converts the text to data and writes it to the specified URL
//	override func write(to url: URL, ofType typeName: String) throws {
//		guard let data = text.data(using: .utf8) else {
//			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
//		}
//		try data.write(to: url, options: .atomic)
//	}
//
//	// MARK: - Printing
//	// Creates a print operation for the document
//	override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
//		let printInfo = NSPrintInfo(dictionary: printSettings)
//		let printOperation = NSPrintOperation(view: printableView(), printInfo: printInfo)
//		return printOperation
//	}
//
//	// Creates a view representing the content to print
//	internal func printableView() -> NSView {
//		let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
//		printView.string = text // Set the content to the document's text
//		return printView
//	}
//
//	// Additional methods and features...
//}

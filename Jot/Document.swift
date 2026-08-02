//
//  Document.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class Document: NSDocument {
	var text = ""

	override class var autosavesInPlace: Bool {
		return PreferencesManager.shared.autosaveEnabled
	}

	// MARK: - Window Controller Management
	override func makeWindowControllers() {
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		guard let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as? NSWindowController else {
			return
		}
		self.addWindowController(windowController)

		if let contentViewController = windowController.contentViewController as? ViewController {
			contentViewController.textView.string = text
			contentViewController.calculateInitialWordCount()
		}
	}

	// MARK: - Data Management
	override func data(ofType typeName: String) throws -> Data {
		// Sync from the textView in case the debounced timer hasn't fired yet
		if let viewController = windowControllers.first?.contentViewController as? ViewController {
			text = viewController.textView.string
		}
		guard let data = text.data(using: .utf8) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		return data
	}

	override func read(from data: Data, ofType typeName: String) throws {
		guard let loadedText = String(data: data, encoding: .utf8) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		text = loadedText
	}

	// MARK: - Saving and Writing
	override func write(to url: URL, ofType typeName: String) throws {
		guard let data = text.data(using: .utf8) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		try data.write(to: url, options: .atomic)
	}

	// MARK: - Printing
	override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
		let printInfo = NSPrintInfo(dictionary: printSettings)
		let printOperation = NSPrintOperation(view: printableView(), printInfo: printInfo)
		return printOperation
	}

	internal func printableView() -> NSView {
		let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
		printView.string = text
		return printView
	}

	// MARK: - Duplication
	override func duplicate() throws -> NSDocument {
		guard let newDocument = try super.duplicate() as? Document else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		newDocument.text = self.text
		return newDocument
	}

}

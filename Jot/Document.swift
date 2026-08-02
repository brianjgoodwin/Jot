//
//  Document.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class Document: NSDocument {
	nonisolated(unsafe) var text = ""

	// AppKit may cache this value per-document, so toggling the preference
	// in Settings may not take effect for already-open documents.
	// Reads UserDefaults directly to avoid MainActor isolation requirement.
	override class var autosavesInPlace: Bool {
		return UserDefaults.standard.object(forKey: "autosaveEnabled") as? Bool ?? true
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
		// Try UTF-8 first
		if let loadedText = String(data: data, encoding: .utf8) {
			text = loadedText
			return
		}

		// UTF-16 only if a BOM is present (without a BOM, UTF-16 decodes
		// arbitrary bytes as garbage)
		if data.count >= 2 {
			let bom = (UInt16(data[0]) << 8) | UInt16(data[1])
			if bom == 0xFEFF || bom == 0xFFFE,
			   let loadedText = String(data: data, encoding: .utf16) {
				text = loadedText
				return
			}
		}

		// CP1252 first: it is a superset of Latin-1 (fills 0x80-0x9F with
		// smart quotes, em-dashes, euro sign) and handles the vast majority
		// of non-UTF-8 files from Windows. Latin-1 and macOS Roman are
		// unreachable since CP1252 accepts any byte sequence, but kept as
		// defensive fallbacks.
		for encoding: String.Encoding in [.windowsCP1252, .isoLatin1, .macOSRoman] {
			if let loadedText = String(data: data, encoding: encoding) {
				text = loadedText
				return
			}
		}

		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
					  userInfo: [NSLocalizedDescriptionKey: "Unable to read file: unsupported text encoding"])
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

	// MARK: - Unsaved State Persistence

	private static let unsavedStatesFolder: URL? = {
		let fm = FileManager.default
		guard let support = try? fm.url(for: .applicationSupportDirectory,
										in: .userDomainMask,
										appropriateFor: nil,
										create: true) else { return nil }
		let folder = support.appendingPathComponent("Jot/UnsavedStates", isDirectory: true)
		if !fm.fileExists(atPath: folder.path) {
			try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
		}
		return folder
	}()

	private lazy var untitledStateID = UUID().uuidString

	var unsavedStateURL: URL {
		let fileName: String
		if let fileURL = self.fileURL {
			let sanitized = fileURL.lastPathComponent
				.replacingOccurrences(of: "..", with: "_")
				.replacingOccurrences(of: "/", with: "_")
				.replacingOccurrences(of: "\\", with: "_")
			fileName = sanitized + ".unsaved"
		} else {
			fileName = untitledStateID + ".unsaved"
		}

		if let folder = Document.unsavedStatesFolder {
			return folder.appendingPathComponent(fileName)
		}
		return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
	}

	func saveUnsavedState() {
		guard !text.isEmpty else { return }
		try? text.write(to: unsavedStateURL, atomically: true, encoding: .utf8)
	}

	static func restoreUnsavedStates() {
		let fm = FileManager.default
		guard let folder = unsavedStatesFolder,
			  let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }

		for fileURL in files {
			guard let restoredText = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
			let doc = Document()
			doc.text = restoredText
			NSDocumentController.shared.addDocument(doc)
			doc.makeWindowControllers()
			doc.showWindows()
			try? fm.removeItem(at: fileURL)
		}
	}
}

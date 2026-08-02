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

	/// URL of the restored .unsaved file, kept until the document is saved or
	/// closed so crash-during-launch doesn't lose recovery data (#87).
	private var restoredFromURL: URL?

	var unsavedStateURL: URL {
		let fileName: String
		if let fileURL = self.fileURL {
			// Hash the full path to avoid collisions between same-named files
			// in different directories (#88).
			let pathHash = String(fileURL.path.hashValue, radix: 36, uppercase: false)
			let baseName = fileURL.lastPathComponent
				.replacingOccurrences(of: "..", with: "_")
				.replacingOccurrences(of: "/", with: "_")
				.replacingOccurrences(of: "\\", with: "_")
			fileName = "\(baseName)_\(pathHash).unsaved"
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

	/// Remove the .unsaved file after a successful save or when the document
	/// is closed, not at restore time (#87).
	func cleanUpUnsavedState() {
		if let url = restoredFromURL {
			try? FileManager.default.removeItem(at: url)
			restoredFromURL = nil
		}
		// Also remove the current unsaved state file if it exists
		let stateURL = unsavedStateURL
		if FileManager.default.fileExists(atPath: stateURL.path) {
			try? FileManager.default.removeItem(at: stateURL)
		}
	}

	override func save(_ sender: Any?) {
		super.save(sender)
		cleanUpUnsavedState()
	}

	override func close() {
		cleanUpUnsavedState()
		super.close()
	}

	/// Restore unsaved documents from the UnsavedStates folder. Deferred to
	/// the next run-loop iteration so AppKit's own state restoration runs
	/// first, avoiding duplicate windows (#89).
	static func restoreUnsavedStates() {
		DispatchQueue.main.async {
			performRestore()
		}
	}

	private static func performRestore() {
		let fm = FileManager.default
		guard let folder = unsavedStatesFolder,
			  let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }

		// Collect paths of documents AppKit already restored (#89)
		let openPaths = Set(
			NSDocumentController.shared.documents
				.compactMap { ($0 as? Document)?.fileURL?.path }
		)

		for fileURL in files {
			guard fileURL.pathExtension == "unsaved",
				  let restoredText = try? String(contentsOf: fileURL, encoding: .utf8),
				  !restoredText.isEmpty else { continue }

			// Untitled documents use a UUID filename. Named documents use
			// "name_hash.unsaved". If AppKit already restored a named
			// document from disk, skip the stale .unsaved file (#89).
			let stem = fileURL.deletingPathExtension().lastPathComponent
			let isUntitled = UUID(uuidString: stem) != nil
			if !isUntitled && !openPaths.isEmpty {
				try? fm.removeItem(at: fileURL)
				continue
			}

			let doc = Document()
			doc.text = restoredText
			doc.restoredFromURL = fileURL
			NSDocumentController.shared.addDocument(doc)
			doc.makeWindowControllers()
			doc.showWindows()
		}
	}
}

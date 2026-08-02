//
//  Document.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

class Document: NSDocument {
	// SAFETY: NSDocument calls read/write overrides on the main thread for
	// non-concurrent document types. This class does not opt into
	// canConcurrentlyReadDocuments(ofType:), so all access is serialized
	// through the main thread in practice.
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

	/// Deterministic hash of a string, stable across process launches.
	/// Swift's hashValue is randomly seeded per process and must not be
	/// used for filenames that need to survive a restart.
	private static func stableHash(of string: String) -> String {
		var hash: UInt64 = 5381
		for byte in string.utf8 {
			hash = hash &* 33 &+ UInt64(byte)
		}
		return String(hash, radix: 36, uppercase: false)
	}

	var unsavedStateURL: URL {
		let fileName: String
		if let fileURL = self.fileURL {
			// Hash the full path to avoid collisions between same-named files
			// in different directories (#88). Uses a stable DJB2 hash instead
			// of hashValue, which is randomized per process launch.
			let pathHash = Document.stableHash(of: fileURL.path)
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

	/// Sentinel prefix used to store the original file path as the first
	/// line of .unsaved files for named documents, so performRestore()
	/// can check against already-open documents (#89).
	private static let pathSentinel = "jot-original-path:"

	func saveUnsavedState() {
		guard !text.isEmpty else { return }
		var content = text
		if let fileURL = self.fileURL {
			content = Document.pathSentinel + fileURL.path + "\n" + text
		}
		try? content.write(to: unsavedStateURL, atomically: true, encoding: .utf8)
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

	override func save(to url: URL, ofType typeName: String,
					   for saveOperation: NSDocument.SaveOperationType,
					   completionHandler: @escaping (Error?) -> Void) {
		super.save(to: url, ofType: typeName, for: saveOperation) { [weak self] error in
			if error == nil {
				self?.cleanUpUnsavedState()
			}
			completionHandler(error)
		}
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
				  let rawContent = try? String(contentsOf: fileURL, encoding: .utf8),
				  !rawContent.isEmpty else { continue }

			// Extract the original file path and text content.
			// Named documents store the path as the first line with a sentinel.
			let restoredText: String
			if rawContent.hasPrefix(pathSentinel) {
				let afterSentinel = rawContent.dropFirst(pathSentinel.count)
				guard let newlineIndex = afterSentinel.firstIndex(of: "\n") else { continue }
				let originalPath = String(afterSentinel[afterSentinel.startIndex..<newlineIndex])
				restoredText = String(afterSentinel[afterSentinel.index(after: newlineIndex)...])

				// Skip if AppKit already restored this specific document (#89)
				if openPaths.contains(originalPath) {
					try? fm.removeItem(at: fileURL)
					continue
				}
			} else {
				restoredText = rawContent
			}

			guard !restoredText.isEmpty else { continue }

			let doc = Document()
			doc.text = restoredText
			doc.restoredFromURL = fileURL
			NSDocumentController.shared.addDocument(doc)
			doc.makeWindowControllers()
			doc.showWindows()
		}
	}
}

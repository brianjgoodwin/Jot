//
//  Document.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa
import os.signpost

class Document: NSDocument {
	// SAFETY: NSDocument calls read/write overrides on the main thread for
	// non-concurrent document types. This class does not opt into
	// canConcurrentlyReadDocuments(ofType:), so all access is serialized
	// through the main thread in practice.
	nonisolated(unsafe) var text = ""

	// Unconditionally true: NSDocument owns autosave, crash recovery
	// (drafts in ~/Library/Autosave Information), and the Versions
	// browser. The user-toggleable preference and the hand-rolled
	// UnsavedStates subsystem it justified were removed in #121.
	override class var autosavesInPlace: Bool {
		return true
	}

	// MARK: - Window Controller Management
	override func makeWindowControllers() {
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		guard let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as? NSWindowController else {
			return
		}
		self.addWindowController(windowController)

		if let contentViewController = windowController.contentViewController as? EditorViewController {
			contentViewController.textView.string = text
			contentViewController.updateWordCount()
		}
	}

	// MARK: - Data Management
	// NOTE: Do not override write(to:ofType:). NSDocument's default
	// implementation routes every save (Cmd-S, autosave, close, quit)
	// through data(ofType:), which is the single point that flushes the
	// live textView. A write override would serialize stale `text` (#118).
	/// Copy the live textView contents into `text`, in case the debounced
	/// sync hasn't fired yet. Every path that serializes the document
	/// (saving, printing) must call this first.
	private func syncTextFromEditor() {
		if let viewController = windowControllers.first?.contentViewController as? EditorViewController {
			text = viewController.textView.string
		}
	}

	override func data(ofType typeName: String) throws -> Data {
		// `text` is nonisolated(unsafe); catch any future off-main caller
		dispatchPrecondition(condition: .onQueue(.main))
		syncTextFromEditor()
		guard let data = text.data(using: .utf8) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		return data
	}

	override func read(from data: Data, ofType typeName: String) throws {
		dispatchPrecondition(condition: .onQueue(.main))
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

		// CP1252 first: it fills 0x80-0x9F with smart quotes, em-dashes,
		// and the euro sign, and handles the vast majority of non-UTF-8
		// files from Windows. CP1252 leaves five bytes undefined
		// (0x81/0x8D/0x8F/0x90/0x9D), so files containing them fall
		// through to Latin-1, then macOS Roman.
		for encoding: String.Encoding in [.windowsCP1252, .isoLatin1, .macOSRoman] {
			if let loadedText = String(data: data, encoding: encoding) {
				text = loadedText
				return
			}
		}

		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
					  userInfo: [NSLocalizedDescriptionKey: "Unable to read file: unsupported text encoding"])
	}

	// MARK: - Reverting
	override func revert(toContentsOf url: URL, ofType typeName: String) throws {
		try super.revert(toContentsOf: url, ofType: typeName)
		// super rereads the file into `text`, but nothing else pushes it
		// back into the editor -- without this the window keeps showing the
		// old text and the next debounced sync re-overwrites the revert (#119).
		if let viewController = windowControllers.first?.contentViewController as? EditorViewController {
			viewController.documentDidRevert(to: text)
		}
	}

	// MARK: - Printing
	override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
		syncTextFromEditor()
		// Base the operation on this document's print info (Page Setup)
		// plus the print panel's settings -- never the shared global (#125).
		guard let printInfo = self.printInfo.copy() as? NSPrintInfo else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		printInfo.dictionary().addEntries(from: printSettings)
		printInfo.horizontalPagination = .fit
		printInfo.verticalPagination = .automatic
		return NSPrintOperation(view: printableView(for: printInfo), printInfo: printInfo)
	}

	/// A text view sized to the page content area so line wrapping and
	/// pagination follow the paper size instead of a fixed 400x600 frame,
	/// using the user's editor font (#125).
	internal func printableView(for printInfo: NSPrintInfo) -> NSView {
		// Paper minus the user's margins. NSPrintOperation insets the
		// margins itself, so sizing from imageablePageBounds here would
		// apply them twice.
		let contentSize = NSSize(
			width: printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin,
			height: printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin
		)
		let printView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
		// A bare off-window view follows the app's appearance; in dark
		// mode that prints near-white text on white paper
		printView.appearance = NSAppearance(named: .aqua)
		printView.string = text
		printView.font = FontConfiguration.shared.resolvedFont()

		// Lay out the whole document and grow the frame to its full
		// height, otherwise NSPrintOperation paginates a one-page-tall
		// view and everything past page one is dropped
		printView.isHorizontallyResizable = false
		printView.isVerticallyResizable = true
		printView.maxSize = NSSize(width: contentSize.width, height: .greatestFiniteMagnitude)
		printView.textContainer?.widthTracksTextView = true
		if let layoutManager = printView.layoutManager, let container = printView.textContainer {
			layoutManager.ensureLayout(for: container)
		}
		printView.sizeToFit()
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

	// MARK: - Legacy unsaved-state migration

	// Jot 1.0.6-1.0.8 had a hand-rolled crash-recovery system that wrote
	// .unsaved files to Application Support on every quit with unsaved
	// changes. NSDocument autosave replaced it (#121). This migration
	// restores any leftover drafts once, then deletes the legacy files
	// (which held document text in plaintext indefinitely). Remove this
	// whole section once 1.0.6-1.0.8 installs are gone.

	/// Overridable in tests to use a temporary directory (#95).
	static var unsavedStatesFolder: URL? = {
		guard let support = try? FileManager.default.url(for: .applicationSupportDirectory,
														 in: .userDomainMask,
														 appropriateFor: nil,
														 create: false) else { return nil }
		return support.appendingPathComponent("Jot/UnsavedStates", isDirectory: true)
	}()

	/// The legacy format stored a named document's path as the first line.
	private static let legacyPathSentinel = "jot-original-path:"

	/// Deferred one run-loop iteration so AppKit's own window restoration
	/// runs first and already-restored documents can be recognized.
	static func migrateLegacyUnsavedStates() {
		DispatchQueue.main.async {
			performLegacyMigration()
		}
	}

	/// Internal (not private) so the migration is unit-testable
	/// with the unsavedStatesFolder override (#135).
	static func performLegacyMigration() {
		let signpostID = OSSignpostID(log: PerformanceLog.log)
		os_signpost(.begin, log: PerformanceLog.log, name: "Legacy Draft Restore", signpostID: signpostID)
		defer { os_signpost(.end, log: PerformanceLog.log, name: "Legacy Draft Restore", signpostID: signpostID) }

		let fm = FileManager.default
		guard let folder = unsavedStatesFolder,
			  let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }

		let openPaths = Set(
			NSDocumentController.shared.documents
				.compactMap { ($0 as? Document)?.fileURL?.path }
		)

		for fileURL in files {
			guard fileURL.pathExtension == "unsaved" else { continue }

			guard let rawContent = try? String(contentsOf: fileURL, encoding: .utf8),
				  !rawContent.isEmpty else {
				try? fm.removeItem(at: fileURL)
				continue
			}

			var restoredText = rawContent
			if rawContent.hasPrefix(legacyPathSentinel) {
				let afterSentinel = rawContent.dropFirst(legacyPathSentinel.count)
				guard let newlineIndex = afterSentinel.firstIndex(of: "\n") else {
					try? fm.removeItem(at: fileURL)
					continue
				}
				let originalPath = String(afterSentinel[afterSentinel.startIndex..<newlineIndex])
				restoredText = String(afterSentinel[afterSentinel.index(after: newlineIndex)...])

				// AppKit already restored this document; the draft is stale
				if openPaths.contains(originalPath) {
					try? fm.removeItem(at: fileURL)
					continue
				}
			}

			guard !restoredText.isEmpty else {
				try? fm.removeItem(at: fileURL)
				continue
			}

			let doc = Document()
			doc.text = restoredText
			// Mark edited so the draft participates in NSDocument autosave
			// and closing the window prompts to save (#120)
			doc.updateChangeCount(.changeDone)
			NSDocumentController.shared.addDocument(doc)
			doc.makeWindowControllers()
			doc.showWindows()

			// NSDocument autosave owns the draft from here
			try? fm.removeItem(at: fileURL)
		}

		// Best-effort removal of the now-empty legacy folder
		if let remaining = try? fm.contentsOfDirectory(atPath: folder.path), remaining.isEmpty {
			try? fm.removeItem(at: folder)
		}
	}
}

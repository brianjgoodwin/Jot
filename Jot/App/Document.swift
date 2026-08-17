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

	// MARK: - File encoding and line endings (#194, #195)
	// Same main-thread serialization argument as `text` above.

	/// The encoding the file was read with; saves go back out the same way
	/// instead of silently converting to UTF-8. Untitled documents are UTF-8.
	nonisolated(unsafe) var readEncoding: String.Encoding = .utf8
	/// A UTF-8 byte-order mark is stripped from the buffer on read and put
	/// back on save; files without one never gain one.
	nonisolated(unsafe) var hadUTF8BOM = false
	/// The buffer is normalized to LF; this convention is restored on save.
	nonisolated(unsafe) var lineEnding: LineEnding = .lf

	/// Encoding parsed from the file's com.apple.TextEncoding extended
	/// attribute, alive only while a URL-based read is in flight — the
	/// data-based read consults it for its first decoding attempt.
	private var xattrEncodingHint: String.Encoding?

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
		// Cascading repositions the window after the autosaved frame is
		// applied, which silently defeats frameAutosaveName (#187). Only
		// cascade when another document is already open, so the first
		// window returns to its saved frame and extras stagger off it.
		windowController.shouldCascadeWindows = NSDocumentController.shared.documents.count > 1
		self.addWindowController(windowController)

		if let contentViewController = windowController.contentViewController as? EditorViewController {
			contentViewController.loadText(text)
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
		var outgoing = lineEnding.restore(in: text)
		if hadUTF8BOM {
			outgoing = "\u{FEFF}" + outgoing
		}
		guard let data = outgoing.data(using: readEncoding) else {
			// The user typed characters the original encoding can't hold
			// (a CP1252 file gaining an emoji). Never convert silently —
			// the error offers the conversion as an explicit choice (#194)
			throw encodingUnrepresentableError()
		}
		return data
	}

	override func read(from url: URL, ofType typeName: String) throws {
		// Peek at the com.apple.TextEncoding attribute before the default
		// implementation funnels down to read(from:ofType:) with bare data
		xattrEncodingHint = Self.encodingFromExtendedAttribute(at: url)
		defer { xattrEncodingHint = nil }
		try super.read(from: url, ofType: typeName)
	}

	override func read(from data: Data, ofType typeName: String) throws {
		dispatchPrecondition(condition: .onQueue(.main))
		guard let (rawDecoded, encoding) = Self.decode(data, hint: xattrEncodingHint) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr,
						  userInfo: [NSLocalizedDescriptionKey: "Unable to read file: unsupported text encoding"])
		}
		var decoded = rawDecoded
		readEncoding = encoding
		// String(data:encoding:.utf8) keeps a byte-order mark as U+FEFF:
		// invisible in the editor, but present in counts, searches, and
		// position math. Strip it here; save puts the bytes back (#194).
		hadUTF8BOM = encoding == .utf8 && decoded.hasPrefix("\u{FEFF}")
		if decoded.hasPrefix("\u{FEFF}") {
			decoded.removeFirst()
		}
		lineEnding = LineEnding.detect(in: decoded) ?? .lf
		text = LineEnding.normalizeToLF(decoded)
	}

	/// The detection ladder, unchanged from before #194 except that it now
	/// reports which rung matched. A com.apple.TextEncoding hint gets the
	/// first try so ambiguous bytes decode the way they were written.
	private static func decode(_ data: Data, hint: String.Encoding?) -> (String, String.Encoding)? {
		if let hint, let decoded = String(data: data, encoding: hint) {
			return (decoded, hint)
		}
		if let decoded = String(data: data, encoding: .utf8) {
			return (decoded, .utf8)
		}

		// UTF-16 only if a BOM is present (without a BOM, UTF-16 decodes
		// arbitrary bytes as garbage)
		if data.count >= 2 {
			let bom = (UInt16(data[0]) << 8) | UInt16(data[1])
			if bom == 0xFEFF || bom == 0xFFFE,
			   let decoded = String(data: data, encoding: .utf16) {
				return (decoded, .utf16)
			}
		}

		// CP1252 first: it fills 0x80-0x9F with smart quotes, em-dashes,
		// and the euro sign, and handles the vast majority of non-UTF-8
		// files from Windows. CP1252 leaves five bytes undefined
		// (0x81/0x8D/0x8F/0x90/0x9D), so files containing them fall
		// through to Latin-1, then macOS Roman.
		for encoding: String.Encoding in [.windowsCP1252, .isoLatin1, .macOSRoman] {
			if let decoded = String(data: data, encoding: encoding) {
				return (decoded, encoding)
			}
		}
		return nil
	}

	// MARK: - Encoding persistence and recovery (#194)

	/// Parses "com.apple.TextEncoding" ("<IANA name>;<CFStringEncoding>",
	/// e.g. "windows-1252;1280") — the attribute TextEdit and Cocoa's own
	/// string writers maintain. The number wins; the name is the fallback.
	private static func encodingFromExtendedAttribute(at url: URL) -> String.Encoding? {
		var buffer = [UInt8](repeating: 0, count: 256)
		let length = getxattr(url.path, "com.apple.TextEncoding", &buffer, buffer.count, 0, 0)
		guard length > 0, let value = String(bytes: buffer[0..<length], encoding: .utf8) else {
			return nil
		}

		let parts = value.split(separator: ";", omittingEmptySubsequences: false)
		if parts.count >= 2, let cfRawValue = UInt32(parts[1]),
		   CFStringIsEncodingAvailable(CFStringEncoding(cfRawValue)) {
			return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfRawValue)))
		}
		if let name = parts.first, !name.isEmpty {
			let cfEncoding = CFStringConvertIANACharSetNameToEncoding(String(name) as CFString)
			if cfEncoding != kCFStringEncodingInvalidId {
				return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
			}
		}
		return nil
	}

	/// Writes com.apple.TextEncoding as part of the safe-save itself, so
	/// the attribute survives the atomic swap (writing it after the fact
	/// would race the swap — the trap #157 documents). It is a hint, never
	/// the only record: xattrs vanish on SMB shares, git, and uploads, and
	/// the read ladder still detects the encoding without it.
	override func fileAttributesToWrite(to url: URL, ofType typeName: String,
										for saveOperation: NSDocument.SaveOperationType,
										originalContentsURL absoluteOriginalContentsURL: URL?) throws -> [String: Any] {
		var attributes = try super.fileAttributesToWrite(to: url, ofType: typeName,
														 for: saveOperation,
														 originalContentsURL: absoluteOriginalContentsURL)
		if let value = Self.textEncodingAttributeValue(for: readEncoding) {
			var extended = attributes["NSFileExtendedAttributes"] as? [String: Any] ?? [:]
			extended["com.apple.TextEncoding"] = Data(value.utf8)
			attributes["NSFileExtendedAttributes"] = extended
		}
		return attributes
	}

	internal static func textEncodingAttributeValue(for encoding: String.Encoding) -> String? {
		let cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)
		guard cfEncoding != kCFStringEncodingInvalidId,
			  let ianaName = CFStringConvertEncodingToIANACharSetName(cfEncoding) as String? else {
			return nil
		}
		return "\(ianaName);\(cfEncoding)"
	}

	/// Short human name for the status bar and error text.
	var encodingDisplayName: String {
		switch readEncoding {
		case .utf8: return hadUTF8BOM ? "UTF-8 BOM" : "UTF-8"
		case .utf16: return "UTF-16"
		case .windowsCP1252: return "CP1252"
		case .isoLatin1: return "Latin-1"
		case .macOSRoman: return "Mac Roman"
		default: return String.localizedName(of: readEncoding)
		}
	}

	private func encodingUnrepresentableError() -> NSError {
		NSError(domain: "JotDocumentErrorDomain", code: 1, userInfo: [
			NSLocalizedDescriptionKey:
				"This document can no longer be saved in its original \(encodingDisplayName) encoding.",
			NSLocalizedRecoverySuggestionErrorKey:
				"It now contains characters that \(encodingDisplayName) can't represent. You can save it as UTF-8 instead, or cancel and remove the new characters.",
			NSLocalizedRecoveryOptionsErrorKey: ["Save as UTF-8", "Cancel"],
			NSRecoveryAttempterErrorKey: EncodingRecoveryAttempter(document: self),
		])
	}

	/// Called by the recovery attempter after converting to UTF-8, and by
	/// anything else that changes encoding metadata outside a read.
	func noteEncodingDidChange() {
		(windowControllers.first?.contentViewController as? EditorViewController)?.updateFileInfoLabel()
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
		newDocument.readEncoding = readEncoding
		newDocument.hadUTF8BOM = hadUTF8BOM
		newDocument.lineEnding = lineEnding
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

	/// Parks a draft the migration couldn't safely judge, instead of
	/// deleting it. The archive is a sibling of the state folder (derived
	/// from it, so the test override covers it) — putting it inside would
	/// break the folder-emptiness cleanup and re-process files every launch.
	private static func archiveLegacyFile(_ fileURL: URL) {
		guard let folder = unsavedStatesFolder else { return }
		let archive = folder.deletingLastPathComponent()
			.appendingPathComponent(folder.lastPathComponent + "-Archived", isDirectory: true)
		let fm = FileManager.default
		try? fm.createDirectory(at: archive, withIntermediateDirectories: true)
		var destination = archive.appendingPathComponent(fileURL.lastPathComponent)
		if fm.fileExists(atPath: destination.path) {
			let unique = fileURL.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString
			destination = archive.appendingPathComponent(unique).appendingPathExtension("unsaved")
		}
		// On failure the file stays put and the next launch retries
		try? fm.moveItem(at: fileURL, to: destination)
	}

	/// Deferred one run-loop iteration to stay off the launch path. The
	/// migration no longer consults which documents are open, so it has no
	/// ordering requirement against window restoration (#173).
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

		var recoveredCount = 0
		var untitledCount = 0
		var firstRecoveredWindow: NSWindow?
		for fileURL in files {
			guard fileURL.pathExtension == "unsaved" else { continue }

			guard let rawContent = try? String(contentsOf: fileURL, encoding: .utf8) else {
				// A draft that can't be read can't be judged either — park
				// it instead of destroying bytes no one inspected (#173)
				archiveLegacyFile(fileURL)
				continue
			}
			if rawContent.isEmpty {
				try? fm.removeItem(at: fileURL)
				continue
			}

			var restoredText = rawContent
			var originalName: String?
			if rawContent.hasPrefix(legacyPathSentinel) {
				let afterSentinel = rawContent.dropFirst(legacyPathSentinel.count)
				guard let newlineIndex = afterSentinel.firstIndex(of: "\n") else {
					// A sentinel with no body line plausibly means the legacy
					// writer was interrupted mid-file — exactly the draft not
					// to destroy (#173)
					archiveLegacyFile(fileURL)
					continue
				}
				let originalPath = String(afterSentinel[afterSentinel.startIndex..<newlineIndex])
				restoredText = String(afterSentinel[afterSentinel.index(after: newlineIndex)...])
				originalName = URL(fileURLWithPath: originalPath).lastPathComponent
			}

			guard !restoredText.isEmpty else {
				try? fm.removeItem(at: fileURL)
				continue
			}

			// Always recover, even when the original file is already open:
			// the legacy system wrote a draft precisely because it held edits
			// the on-disk file never received, so a window restored from disk
			// does not cover it. The old "already open, delete as stale"
			// check discarded the only copy of those edits (#173).
			let doc = Document()
			doc.text = restoredText
			recoveredCount += 1
			// Window title carries the context a sighted user infers and a
			// VoiceOver user otherwise never gets (#153). NSDocument's own
			// setter is used deliberately: it applies only while the document
			// is untitled and yields to the real filename once the user saves.
			// An overridden getter would keep saying "Recovered Draft" in the
			// window title, save panel, and close alert forever.
			if let originalName {
				// The filename lets the user compare this draft against the
				// same file's restored window side by side
				doc.displayName = "Recovered Draft — \(originalName)"
			} else {
				untitledCount += 1
				doc.displayName = untitledCount == 1
					? "Recovered Draft"
					: "Recovered Draft \(untitledCount)"
			}
			// Mark edited so the draft participates in NSDocument autosave
			// and closing the window prompts to save (#120)
			doc.updateChangeCount(.changeDone)
			NSDocumentController.shared.addDocument(doc)
			doc.makeWindowControllers()
			doc.showWindows()
			if firstRecoveredWindow == nil {
				firstRecoveredWindow = doc.windowControllers.first?.window
			}

			// NSDocument autosave owns the draft from here
			try? fm.removeItem(at: fileURL)
		}

		if recoveredCount > 0, let window = firstRecoveredWindow {
			announceRecovery(of: recoveredCount, from: window)
		}

		// Best-effort removal of the now-empty legacy folder
		if let remaining = try? fm.contentsOfDirectory(atPath: folder.path), remaining.isEmpty {
			try? fm.removeItem(at: folder)
		}
	}

	/// Speak the recovery notice, once the app is active and a window is key.
	///
	/// Three things this gets wrong if done naively (#153 follow-up):
	/// announcements default to medium priority, which VoiceOver coalesces
	/// away when it is already speaking — and at launch it is busy with the
	/// app name and window title; posting during activation routes nowhere;
	/// and posting against NSApp is unreliable, so this targets the recovered
	/// window like every other announcement in the app.
	private static func announceRecovery(of count: Int, from window: NSWindow) {
		let message = count == 1
			? "Recovered 1 unsaved draft from a previous session"
			: "Recovered \(count) unsaved drafts from a previous session"

		if NSApp.isActive {
			postAnnouncement(message, to: window)
			return
		}
		// Launch case: wait for activation, then post once. The observer
		// crosses an isolation boundary, so it may only capture Sendable
		// values — the window travels as its number and is looked up
		// again on the main actor, not captured.
		let windowNumber = window.windowNumber
		var token: NSObjectProtocol?
		token = NotificationCenter.default.addObserver(
			forName: NSApplication.didBecomeActiveNotification,
			object: NSApp,
			queue: .main
		) { _ in
			if let token { NotificationCenter.default.removeObserver(token) }
			MainActor.assumeIsolated {
				// The window may have closed during launch; drop the
				// announcement rather than target a dead element.
				guard let window = NSApp.window(withWindowNumber: windowNumber) else { return }
				postAnnouncement(message, to: window)
			}
		}
	}

	private static func postAnnouncement(_ message: String, to window: NSWindow) {
		NSAccessibility.post(
			element: window,
			notification: .announcementRequested,
			userInfo: [
				.announcement: message,
				.priority: NSAccessibilityPriorityLevel.high.rawValue
			]
		)
	}
}

/// Recovery for the unrepresentable-encoding save error (#194): option 0
/// converts the document to UTF-8 and retries the save. NSDocument presents
/// save errors as sheets, which drive the delegate-based recovery method —
/// it forwards to the boolean one and reports back through the selector.
private final class EncodingRecoveryAttempter: NSObject {
	private weak var document: Document?

	init(document: Document) {
		self.document = document
	}

	override func attemptRecovery(fromError error: Error, optionIndex recoveryOptionIndex: Int) -> Bool {
		guard recoveryOptionIndex == 0, let document else { return false }
		// AppKit presents document save errors on the main thread
		return MainActor.assumeIsolated {
			document.readEncoding = .utf8
			document.hadUTF8BOM = false
			document.noteEncodingDidChange()
			guard let fileURL = document.fileURL else { return true }
			// AppKit is still unwinding the failed save when this runs, and
			// it does not reliably retry after recovery — re-save once the
			// stack clears. The closure crosses an isolation boundary, so it
			// carries the URL and looks the document up again rather than
			// capturing it (same pattern as the recovery announcement). The
			// isDocumentEdited guard makes a double save harmless.
			DispatchQueue.main.async {
				MainActor.assumeIsolated {
					guard let document = NSDocumentController.shared.document(for: fileURL) as? Document,
						  document.isDocumentEdited else { return }
					document.save(nil)
				}
			}
			return true
		}
	}

	override func attemptRecovery(fromError error: Error, optionIndex recoveryOptionIndex: Int,
								  delegate: Any?, didRecoverSelector: Selector?,
								  contextInfo: UnsafeMutableRawPointer?) {
		let didRecover = attemptRecovery(fromError: error, optionIndex: recoveryOptionIndex)
		guard let delegate = delegate as? NSObject, let didRecoverSelector else { return }
		// The callback signature is (didRecover:contextInfo:) — not
		// expressible through performSelector, hence the IMP cast
		typealias Callback = @convention(c) (NSObject, Selector, Bool, UnsafeMutableRawPointer?) -> Void
		let callback = unsafeBitCast(delegate.method(for: didRecoverSelector), to: Callback.self)
		callback(delegate, didRecoverSelector, didRecover, contextInfo)
	}
}

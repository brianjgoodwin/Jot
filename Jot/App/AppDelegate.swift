//
//  AppDelegate.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
	
	var aboutWindowController: AboutWindowControllerProgrammatic?
	var settingsPanelController: SettingsPanelController?
	var wordCountPanelController: WordCountPanelController?
	var helpWindowController: HelpWindowController?
	var previewWindowController: MarkdownPreviewWindowController?
	var acknowledgementsWindowController: AcknowledgementsWindowController?

	/// The File > New from Template submenu (#161), populated on demand
	/// from the Templates folder by templateMenuSource.
	@IBOutlet weak var newFromTemplateMenu: NSMenu!
	var templateMenuSource: FolderMenuSource?

	/// The Edit > Insert Snippet submenu (#162), populated on demand
	/// from the Snippets folder by snippetMenuSource.
	@IBOutlet weak var insertSnippetMenu: NSMenu!
	var snippetMenuSource: FolderMenuSource?

	@IBAction func showAboutWindow(_ sender: Any) {
		if aboutWindowController == nil {
			aboutWindowController = AboutWindowControllerProgrammatic()
		}
		aboutWindowController?.showWindow(sender)
	}

	@IBAction func showHelp(_ sender: Any?) {
		if helpWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			helpWindowController = storyboard.instantiateController(withIdentifier: "HelpWindowController") as? HelpWindowController
		}
		
		helpWindowController?.showWindow(sender)
	}

	@IBAction func showMarkdownPreview(_ sender: Any) {
		if previewWindowController == nil {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
			previewWindowController = storyboard.instantiateController(withIdentifier: "MarkdownPreviewWindowController") as? MarkdownPreviewWindowController
		}

		if let vc = NSApp.mainWindow?.contentViewController as? EditorViewController {
			previewWindowController?.loadMarkdown(markdown: vc.textView.string)
		}
		previewWindowController?.showWindow(self)
	}
	
	@IBAction func showSettingsWindow(_ sender: Any) {
		if settingsPanelController == nil {
			settingsPanelController = SettingsPanelController()
		}
		// No per-window wiring: font changes broadcast via
		// FontConfiguration.didChangeNotification to every editor (#124)
		settingsPanelController?.showWindow(sender)
	}
	
	/// Show/Hide toggle: the panel is built with becomesKeyOnlyIfNeeded and
	/// holds only non-selectable labels, so nothing in it ever needs key
	/// input and it does not take key status in normal use — which leaves
	/// Cmd-W acting on the document window behind it. Without this toggle a
	/// keyboard-only user can summon a floating panel and then has only the
	/// mouse to dismiss it (#152). The menu title tracks state in
	/// validateMenuItem.
	@IBAction func showWordCountWindow(_ sender: Any) {
		if wordCountPanelController == nil {
			wordCountPanelController = WordCountPanelController()
		}
		if wordCountPanelController?.window?.isVisible == true {
			wordCountPanelController?.window?.orderOut(sender)
		} else {
			wordCountPanelController?.showWindow(sender)
		}
	}
	
	/// View > Show/Hide Line Numbers. Lives here rather than on the editor
	/// because it only writes the shared preference — every open editor
	/// observes that and updates itself (#106), and the command stays
	/// meaningful with no document window open. Same Show/Hide title
	/// pattern as Word Count (#152), handled in validateMenuItem.
	@IBAction func toggleLineNumbers(_ sender: Any) {
		PreferencesManager.shared.showLineNumbers.toggle()
	}

	@IBAction func openHelpWebsite(_ sender: Any) {
		if let url = URL(string: "https://github.com/brianjgoodwin/Jot/wiki/Feedback-and-Support") {
			NSWorkspace.shared.open(url)
		}
	}
	
	@IBAction func openPrivacyWebsite(_ sender: Any) {
		if let url = URL(string: "https://github.com/brianjgoodwin/Jot/wiki/Privacy") {
			NSWorkspace.shared.open(url)
		}
	}
	
	// MARK: - New from Template (#161)

	@IBAction func newDocumentFromTemplate(_ sender: Any?) {
		guard let url = (sender as? NSMenuItem)?.representedObject as? URL else { return }
		do {
			try Document.makeUntitledDocument(fromTemplateAt: url)
		} catch {
			NSApp.presentError(error)
		}
	}

	/// The Templates and Snippets folders are only ever created here,
	/// never during a menu scan.
	@IBAction func openTemplatesFolder(_ sender: Any?) {
		openInFinderCreatingIfNeeded(templateMenuSource?.folder)
	}

	// MARK: - Insert Snippet (#162)

	@IBAction func openSnippetsFolder(_ sender: Any?) {
		openInFinderCreatingIfNeeded(snippetMenuSource?.folder)
	}

	// MARK: - Services (#149)

	/// A service message that launched the app arrives before
	/// applicationDidFinishLaunching (why the provider registers in
	/// applicationWillFinishLaunching) and before AppKit asks about the
	/// default untitled window — this flag suppresses that window so a
	/// cold-launch service invocation opens only the draft.
	private var serviceCreatedDraftDuringLaunch = false
	private var hasFinishedLaunching = false

	/// "New Jot Note from Selection": selected text in any app becomes an
	/// untitled Jot draft. Declared in Info.plist under NSServices; the
	/// selector name must match its NSMessage entry. MainActor is safe:
	/// AppKit delivers service messages on the main thread.
	@MainActor @objc func newJotNoteFromSelection(_ pboard: NSPasteboard,
	                                   userData: String?,
	                                   error: AutoreleasingUnsafeMutablePointer<NSString?>) {
		guard let text = pboard.string(forType: .string), !text.isEmpty else {
			error.pointee = "No text was found in the selection." as NSString
			return
		}
		// A pasteboard has no pre-read size query, so the string is
		// already in memory — but the expensive part (normalize, style,
		// layout) has not run yet, and that is what the guard prevents.
		guard text.utf8.count <= Document.maximumInputBytes else {
			error.pointee = "The selection is too large for a Jot note." as NSString
			return
		}
		if !hasFinishedLaunching {
			serviceCreatedDraftDuringLaunch = true
		}
		Document.makeUntitledDocument(withText: text)
		// The services system does not activate the provider app; without
		// this the draft opens behind the app the user invoked us from.
		if #available(macOS 14.0, *) {
			NSApp.activate()
		} else {
			NSApp.activate(ignoringOtherApps: true)
		}
	}

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		if serviceCreatedDraftDuringLaunch {
			serviceCreatedDraftDuringLaunch = false
			return false
		}
		return true
	}

	private func openInFinderCreatingIfNeeded(_ folder: URL?) {
		guard let folder else { return }
		do {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		} catch {
			NSApp.presentError(error)
			return
		}
		NSWorkspace.shared.open(folder)
	}

	@IBAction func openAcknowledgements(_ sender: Any) {
		if acknowledgementsWindowController == nil {
			acknowledgementsWindowController = AcknowledgementsWindowController()
		}
		acknowledgementsWindowController?.showWindow(sender)
	}

	
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(showWordCountWindow(_:)) {
			menuItem.title = (wordCountPanelController?.window?.isVisible == true)
				? "Hide Word Count"
				: "Show Word Count"
		}
		if menuItem.action == #selector(toggleLineNumbers(_:)) {
			menuItem.title = PreferencesManager.shared.showLineNumbers
				? "Hide Line Numbers"
				: "Show Line Numbers"
		}
		return true
	}

	func applicationWillFinishLaunching(_ notification: Notification) {
		// Receiver for the NSServices entry in Info.plist (#149).
		// Registered before launch finishes: a service invocation can be
		// the reason the app is launching, and AppKit delivers the
		// service message before applicationDidFinishLaunching.
		NSApp.servicesProvider = self
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// One-time recovery of drafts left by the pre-1.0.9 hand-rolled
		// crash-recovery system. NSDocument autosave owns crash recovery
		// now (#121), so there is no terminate-time state saving.
		Document.migrateLegacyUnsavedStates()

		// The submenu contents live in the Templates folder, not the
		// storyboard — the delegate rebuilds them on every menu open (#161).
		let source = FolderMenuSource(
			folder: FolderMenuSource.applicationSupportFolder(named: "Templates"),
			fileExtensions: ["txt", "md"],
			emptyTitle: "No Templates",
			selectionAction: #selector(newDocumentFromTemplate(_:)),
			selectionTarget: self,
			openFolderTitle: "Open Templates Folder",
			openFolderAction: #selector(openTemplatesFolder(_:)),
			openFolderTarget: self)
		templateMenuSource = source
		newFromTemplateMenu?.delegate = source

		// Snippet items get a nil target so the responder chain routes
		// them to the key window's editor — and disables them when there
		// is none (#162).
		let snippetSource = FolderMenuSource(
			folder: FolderMenuSource.applicationSupportFolder(named: "Snippets"),
			fileExtensions: ["txt", "md"],
			emptyTitle: "No Snippets",
			selectionAction: #selector(EditorViewController.insertSnippet(_:)),
			selectionTarget: nil,
			openFolderTitle: "Open Snippets Folder",
			openFolderAction: #selector(openSnippetsFolder(_:)),
			openFolderTarget: self)
		snippetMenuSource = snippetSource
		insertSnippetMenu?.delegate = snippetSource

		hasFinishedLaunching = true
	}

	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
	
	// NOTE: Print… targets First Responder in the storyboard, so
	// NSDocument's printDocument: handles it via
	// Document.printOperation(withSettings:). A parallel print path here
	// mutated the shared NSPrintInfo and was reachable with no document
	// open (#125).
}

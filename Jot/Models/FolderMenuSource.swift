//
//  FolderMenuSource.swift
//  Jot
//
//  Created on 8/17/26.
//
//  Fills a submenu from the plain-text files of a folder (#161,
//  the BBEdit-stationery pattern): the file system is the management
//  UI, the menu is just a live view of the folder. Configuration-
//  driven so Insert Snippet (#162) is a second instance of this
//  class, not a second class.
//

import Cocoa

@MainActor
final class FolderMenuSource: NSObject, NSMenuDelegate {

	/// The folder whose files become menu items. An instance property
	/// so tests point an instance at a temporary directory. A nil or
	/// missing folder reads as empty — it is only created on demand by
	/// the "Open … Folder" action, never during a menu scan.
	var folder: URL?

	/// A stable item below the separator — "Create New Template…",
	/// "Open Templates Folder" (#233). These never depend on the folder
	/// contents.
	struct TrailingItem {
		let title: String
		let action: Selector
	}

	private let fileExtensions: Set<String>
	private let emptyTitle: String
	private let selectionAction: Selector
	/// nil sends selection actions down the responder chain, which also
	/// auto-disables the items when nothing responds — Insert Snippet
	/// (#162) uses this so its items dim when no editor is key.
	private weak var selectionTarget: AnyObject?
	private let trailingItems: [TrailingItem]
	private weak var trailingTarget: AnyObject?

	/// - Parameter fileExtensions: lowercase, without the dot.
	init(folder: URL?,
	     fileExtensions: Set<String>,
	     emptyTitle: String,
	     selectionAction: Selector,
	     selectionTarget: AnyObject?,
	     trailingItems: [TrailingItem],
	     trailingTarget: AnyObject) {
		self.folder = folder
		self.fileExtensions = fileExtensions
		self.emptyTitle = emptyTitle
		self.selectionAction = selectionAction
		self.selectionTarget = selectionTarget
		self.trailingItems = trailingItems
		self.trailingTarget = trailingTarget
	}

	/// App Support/Jot/<name> — the same container-relative resolution
	/// as Document.unsavedStatesFolder. nonisolated: pure path
	/// computation, and badgeLabel's default arguments (which evaluate
	/// outside the actor) need to call it.
	nonisolated static func applicationSupportFolder(named name: String) -> URL? {
		guard let support = try? FileManager.default.url(for: .applicationSupportDirectory,
		                                                 in: .userDomainMask,
		                                                 appropriateFor: nil,
		                                                 create: false) else {
			return nil
		}
		return support.appendingPathComponent("Jot/\(name)", isDirectory: true)
	}

	/// Visible regular files with a matching extension, in Finder order.
	/// The regular-file check keeps a directory or pipe named "X.md" from
	/// becoming a menu item that errors on selection. It also excludes
	/// symlinks (isRegularFile describes the link itself here, not its
	/// target) — deliberate: the sandbox would deny most link targets
	/// anyway, and a link that silently reads a file from elsewhere is
	/// exactly the surprise this menu should not have.
	func files() -> [URL] {
		guard let folder,
		      let contents = try? FileManager.default.contentsOfDirectory(at: folder,
		                                                                  includingPropertiesForKeys: [.isRegularFileKey],
		                                                                  options: [.skipsHiddenFiles]) else {
			return []
		}
		return contents
			.filter { fileExtensions.contains($0.pathExtension.lowercased()) }
			.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
			.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
	}

	// MARK: - NSMenuDelegate

	func menuNeedsUpdate(_ menu: NSMenu) {
		menu.removeAllItems()

		let files = files()
		if files.isEmpty {
			// nil action leaves the item disabled via autoenablesItems.
			menu.addItem(NSMenuItem(title: emptyTitle, action: nil, keyEquivalent: ""))
		}

		let basenames = files.map { $0.deletingPathExtension().lastPathComponent }
		let collisions = Set(basenames.filter { name in
			basenames.filter { $0 == name }.count > 1
		})

		for url in files {
			let basename = url.deletingPathExtension().lastPathComponent
			let title = collisions.contains(basename) ? url.lastPathComponent : basename
			let item = NSMenuItem(title: title,
			                      action: selectionAction,
			                      keyEquivalent: "")
			item.target = selectionTarget
			item.representedObject = url
			menu.addItem(item)
		}

		menu.addItem(.separator())
		for trailing in trailingItems {
			let item = NSMenuItem(title: trailing.title, action: trailing.action, keyEquivalent: "")
			item.target = trailingTarget
			menu.addItem(item)
		}
	}

	// MARK: - Authoring file names (#233, #238)

	/// Turns the name typed into the Create New Template/Snippet dialog
	/// into a filename the submenu will actually list: a typed .txt or
	/// .md extension is kept (it steers the mode, same as #161; these
	/// are exactly the extensions both submenus scan for), anything
	/// else gets .txt appended. Slashes and colons become dashes — the
	/// two characters macOS filenames cannot carry. nil for a name that
	/// is empty once trimmed.
	nonisolated static func authoringFileName(from input: String) -> String? {
		let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: "/", with: "-")
			.replacingOccurrences(of: ":", with: "-")
		guard !trimmed.isEmpty else { return nil }
		let listedExtensions: Set<String> = ["txt", "md"]
		if listedExtensions.contains((trimmed as NSString).pathExtension.lowercased()) {
			return trimmed
		}
		return trimmed + ".txt"
	}

	// MARK: - Folder badge (#233, #238)

	/// "TEMPLATE" / "SNIPPET" when the file lives directly in the
	/// corresponding Application Support folder — the status-bar badge
	/// that tells editing a template master apart from editing an
	/// untitled copy made by New from Template. Folder parameters exist
	/// for tests; production callers take the defaults. Worst case of a
	/// comparison miss is a missing badge, never a wrong one.
	nonisolated static func badgeLabel(for fileURL: URL?,
	                                   templatesFolder: URL? = applicationSupportFolder(named: "Templates"),
	                                   snippetsFolder: URL? = applicationSupportFolder(named: "Snippets")) -> String? {
		guard let parent = fileURL?.deletingLastPathComponent().standardizedFileURL else {
			return nil
		}
		if parent == templatesFolder?.standardizedFileURL {
			return "TEMPLATE"
		}
		if parent == snippetsFolder?.standardizedFileURL {
			return "SNIPPET"
		}
		return nil
	}

	// Deliberately no menuHasKeyEquivalent override: AppKit then
	// populates the menu (a folder scan) during Cmd-key resolution,
	// which is what lets user-assigned App Shortcuts reach every item
	// here, including the dynamic ones. The scan is cheap — measured
	// 2026-08-18 at ~0.4 ms warm for 25 files, ~2.5 ms for 100 — so
	// blocking shortcuts to save it is a bad trade (#239).
}

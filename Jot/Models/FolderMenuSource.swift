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

	private let fileExtensions: Set<String>
	private let emptyTitle: String
	private let selectionAction: Selector
	/// nil sends selection actions down the responder chain, which also
	/// auto-disables the items when nothing responds — Insert Snippet
	/// (#162) uses this so its items dim when no editor is key.
	private weak var selectionTarget: AnyObject?
	private let openFolderTitle: String
	private let openFolderAction: Selector
	private weak var openFolderTarget: AnyObject?

	/// - Parameter fileExtensions: lowercase, without the dot.
	init(folder: URL?,
	     fileExtensions: Set<String>,
	     emptyTitle: String,
	     selectionAction: Selector,
	     selectionTarget: AnyObject?,
	     openFolderTitle: String,
	     openFolderAction: Selector,
	     openFolderTarget: AnyObject) {
		self.folder = folder
		self.fileExtensions = fileExtensions
		self.emptyTitle = emptyTitle
		self.selectionAction = selectionAction
		self.selectionTarget = selectionTarget
		self.openFolderTitle = openFolderTitle
		self.openFolderAction = openFolderAction
		self.openFolderTarget = openFolderTarget
	}

	/// App Support/Jot/<name> — the same container-relative resolution
	/// as Document.unsavedStatesFolder.
	static func applicationSupportFolder(named name: String) -> URL? {
		guard let support = try? FileManager.default.url(for: .applicationSupportDirectory,
		                                                 in: .userDomainMask,
		                                                 appropriateFor: nil,
		                                                 create: false) else {
			return nil
		}
		return support.appendingPathComponent("Jot/\(name)", isDirectory: true)
	}

	/// Visible files with a matching extension, in Finder order.
	func files() -> [URL] {
		guard let folder,
		      let contents = try? FileManager.default.contentsOfDirectory(at: folder,
		                                                                  includingPropertiesForKeys: nil,
		                                                                  options: [.skipsHiddenFiles]) else {
			return []
		}
		return contents
			.filter { fileExtensions.contains($0.pathExtension.lowercased()) }
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
		for url in files {
			let item = NSMenuItem(title: url.deletingPathExtension().lastPathComponent,
			                      action: selectionAction,
			                      keyEquivalent: "")
			item.target = selectionTarget
			item.representedObject = url
			menu.addItem(item)
		}

		menu.addItem(.separator())
		let open = NSMenuItem(title: openFolderTitle, action: openFolderAction, keyEquivalent: "")
		open.target = openFolderTarget
		menu.addItem(open)
	}

	/// No dynamic item ever has a key equivalent. Without this, AppKit
	/// falls back to menuNeedsUpdate — a folder scan — on every Cmd-key
	/// press during key-equivalent resolution.
	func menuHasKeyEquivalent(_ menu: NSMenu,
	                          for event: NSEvent,
	                          target: AutoreleasingUnsafeMutablePointer<AnyObject?>,
	                          action: UnsafeMutablePointer<Selector?>) -> Bool {
		return false
	}
}

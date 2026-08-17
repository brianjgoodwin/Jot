//
//  EditorMode.swift
//  Jot
//
//  Created by Brian on 1/27/24.
//

import Foundation
import UniformTypeIdentifiers

/// Raw values are the serialization format of the view-settings extended
/// attribute (#157) — renaming a case breaks reading existing files' xattrs.
enum EditorMode: String {
	case plainText
	case markdown

	/// Extensions that open in markdown mode. Matches the
	/// UTImportedTypeDeclarations entry in Info.plist.
	private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]

	/// Initial mode for a document (#158): markdown files open in markdown
	/// mode, everything else — including untitled documents — opens in
	/// plain text. This is only the default at open time; explicit
	/// per-document state (restoration, the planned #157 xattr) is applied
	/// afterward and wins.
	///
	/// The filename extension is the primary signal, not the UTI: there is
	/// no standard markdown UTI, and any installed app that *exports* its
	/// own (iA Writer's net.ia.markdown, say) owns what .md resolves to —
	/// Jot's imported net.daringfireball.markdown declaration is only a
	/// fallback vote in that database. Conformance is still checked second
	/// so a markdown-typed document without a URL infers correctly.
	static func inferred(fromTypeIdentifier identifier: String?, filenameExtension: String?) -> EditorMode {
		if let filenameExtension, markdownExtensions.contains(filenameExtension.lowercased()) {
			return .markdown
		}
		if let identifier,
		   let type = UTType(identifier),
		   let markdown = UTType("net.daringfireball.markdown"),
		   type.conforms(to: markdown) {
			return .markdown
		}
		return .plainText
	}
}

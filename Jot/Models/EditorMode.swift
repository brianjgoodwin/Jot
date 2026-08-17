//
//  EditorMode.swift
//  Jot
//
//  Created by Brian on 1/27/24.
//

import Foundation
import UniformTypeIdentifiers

enum EditorMode {
	case plainText
	case markdown

	/// Initial mode for a document of the given type (#158): markdown
	/// types open in markdown mode, everything else — including untitled
	/// documents — opens in plain text. This is only the default at open
	/// time; explicit per-document state (restoration, the planned #157
	/// xattr) is applied afterward and wins.
	static func inferred(fromTypeIdentifier identifier: String?) -> EditorMode {
		// The identifier matches the UTImportedTypeDeclarations entry in
		// Info.plist, which maps .md/.markdown/.mdown to it
		guard let identifier,
			  let type = UTType(identifier),
			  let markdown = UTType("net.daringfireball.markdown") else {
			return .plainText
		}
		return type.conforms(to: markdown) ? .markdown : .plainText
	}
}

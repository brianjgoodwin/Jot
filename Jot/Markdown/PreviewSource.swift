//
//  PreviewSource.swift
//  Jot
//
//  Created on 8/19/26.
//
//  What the preview window needs from an editor window (#38). A
//  protocol rather than EditorViewController directly so the tracking
//  logic is testable with stub windows -- EditorViewController only
//  exists fully wired through the storyboard, and tests must never
//  present real UI.
//

import Cocoa

@MainActor
protocol PreviewSource: AnyObject {
	/// Only markdown-mode editors are previewable; plain-text windows
	/// are invisible to the preview's tracking.
	var previewMode: EditorMode { get }
	/// The document name, for the window title and the page <title>.
	var previewTitle: String { get }
	/// The markdown to render.
	var previewMarkdown: String { get }
}

extension EditorViewController: PreviewSource {
	var previewMode: EditorMode { currentMode }

	var previewTitle: String {
		(view.window?.windowController?.document as? NSDocument)?.displayName ?? "Untitled"
	}

	var previewMarkdown: String { textView.string }
}

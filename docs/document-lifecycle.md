# Document Lifecycle

This document describes the life of a document in Jot — creation,
opening, editing, saving, and closing — at a high level rather than a
drill-down of each mechanism. Like the rest of the app it leans hard
on NSDocument: the platform owns autosave, crash recovery, the
Versions browser, and the save/close prompts. What follows is mostly
a description of what Jot adds around those defaults.

A theme to notice throughout: metadata that belongs to a file (its
text encoding, its editor mode) travels *with* the file as extended
attributes, not in a database. A lost attribute degrades to inference
— a preference is lost, never data.

## Creation (Jot/App/AppDelegate.swift)

A document is born one of four ways: an empty untitled window; New
from Template, which reads a file from the user's templates folder
into an untitled document; Insert Snippet-style capture through the
macOS Services menu, which turns selected text in another app into a
new note; and drag-and-drop of a file onto an editor window, which
opens it as a document rather than pasting its path. Untitled
documents are UTF-8 with LF line endings until told otherwise.

## Opening a File (Jot/App/Document.swift)

Opening runs a fixed sequence. First a size guard refuses anything
over 32 MB before the bytes load — plain text at that size is an
accident, and unbounded input would hang the app. Then the encoding
is worked out: a com.apple.TextEncoding extended attribute (the hint
TextEdit and Cocoa maintain) gets the first try, then UTF-8, then
UTF-16 (only with a byte-order mark), then a ladder of legacy
encodings (CP1252, Latin-1, macOS Roman). The winning encoding is
remembered so the file can be saved back the same way.

After decoding, a UTF-8 byte-order mark is stripped from the buffer
(and re-added on save), the file's line-ending convention is detected
and remembered, and the buffer is normalized to LF — the editor never
holds mixed line endings. Finally, the document's editor mode is read
from its view-settings extended attribute if the user ever chose one,
otherwise inferred from the file type.

## The Editor Window (Jot/App/Document.swift)

makeWindowControllers instantiates the window, applies the initial
mode, and hands the text to the editor. Additional windows currently
stack on the first rather than cascading.

## Editing (Jot/Editor/EditorViewController.swift)

While editing, the live text belongs to the text view; the document's
copy is synced from it on a debounce and — critically — re-synced by
every path that serializes the document. NSDocument tracks edited
state and runs autosave on its own schedule. There is no hand-rolled
unsaved-changes machinery; an earlier subsystem for that was deleted
in favor of the platform's.

## Saving (Jot/App/Document.swift)

Every save route — Cmd-S, autosave, close, quit — funnels through one
method, data(ofType:), which reverses the transformations made on
open: sync the latest text from the editor, restore the original
line-ending convention, re-add the byte-order mark if the file had
one, and encode in the encoding the file arrived with. If the user
typed characters the original encoding cannot hold (a CP1252 file
gaining an emoji), the save fails with an explicit offer to convert
to UTF-8 — never a silent conversion.

The encoding and view-settings extended attributes are written as
part of the atomic safe-save itself, so they survive the file swap.

## Mode Changes (Jot/App/Document.swift)

When the user explicitly switches a document between plain text and
markdown, the choice is written to the view-settings attribute
immediately — without marking the document edited, because a view
toggle must not create an Edited state or a Versions entry. Every
subsequent save re-applies the attribute, so a failed immediate write
still reaches disk eventually.

## Revert and Versions (Jot/App/Document.swift)

Revert to Saved rereads the file through the normal open path, which
also refreshes the mode from the file's attribute. The Versions
browser's Restore keeps the live file's extended attributes (that is
how the platform behaves — file content is restored, xattrs stay),
so a document's mode and encoding survive a restore.

## Window Restoration (Jot/Editor/EditorViewController.swift)

On relaunch, macOS reopens the windows that were open at quit. The
editor encodes its mode, zoom, selection, and scroll position into
the restoration state and applies them when the window returns — so
a restored window looks identical to the one that was closed.
Restoration state wins over the mode the document would otherwise
open with.

Testing restoration has two traps that make it look broken when it
isn't (#198). First, a second running Jot instance — a dev build
alongside the installed copy, or two dev builds — makes AppKit
permanently stop saving state for those processes, even after the
other instance quits; every quit then writes nothing, so the next
launch restores nothing. Second, Xcode's stop button kills the
process without a state write. Restoration can only be tested with
a single instance launched from Finder and quit with Cmd-Q.

## Printing (Jot/App/Document.swift)

Printing the editor builds an offscreen text view sized to the page
content area, using the user's editor font, so wrapping and
pagination follow the paper size. (The markdown preview prints
separately, through its own pipeline — see architecture.md.)

## Duplication (Jot/App/Document.swift)

Duplicate carries the mode override in memory only; it reaches disk
when the duplicate is first saved. Everything else follows the
platform's duplicate behavior.

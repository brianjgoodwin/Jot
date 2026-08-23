# Jot Architecture

This document gives a high level description of the Jot codebase rather
than a detailed drill-down of each internal mechanism. It is a map for
re-orientation after time away, not a reference.

Jot is a macOS text editor built entirely with AppKit — no SwiftUI. The
UI is migrating from storyboards to programmatic windows; new windows
are built in code, and storyboard scenes are removed as their windows
are rebuilt.

One fact worth knowing up front: Jot contains **two separate markdown
engines** that never share code. The editor styles markdown with
regular expressions directly in the text view (fast enough per
keystroke, measured in a spike). The preview parses markdown into a
real syntax tree with Apple's swift-markdown and renders HTML. They
are different tools for different jobs, and keeping them separate is
deliberate.

## Document (Jot/App/Document.swift)

The NSDocument subclass behind every editor window. Owns file reading
and writing, text encoding detection and recovery (with a consent
dialog for non-UTF-8 files), line-ending preservation, printing,
duplication, and an input-size guard against absurdly large files.
Also persists per-document view settings (like editor mode) as
extended attributes on the file, so a document remembers its own
settings without a database.

## App Delegate (Jot/App/AppDelegate.swift)

Application-level glue: the main menu, macOS Services integration,
New from Template and Insert Snippet (both driven by folders of plain
text files), and ownership of single-instance windows like the
markdown preview.

## Editor (Jot/Editor/EditorViewController.swift)

The heart of the app: one instance per document window. Manages the
text view, mode switching (plain text vs markdown), font handling,
word wrap, state restoration, and all the markdown editing commands
(bold/italic toggles, checklists, list continuation on Return).
EditorTextView.swift is a small NSTextView subclass that opens dropped
files as documents instead of pasting their paths.

## Editor Markdown Styling (Jot/Markdown/MarkdownProcessor.swift)

Applies visual styling (headings, bold, italic, code, links, lists,
blockquotes, tables) to the editor's text storage using regular
expressions. Runs on the visible range for speed. This is styling,
not parsing — it decorates the text the user is editing without
changing it. ListMarker.swift parses list markers at the start of a
line, shared by list continuation and the checklist commands.

## Line Number Gutter (Jot/Editor/LineNumberGutter.swift)

Line numbers built on NSRulerView. The geometry is owned by a custom
clip view that enforces the ruler inset on every frame change, so the
text container width can never drift out of sync with the gutter.

## Markdown Preview (Jot/Markdown/PreviewWindowController.swift)

A single programmatic window (the app delegate holds one instance)
that shows rendered markdown in a WKWebView. It follows the frontmost
markdown document, re-renders after a typing lull, and idles while
occluded. The HTML shell loads once per document; later updates swap
only the body, so re-renders never flash or lose scroll position.
Printing renders through a dedicated offscreen web view sized to the
page. PreviewSource.swift is the protocol the preview uses to talk to
editor windows, so the tracking logic is testable without real UI.

## HTML Rendering (Jot/Markdown/MarkdownHTMLRenderer.swift)

Converts markdown text to HTML for the preview. Parses with Apple's
swift-markdown, then walks the syntax tree emitting HTML. Raw HTML in
the source is always escaped and shown as literal text, which closes
the script-injection path by construction. Link and image URLs pass
scheme allowlists. Highlighting (==text==) and footnotes ([^1]) are
implemented as pre- and post-processing around the parser, which has
no syntax for them. PreviewShell.swift wraps the rendered body in a
full HTML document (Content Security Policy, language tag, theme CSS),
and PreviewTheme.swift holds the CSS, including dark mode, high
contrast, and print styles.

## Preferences (Jot/Models/PreferencesManager.swift)

Centralized UserDefaults access — one place for every preference key.
Tests always use isolated throwaway suites, never the real domain.

## Utility Windows (Jot/Windows/)

Programmatic single-purpose windows: Settings, the floating word count
panel (tracks the active editor), Help (a WKWebView showing bundled
content), About, and a read-only Acknowledgements viewer.

## Supporting Models (Jot/Models/)

Small, mostly pure types: TextStatistics (word/character counts),
LineEnding (the newline convention a file arrived with — the editor
buffer is always normalized to \n and the original convention is
restored at save), EditorMode (whose raw values are a serialization
format — renaming a case breaks existing files' extended attributes),
SnippetExpansion (variable substitution for snippets, pure and
injectable for tests), FolderMenuSource (fills a menu from a folder of
files — the file system is the management UI), and PerformanceLog
(signpost markers for Instruments; see docs/PERFORMANCE.md).

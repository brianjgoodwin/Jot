//
//  EditorTextView.swift
//  Jot
//
//  NSTextView subclass that intercepts file drops and opens them
//  as documents instead of inserting the file path as text.
//

import Cocoa
import UniformTypeIdentifiers

class EditorTextView: NSTextView {

    // UTIs the app can open, matching Info.plist declarations.
    private static let supportedTypeIdentifiers: [String] = [
        "public.plain-text",
        "net.daringfireball.markdown",
        "public.source-code",
    ]

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let urls = extractFileURLs(from: sender.draggingPasteboard) {
            return supportedFileURLs(from: urls).isEmpty ? NSDragOperation() : .copy
        }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let urls = extractFileURLs(from: sender.draggingPasteboard) {
            return supportedFileURLs(from: urls).isEmpty ? NSDragOperation() : .copy
        }
        return super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = extractFileURLs(from: sender.draggingPasteboard) else {
            // Not a file drop -- let NSTextView handle text drags
            return super.performDragOperation(sender)
        }

        let supported = supportedFileURLs(from: urls)
        if supported.isEmpty {
            return false
        }

        let documentController = NSDocumentController.shared
        for url in supported {
            documentController.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
        return true
    }

    // MARK: - Paste URL as link (#145)

    override func paste(_ sender: Any?) {
        if pasteURLOverSelectionAsMarkdownLink() { return }
        super.paste(sender)
    }

    /// With text selected in markdown mode, pasting a URL wraps the
    /// selection as a markdown link instead of replacing it. Every other
    /// case falls through to a normal paste, and Paste and Match Style is
    /// untouched, so plain replacement stays one shortcut away.
    private func pasteURLOverSelectionAsMarkdownLink() -> Bool {
        guard (delegate as? EditorViewController)?.currentMode == .markdown else { return false }
        let selectedRange = self.selectedRange()
        guard selectedRange.length > 0 else { return false }
        guard let pasted = NSPasteboard.general.string(forType: .string) else { return false }

        let selectedText = (string as NSString).substring(with: selectedRange)
        guard let replacement = EditorTextView.markdownLink(wrapping: selectedText, around: pasted) else {
            return false
        }
        insertText(replacement, replacementRange: selectedRange)
        return true
    }

    /// `"[selection](url)"` when `pasted` is a lone http(s) URL and the
    /// selection can serve as link text; nil means "do a normal paste".
    /// Static and pure so the decision is directly testable.
    static func markdownLink(wrapping selection: String, around pasted: String) -> String? {
        // A copied URL often arrives with a trailing newline; anything with
        // interior whitespace is prose, not a URL.
        let candidate = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              candidate.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }

        // A selection that is already a markdown link gets replaced like a
        // normal paste instead of double-wrapped.
        if selection.hasPrefix("["), selection.hasSuffix(")"), selection.contains("](") {
            return nil
        }
        // Link text can't span lines; wrapping would produce broken syntax.
        if selection.rangeOfCharacter(from: .newlines) != nil {
            return nil
        }
        // Unbalanced brackets in the selection corrupt the link too:
        // "a] b" would become "[a] b](url)" and end the link text at "a".
        // Balanced pairs are fine — CommonMark allows them in link text.
        var bracketDepth = 0
        for character in selection {
            if character == "[" { bracketDepth += 1 }
            if character == "]" { bracketDepth -= 1 }
            if bracketDepth < 0 { return nil }
        }
        if bracketDepth != 0 { return nil }
        return "[\(selection)](\(candidate))"
    }

    // MARK: - Helpers

    private func extractFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty else {
            return nil
        }
        return urls
    }

    private func supportedFileURLs(from urls: [URL]) -> [URL] {
        return urls.filter { url in
            guard let uti = utiForURL(url) else { return false }
            return EditorTextView.isSupportedUTI(uti)
        }
    }

    private static func isSupportedUTI(_ uti: String) -> Bool {
        if #available(macOS 11.0, *) {
            guard let type = UTType(uti) else { return false }
            return supportedTypeIdentifiers.contains { identifier in
                guard let supported = UTType(identifier) else { return false }
                return type.conforms(to: supported)
            }
        } else {
            return supportedTypeIdentifiers.contains { identifier in
                UTTypeConformsTo(uti as CFString, identifier as CFString)
            }
        }
    }

    private func utiForURL(_ url: URL) -> String? {
        guard let resourceValues = try? url.resourceValues(forKeys: [.typeIdentifierKey]) else {
            return nil
        }
        return resourceValues.typeIdentifier
    }
}

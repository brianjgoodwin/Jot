//
//  EditorTextView.swift
//  Jot
//
//  NSTextView subclass that intercepts file drops and opens them
//  as documents instead of inserting the file path as text.
//

import Cocoa

class EditorTextView: NSTextView {

    // UTIs the app can open, matching Info.plist declarations.
    private static let supportedTypes: [CFString] = [
        kUTTypePlainText,
        "net.daringfireball.markdown" as CFString,
        kUTTypeSourceCode,
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

    // MARK: - Helpers

    private func extractFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        guard let items = pasteboard.pasteboardItems else { return nil }

        var fileURLs: [URL] = []
        for item in items {
            // Try the modern fileURL type first, then fall back to filenames
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString),
               url.isFileURL {
                fileURLs.append(url)
            }
        }

        // Fall back to the deprecated but reliable filenames pasteboard type
        if fileURLs.isEmpty,
           let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            fileURLs = filenames.map { URL(fileURLWithPath: $0) }
        }

        return fileURLs.isEmpty ? nil : fileURLs
    }

    private func supportedFileURLs(from urls: [URL]) -> [URL] {
        return urls.filter { url in
            guard let uti = utiForURL(url) else { return false }
            return EditorTextView.supportedTypes.contains { supportedUTI in
                UTTypeConformsTo(uti as CFString, supportedUTI)
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

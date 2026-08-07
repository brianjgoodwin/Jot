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

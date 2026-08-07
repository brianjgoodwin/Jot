//
//  AcknowledgementsWindowController.swift
//  Jot
//
//  Read-only in-app viewer for Acknowledgements.txt. Opening the file
//  externally sent it to an editor as an editable document whose save
//  would always fail (the signed bundle is read-only).
//

import Cocoa

@MainActor
class AcknowledgementsWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Acknowledgements"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupContentView()
    }

    private func setupContentView() {
        guard let window = window else { return }

        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let font: NSFont
        if #available(macOS 11.0, *) {
            font = NSFont.preferredFont(forTextStyle: .body)
        } else {
            font = NSFont.systemFont(ofSize: 13)
        }

        textView.isEditable = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.font = font
        textView.setAccessibilityLabel("Acknowledgements")

        let contents: String
        if let url = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt"),
           let loaded = try? String(contentsOf: url, encoding: .utf8) {
            contents = loaded
        } else {
            contents = "Acknowledgements are unavailable."
        }
        textView.string = contents

        // The file is hard-wrapped, so size the window to its longest line
        // to avoid ugly mid-line rewrapping (clamped to a sane maximum)
        let longestLineWidth = contents.components(separatedBy: .newlines)
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        // Covers the text container's line-fragment padding plus a legacy
        // (always-visible) scroller, so the longest line never quite wraps
        let scrollerAllowance: CGFloat = 30
        let contentWidth = min(longestLineWidth + textView.textContainerInset.width * 2 + scrollerAllowance, 800)
        window.setContentSize(NSSize(width: ceil(contentWidth), height: 400))
        window.center()

        window.contentView = scrollView
    }
}

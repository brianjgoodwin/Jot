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

        textView.isEditable = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        if #available(macOS 11.0, *) {
            textView.font = NSFont.preferredFont(forTextStyle: .body)
        } else {
            textView.font = NSFont.systemFont(ofSize: 13)
        }
        textView.setAccessibilityLabel("Acknowledgements")

        if let url = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            textView.string = contents
        } else {
            textView.string = "Acknowledgements are unavailable."
        }

        window.contentView = scrollView
    }
}

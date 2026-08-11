//
//  SettingsPanelController.swift
//  Jot
//
//  Created on 8/9/26.
//
//  Programmatic Settings window -- no storyboard required.
//  Font selection uses the system NSFontPanel.
//

import Cocoa

@MainActor
class SettingsPanelController: NSWindowController, NSWindowDelegate {

    private var fontPreviewLabel: NSTextField!
    private var lineNumbersPopup: NSPopUpButton!
    private var remoteImagesPopup: NSPopUpButton!

    // MARK: - Initialization

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
        setupContentView()
        loadCurrentValues()
    }

    @objc private func fontConfigurationDidChange(_ notification: Notification) {
        updateFontPreview(FontConfiguration.shared.resolvedFont())
    }

    @objc private func showLineNumbersDidChange(_ notification: Notification) {
        // The View menu can flip the preference while this panel is open;
        // the popup has to follow or it becomes a second source of truth —
        // the exact disease #106 is about.
        // The popup only exists after setupContentView(), which only
        // convenience init() calls — a panel built via init(window:) or
        // init?(coder:) observes this notification with no popup to
        // update, and the implicit unwrap would crash it (#178).
        guard let popup = lineNumbersPopup else { return }
        popup.selectItem(withTitle: PreferencesManager.shared.showLineNumbers ? "On" : "Off")
    }

    /// Registered from every initializer, not just convenience init(): a
    /// panel built through init(window:) or init?(coder:) would otherwise
    /// have a preview that silently never updates, hidden by the
    /// loadCurrentValues() call in showWindow (#124).
    private func observeSharedState() {
        // Keep the preview current when the font changes from anywhere,
        // not just this panel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fontConfigurationDidChange),
            name: FontConfiguration.didChangeNotification,
            object: FontConfiguration.shared
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showLineNumbersDidChange),
            name: PreferencesManager.showLineNumbersDidChangeNotification,
            object: nil
        )
    }

    override init(window: NSWindow?) {
        super.init(window: window)
        observeSharedState()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeSharedState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - View Setup

    private func setupContentView() {
        guard let contentView = window?.contentView else { return }

        let margin: CGFloat = 20
        let rowSpacing: CGFloat = 12
        // Fixed window width; height comes from fittingSize below
        let contentWidth: CGFloat = 280

        // Font row
        let fontLabel = makeLabel("Font:")
        fontLabel.setAccessibilityLabel("Font")

        fontPreviewLabel = makeLabel("")
        fontPreviewLabel.lineBreakMode = .byTruncatingTail
        fontPreviewLabel.setAccessibilityLabel("Current font")

        let fontButton = NSButton(title: "Choose\u{2026}", target: self, action: #selector(showFontPanel(_:)))
        fontButton.translatesAutoresizingMaskIntoConstraints = false
        fontButton.bezelStyle = .rounded
        fontButton.setAccessibilityLabel("Choose font")

        // Line numbers row. The visible and accessibility labels match
        // deliberately: the old branch's a11y label added a "for new
        // editors" caveat sighted users never saw (#106). The setting is
        // live-global now, so there is no caveat to admit.
        let lineNumbersLabel = makeLabel("Line numbers:")
        lineNumbersLabel.setAccessibilityLabel("Line numbers")

        lineNumbersPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        lineNumbersPopup.translatesAutoresizingMaskIntoConstraints = false
        lineNumbersPopup.addItems(withTitles: ["On", "Off"])
        lineNumbersPopup.target = self
        lineNumbersPopup.action = #selector(lineNumbersChanged(_:))
        lineNumbersPopup.setAccessibilityLabel("Line numbers")

        // Remote images row
        let remoteImagesLabel = makeLabel("Remote images:")
        remoteImagesLabel.setAccessibilityLabel("Remote images in preview")

        remoteImagesPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        remoteImagesPopup.translatesAutoresizingMaskIntoConstraints = false
        remoteImagesPopup.addItems(withTitles: ["On", "Off"])
        remoteImagesPopup.target = self
        remoteImagesPopup.action = #selector(remoteImagesChanged(_:))
        remoteImagesPopup.setAccessibilityLabel("Remote images in preview")

        let remoteImagesNote = makeLabel("When off, preview blocks remote images to prevent tracking.")
        remoteImagesNote.font = NSFont.preferredFont(forTextStyle: .footnote)
        remoteImagesNote.textColor = .secondaryLabelColor
        remoteImagesNote.lineBreakMode = .byWordWrapping
        remoteImagesNote.maximumNumberOfLines = 0
        remoteImagesNote.preferredMaxLayoutWidth = contentWidth - margin * 2

        contentView.addSubview(fontLabel)
        contentView.addSubview(fontPreviewLabel)
        contentView.addSubview(fontButton)
        contentView.addSubview(lineNumbersLabel)
        contentView.addSubview(lineNumbersPopup)
        contentView.addSubview(remoteImagesLabel)
        contentView.addSubview(remoteImagesPopup)
        contentView.addSubview(remoteImagesNote)

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: contentWidth),

            // Font label
            fontLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin),
            fontLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            // Font preview -- right of label, left of button
            fontPreviewLabel.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontPreviewLabel.leadingAnchor.constraint(equalTo: fontLabel.trailingAnchor, constant: 8),
            fontPreviewLabel.trailingAnchor.constraint(lessThanOrEqualTo: fontButton.leadingAnchor, constant: -8),

            // Font button
            fontButton.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),

            // Line numbers label
            lineNumbersLabel.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: rowSpacing * 2),
            lineNumbersLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            // Line numbers popup
            lineNumbersPopup.centerYAnchor.constraint(equalTo: lineNumbersLabel.centerYAnchor),
            lineNumbersPopup.leadingAnchor.constraint(equalTo: lineNumbersLabel.trailingAnchor, constant: 8),

            // Remote images label
            remoteImagesLabel.topAnchor.constraint(equalTo: lineNumbersLabel.bottomAnchor, constant: rowSpacing * 2),
            remoteImagesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            // Remote images popup
            remoteImagesPopup.centerYAnchor.constraint(equalTo: remoteImagesLabel.centerYAnchor),
            remoteImagesPopup.leadingAnchor.constraint(equalTo: remoteImagesLabel.trailingAnchor, constant: 8),

            // Remote images note
            remoteImagesNote.topAnchor.constraint(equalTo: remoteImagesLabel.bottomAnchor, constant: 4),
            remoteImagesNote.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            remoteImagesNote.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),

            // Bottom pin
            remoteImagesNote.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -margin),
        ])

        // Size the window to the remaining rows instead of the fixed
        // initial contentRect height
        window?.setContentSize(contentView.fittingSize)
    }

    // MARK: - Load Current Values

    private func loadCurrentValues() {
        let fontConfig = FontConfiguration.shared
        updateFontPreview(fontConfig.currentFont)
        lineNumbersPopup.selectItem(withTitle: PreferencesManager.shared.showLineNumbers ? "On" : "Off")
        remoteImagesPopup.selectItem(withTitle: PreferencesManager.shared.loadRemoteImages ? "On" : "Off")
    }

    private func updateFontPreview(_ font: NSFont) {
        // Same shape as showLineNumbersDidChange: reachable from the
        // font-change observer on panels that never ran setupContentView()
        guard fontPreviewLabel != nil else { return }
        let displayName = font.displayName ?? font.fontName
        let size = Int(font.pointSize)
        fontPreviewLabel.stringValue = "\(displayName), \(size) pt"
        fontPreviewLabel.font = NSFont(descriptor: font.fontDescriptor, size: 13)
            ?? NSFont.systemFont(ofSize: 13)
    }

    // MARK: - Actions

    @objc private func showFontPanel(_ sender: Any) {
        let fontManager = NSFontManager.shared
        let fontConfig = FontConfiguration.shared
        fontManager.setSelectedFont(fontConfig.currentFont, isMultiple: false)
        fontManager.target = self
        fontManager.action = #selector(changeFontFromPanel(_:))
        fontManager.orderFrontFontPanel(sender)
    }

    @objc private func changeFontFromPanel(_ sender: NSFontManager) {
        let currentFont = FontConfiguration.shared.currentFont
        let newFont = sender.convert(currentFont)

        // Write the shared configuration directly: persistence no longer
        // depends on an editor window being open, and the change
        // notification reaches every window (#124). The preview label
        // updates via the same notification.
        FontConfiguration.shared.applyFont(newFont)
    }

    @objc private func lineNumbersChanged(_ sender: NSPopUpButton) {
        // The preference setter broadcasts the change; open editors and
        // the View menu title follow from there (#106)
        PreferencesManager.shared.showLineNumbers = (sender.titleOfSelectedItem == "On")
    }

    @objc private func remoteImagesChanged(_ sender: NSPopUpButton) {
        PreferencesManager.shared.loadRemoteImages = (sender.titleOfSelectedItem == "On")
    }

    // MARK: - Window Lifecycle

    override func showWindow(_ sender: Any?) {
        loadCurrentValues()
        super.showWindow(sender)
    }

    func windowWillClose(_ notification: Notification) {
        let fontManager = NSFontManager.shared
        if fontManager.target === self {
            fontManager.target = nil
        }
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false

        label.font = NSFont.preferredFont(forTextStyle: .body)

        return label
    }
}

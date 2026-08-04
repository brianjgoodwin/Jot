//
//  SettingsPanelController.swift
//  Jot
//
//  Programmatic Settings window -- no storyboard required.
//  Font selection uses the system NSFontPanel.
//

import Cocoa

@MainActor protocol TextSettingsDelegate: AnyObject {
    func didSelectFont(_ font: NSFont)
    func didSelectFontSize(_ fontSize: CGFloat)
    func currentFontSize() -> CGFloat
}

@MainActor
class SettingsPanelController: NSWindowController, NSWindowDelegate {

    private var fontPreviewLabel: NSTextField!
    private var autosavePopup: NSPopUpButton!
    private var lineNumbersPopup: NSPopUpButton!
    private var remoteImagesPopup: NSPopUpButton!

    weak var delegate: TextSettingsDelegate?

    // MARK: - Initialization

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 260),
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

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - View Setup

    private func setupContentView() {
        guard let contentView = window?.contentView else { return }

        let margin: CGFloat = 20
        let rowSpacing: CGFloat = 12

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

        // Autosave row
        let autosaveLabel = makeLabel("Autosave:")
        autosaveLabel.setAccessibilityLabel("Autosave")

        autosavePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        autosavePopup.translatesAutoresizingMaskIntoConstraints = false
        autosavePopup.addItems(withTitles: ["On", "Off"])
        autosavePopup.target = self
        autosavePopup.action = #selector(autosaveChanged(_:))
        autosavePopup.setAccessibilityLabel("Autosave")

        // Line numbers row
        let lineNumbersLabel = makeLabel("Line numbers:")
        lineNumbersLabel.setAccessibilityLabel("Line numbers for new editors")

        lineNumbersPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        lineNumbersPopup.translatesAutoresizingMaskIntoConstraints = false
        lineNumbersPopup.addItems(withTitles: ["On", "Off"])
        lineNumbersPopup.target = self
        lineNumbersPopup.action = #selector(lineNumbersChanged(_:))
        lineNumbersPopup.setAccessibilityLabel("Line numbers for new editors")

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
        remoteImagesNote.font = NSFont.systemFont(ofSize: 10)
        remoteImagesNote.textColor = .secondaryLabelColor
        remoteImagesNote.lineBreakMode = .byWordWrapping
        remoteImagesNote.maximumNumberOfLines = 2
        remoteImagesNote.preferredMaxLayoutWidth = 240

        contentView.addSubview(fontLabel)
        contentView.addSubview(fontPreviewLabel)
        contentView.addSubview(fontButton)
        contentView.addSubview(autosaveLabel)
        contentView.addSubview(autosavePopup)
        contentView.addSubview(lineNumbersLabel)
        contentView.addSubview(lineNumbersPopup)
        contentView.addSubview(remoteImagesLabel)
        contentView.addSubview(remoteImagesPopup)
        contentView.addSubview(remoteImagesNote)

        NSLayoutConstraint.activate([
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

            // Autosave label
            autosaveLabel.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: rowSpacing * 2),
            autosaveLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            // Autosave popup
            autosavePopup.centerYAnchor.constraint(equalTo: autosaveLabel.centerYAnchor),
            autosavePopup.leadingAnchor.constraint(equalTo: autosaveLabel.trailingAnchor, constant: 8),

            // Line numbers label
            lineNumbersLabel.topAnchor.constraint(equalTo: autosaveLabel.bottomAnchor, constant: rowSpacing * 2),
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
    }

    // MARK: - Load Current Values

    private func loadCurrentValues() {
        let fontConfig = FontConfiguration.shared
        updateFontPreview(fontConfig.currentFont)
        autosavePopup.selectItem(withTitle: PreferencesManager.shared.autosaveEnabled ? "On" : "Off")
        lineNumbersPopup.selectItem(withTitle: PreferencesManager.shared.showLineNumbers ? "On" : "Off")
        remoteImagesPopup.selectItem(withTitle: PreferencesManager.shared.loadRemoteImages ? "On" : "Off")
    }

    private func updateFontPreview(_ font: NSFont) {
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

        delegate?.didSelectFont(newFont)
        delegate?.didSelectFontSize(newFont.pointSize)
        updateFontPreview(newFont)
    }

    @objc private func autosaveChanged(_ sender: NSPopUpButton) {
        PreferencesManager.shared.autosaveEnabled = (sender.titleOfSelectedItem == "On")
    }

    @objc private func lineNumbersChanged(_ sender: NSPopUpButton) {
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

        if #available(macOS 11.0, *) {
            label.font = NSFont.preferredFont(forTextStyle: .body)
        } else {
            label.font = NSFont.systemFont(ofSize: 13)
        }

        return label
    }
}

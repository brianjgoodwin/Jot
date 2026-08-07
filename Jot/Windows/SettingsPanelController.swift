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
    private var remoteImagesPopup: NSPopUpButton!

    weak var delegate: TextSettingsDelegate?

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

            // Remote images label
            remoteImagesLabel.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: rowSpacing * 2),
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

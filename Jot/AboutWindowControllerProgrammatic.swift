//
//  AboutWindowControllerProgrammatic.swift
//  Jot
//
//  Programmatic About window -- no storyboard required.
//

import Cocoa

class AboutWindowControllerProgrammatic: NSWindowController {

	// MARK: - Initialization

	convenience init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)

		window.title = "About"
		window.titlebarAppearsTransparent = true
		window.center()
		window.isReleasedWhenClosed = false

		self.init(window: window)
		setupContentView()
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

		let iconImageView = NSImageView()
		iconImageView.translatesAutoresizingMaskIntoConstraints = false
		iconImageView.imageScaling = .scaleProportionallyDown
		iconImageView.image = NSImage(named: "icon_256")
		iconImageView.setAccessibilityLabel("Jot application icon")

		let appNameLabel = makeLabel("Jot - Text Editor", size: 24)
		let versionLabel = makeLabel(versionString(), size: 14)
		let copyrightLabel = makeLabel(copyrightString(), size: 14)

		contentView.addSubview(iconImageView)
		contentView.addSubview(appNameLabel)
		contentView.addSubview(versionLabel)
		contentView.addSubview(copyrightLabel)

		NSLayoutConstraint.activate([
			appNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
			appNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

			versionLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 8),
			versionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

			iconImageView.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 4),
			iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
			iconImageView.widthAnchor.constraint(equalToConstant: 256),
			iconImageView.heightAnchor.constraint(equalToConstant: 128),

			copyrightLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
			copyrightLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
			copyrightLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
		])
	}

	// MARK: - Helpers

	private func makeLabel(_ text: String, size: CGFloat) -> NSTextField {
		let label = NSTextField(labelWithString: text)
		label.translatesAutoresizingMaskIntoConstraints = false
		label.alignment = .center
		label.isBezeled = false
		label.drawsBackground = false
		label.isEditable = false
		label.isSelectable = false
		if #available(macOS 11.0, *) {
			label.font = NSFont.preferredFont(forTextStyle: size >= 24 ? .title1 : .body)
		} else {
			label.font = NSFont.systemFont(ofSize: size)
		}
		return label
	}

	private func versionString() -> String {
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
		return "Version \(version)"
	}

	private func copyrightString() -> String {
		let year = Calendar.current.component(.year, from: Date())
		return "Copyright \u{00A9} Brian Goodwin 2023-\(year)"
	}
}

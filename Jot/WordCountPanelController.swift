//
//  WordCountPanelController.swift
//  Jot
//
//  Programmatic floating utility panel for word count and
//  text statistics. Tracks the active editor window.
//

import Cocoa

@MainActor
class WordCountPanelController: NSWindowController {

    // MARK: - Notification

    static let textDidChangeNotification = Notification.Name("WordCountPanelTextDidChange")

    // MARK: - Labels

    private var documentNameLabel: NSTextField!
    private var wordsValueLabel: NSTextField!
    private var charsValueLabel: NSTextField!
    private var charsNoSpacesValueLabel: NSTextField!
    private var linesValueLabel: NSTextField!
    private var paragraphsValueLabel: NSTextField!
    private var readingTimeValueLabel: NSTextField!
    private var fileSizeValueLabel: NSTextField!

    private var updateTimer: Timer?

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    // MARK: - Initialization

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 260),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "Word Count"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.center()

        // Utility panels should not take key from the editor
        panel.level = .floating

        self.init(window: panel)
        setupContentView()
        startObserving()
    }

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Observation

    private func startObserving() {
        let nc = NotificationCenter.default

        // Track text changes from editors
        nc.addObserver(
            self,
            selector: #selector(handleTextDidChange(_:)),
            name: WordCountPanelController.textDidChangeNotification,
            object: nil
        )

        // Track active window changes to update document name and stats
        nc.addObserver(
            self,
            selector: #selector(handleMainWindowChanged(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }

    @objc private func handleTextDidChange(_ notification: Notification) {
        // Debounce updates
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.updateFromActiveWindow()
        }
    }

    @objc private func handleMainWindowChanged(_ notification: Notification) {
        updateFromActiveWindow()
    }

    // MARK: - Update

    private func updateFromActiveWindow() {
        guard window?.isVisible == true else { return }

        guard let mainWindow = NSApp.mainWindow,
              let vc = mainWindow.contentViewController as? ViewController else {
            updateDisplay(documentName: "No Document", text: "")
            return
        }

        let documentName: String
        if let doc = mainWindow.windowController?.document as? NSDocument {
            documentName = doc.displayName ?? "Untitled"
        } else {
            documentName = "Untitled"
        }

        updateDisplay(documentName: documentName, text: vc.textView.string)
    }

    private func updateDisplay(documentName: String, text: String) {
        let stats = TextStatistics(text: text)

        documentNameLabel.stringValue = documentName

        wordsValueLabel.stringValue = formatted(stats.wordCount)
        charsValueLabel.stringValue = formatted(stats.characterCount)
        charsNoSpacesValueLabel.stringValue = formatted(stats.characterCountNoSpaces)
        linesValueLabel.stringValue = formatted(stats.lineCount)
        paragraphsValueLabel.stringValue = formatted(stats.paragraphCount)
        readingTimeValueLabel.stringValue = stats.readingTimeString
        fileSizeValueLabel.stringValue = stats.fileSizeString
    }

    private func formatted(_ value: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Show

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        updateFromActiveWindow()
    }

    // MARK: - View Setup

    private func setupContentView() {
        guard let contentView = window?.contentView else { return }

        // Document name at the top
        documentNameLabel = makeLabel("Untitled", style: .headline)
        documentNameLabel.lineBreakMode = .byTruncatingMiddle
        documentNameLabel.setAccessibilityLabel("Document name")
        contentView.addSubview(documentNameLabel)

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        contentView.addSubview(separator)

        // Stat rows
        let rows: [(String, String)] = [
            ("Words", "Word count"),
            ("Characters", "Character count"),
            ("Characters (no spaces)", "Character count excluding spaces"),
            ("Lines", "Line count"),
            ("Paragraphs", "Paragraph count"),
            ("Reading Time", "Estimated reading time"),
            ("File Size", "File size"),
        ]

        var valueLabels: [NSTextField] = []
        var rowViews: [NSView] = []

        for (title, accessibilityLabel) in rows {
            let (row, valueLabel) = makeStatRow(title: title, accessibilityLabel: accessibilityLabel)
            contentView.addSubview(row)
            valueLabels.append(valueLabel)
            rowViews.append(row)
        }

        wordsValueLabel = valueLabels[0]
        charsValueLabel = valueLabels[1]
        charsNoSpacesValueLabel = valueLabels[2]
        linesValueLabel = valueLabels[3]
        paragraphsValueLabel = valueLabels[4]
        readingTimeValueLabel = valueLabels[5]
        fileSizeValueLabel = valueLabels[6]

        // Layout
        let margin: CGFloat = 16
        let rowSpacing: CGFloat = 6

        var constraints = [
            documentNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            documentNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            documentNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),

            separator.topAnchor.constraint(equalTo: documentNameLabel.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
        ]

        var previousAnchor = separator.bottomAnchor
        for row in rowViews {
            constraints.append(row.topAnchor.constraint(equalTo: previousAnchor, constant: rowSpacing))
            constraints.append(row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin))
            constraints.append(row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin))
            previousAnchor = row.bottomAnchor
        }

        // Pin the last row to the bottom
        constraints.append(previousAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12))

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Helpers

    private func makeStatRow(title: String, accessibilityLabel: String) -> (NSView, NSTextField) {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = makeLabel(title, style: .body)
        titleLabel.textColor = .secondaryLabelColor

        let valueLabel = makeLabel("0", style: .body)
        valueLabel.alignment = .right
        valueLabel.setAccessibilityLabel(accessibilityLabel)

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),

            container.heightAnchor.constraint(equalTo: titleLabel.heightAnchor),
        ])

        return (container, valueLabel)
    }

    private func makeLabel(_ text: String, style: LabelStyle) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false

        if #available(macOS 11.0, *) {
            switch style {
            case .headline:
                label.font = NSFont.preferredFont(forTextStyle: .headline)
            case .body:
                label.font = NSFont.preferredFont(forTextStyle: .body)
            }
        } else {
            switch style {
            case .headline:
                label.font = NSFont.boldSystemFont(ofSize: 13)
            case .body:
                label.font = NSFont.systemFont(ofSize: 13)
            }
        }

        return label
    }

    private enum LabelStyle {
        case headline
        case body
    }
}

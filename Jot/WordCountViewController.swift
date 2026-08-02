//
//  WordCountViewController.swift
//  Jot
//
//  Created by Brian on 1/8/24.
//

import Cocoa

class WordCountViewController: NSViewController {

    private var textContent: String = ""

    @IBOutlet var wordCountDisplay: NSTextField!
    @IBOutlet var paragraphCountDisplay: NSTextField!
    @IBOutlet var fileSizeDisplay: NSTextField!

    override func viewWillAppear() {
        super.viewWillAppear()
        configureAccessibility()
        updateStatisticsDisplay()
    }

    private func configureAccessibility() {
        wordCountDisplay?.setAccessibilityLabel("Word count")
        paragraphCountDisplay?.setAccessibilityLabel("Line count")
        fileSizeDisplay?.setAccessibilityLabel("File size")
    }

    func updateStatistics(withText text: String) {
        textContent = text
        updateStatisticsDisplay()
    }

    private func updateStatisticsDisplay() {
        let stats = TextStatistics(text: textContent)
        wordCountDisplay?.stringValue = "\(stats.wordCount)"
        paragraphCountDisplay?.stringValue = "\(stats.lineCount)"
        fileSizeDisplay?.stringValue = stats.fileSizeString
    }
}

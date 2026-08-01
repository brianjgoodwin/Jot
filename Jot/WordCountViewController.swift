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
        updateStatisticsDisplay()
    }

    func updateStatistics(withText text: String) {
        textContent = text
        updateStatisticsDisplay()
    }

    private func updateStatisticsDisplay() {
        let stats = TextStatistics(text: textContent)
        wordCountDisplay?.stringValue = "\(stats.wordCount)"
        paragraphCountDisplay?.stringValue = "\(stats.paragraphCount)"
        fileSizeDisplay?.stringValue = stats.fileSizeString
    }
}

//
//  TextStatistics.swift
//  Jot
//
//  Shared text statistics calculations used by ViewController
//  and WordCountViewController.
//

import Foundation

struct TextStatistics {

    let wordCount: Int
    let characterCount: Int
    let characterCountNoSpaces: Int
    let lineCount: Int
    let paragraphCount: Int
    let readingTimeSeconds: Int
    let fileSizeString: String

    init(text: String) {
        wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        characterCount = text.count

        characterCountNoSpaces = text.filter { !$0.isWhitespace }.count

        lineCount = text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .count

        // Paragraphs: blocks of text separated by one or more blank lines.
        // Any run of 2+ consecutive newlines counts as one paragraph break.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            paragraphCount = 0
        } else {
            var count = 1
            var previousWasNewline = false
            var inBreak = false
            for char in trimmed {
                if char.isNewline {
                    if previousWasNewline && !inBreak {
                        count += 1
                        inBreak = true
                    }
                    previousWasNewline = true
                } else {
                    previousWasNewline = false
                    inBreak = false
                }
            }
            paragraphCount = count
        }

        // Reading time at ~250 words per minute
        readingTimeSeconds = wordCount > 0 ? max(1, (wordCount * 60) / 250) : 0

        let byteCount = text.data(using: .utf8)?.count ?? 0
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        fileSizeString = formatter.string(fromByteCount: Int64(byteCount))
    }

    var readingTimeString: String {
        if readingTimeSeconds == 0 { return "0 min" }
        let minutes = readingTimeSeconds / 60
        let seconds = readingTimeSeconds % 60
        if minutes == 0 { return "< 1 min" }
        if seconds >= 30 { return "\(minutes + 1) min" }
        return "\(minutes) min"
    }
}

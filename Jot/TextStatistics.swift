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
    let lineCount: Int
    let fileSizeString: String

    init(text: String) {
        wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        lineCount = text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .count

        let byteCount = text.data(using: .utf8)?.count ?? 0
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        fileSizeString = formatter.string(fromByteCount: Int64(byteCount))
    }
}

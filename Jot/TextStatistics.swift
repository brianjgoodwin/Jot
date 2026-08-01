//
//  TextStatistics.swift
//  Jot
//
//  Shared text statistics calculations used by ViewController
//  and WordCountViewController.
//

import Foundation

struct TextStatistics {

    let text: String

    var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    var paragraphCount: Int {
        text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .count
    }

    var fileSizeString: String {
        let byteCount = text.data(using: .utf8)?.count ?? 0
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteCount))
    }
}

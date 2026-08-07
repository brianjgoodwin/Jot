//
//  TextStatistics.swift
//  Jot
//
//  Shared text statistics calculations used by EditorViewController
//  and WordCountPanelController.
//

import Foundation

struct TextStatistics {

    // Shared formatter for displaying counts (word count label, stats panel)
    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter
    }()

    let wordCount: Int
    let characterCount: Int
    let characterCountNoSpaces: Int
    let lineCount: Int
    let paragraphCount: Int
    let readingTimeSeconds: Int
    let fileSizeString: String

    // The tallies iterate unicode scalars and test raw values: Character
    // iteration pays for grapheme segmentation (~70 ms per MB even with -O,
    // measured for #138) and the CharacterSet/ICU predicates are similarly
    // slow.
    //
    // Two different whitespace sets, faithful to the pre-1.0.10 behavior:
    // word and paragraph logic follows CharacterSet.whitespacesAndNewlines,
    // which includes U+200B ZERO WIDTH SPACE (a documented CharacterSet
    // quirk — Unicode's White_Space property excludes it); the character
    // tallies follow White_Space, matching the old Character.isWhitespace
    // counting. Net effect: ZWSP separates words but counts as a non-space
    // character, exactly as shipped in 1.0.9.

    /// Unicode White_Space scalars (the members of CharacterSet.whitespaces
    /// plus newlines, minus U+200B).
    private static func isWhitespaceScalar(_ value: UInt32) -> Bool {
        switch value {
        case 0x09...0x0D, 0x20, 0x85, 0xA0, 0x1680,
             0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
            return true
        default:
            return false
        }
    }

    /// CharacterSet.whitespacesAndNewlines membership, ZWSP included.
    private static func isWordSeparatorScalar(_ value: UInt32) -> Bool {
        return value == 0x200B || isWhitespaceScalar(value)
    }

    /// The members of CharacterSet.newlines (verified exhaustively in review).
    private static func isNewlineScalar(_ value: UInt32) -> Bool {
        switch value {
        case 0x0A...0x0D, 0x85, 0x2028, 0x2029:
            return true
        default:
            return false
        }
    }

    /// Words are runs of non-whitespace, the same definition the full
    /// statistics use. The editor's word-count label calls this instead of
    /// building all seven statistics just to display one number (#138).
    static func wordCount(of text: String) -> Int {
        var count = 0
        var previousWasSeparator = true
        for scalar in text.unicodeScalars {
            if isWordSeparatorScalar(scalar.value) {
                previousWasSeparator = true
            } else {
                if previousWasSeparator { count += 1 }
                previousWasSeparator = false
            }
        }
        return count
    }

    init(text: String) {
        wordCount = TextStatistics.wordCount(of: text)
        characterCount = text.count

        // Everything else in one scalar pass. The old implementation made ~6
        // full passes and materialized every word and line as its own String
        // — tens of MB of allocator churn per keystroke pause on large
        // documents (#138). A CRLF pair is one logical newline and one
        // Character, so it must count once, not twice.
        var whitespaceCharacters = 0
        var lineTotal = 0
        var paragraphTotal = 0

        // Paragraph rules (same results as the old trim-then-scan version):
        // a break is a run of 2+ newlines, but breaks only count once real
        // (non-whitespace) content follows — pending breaks at the very
        // start or end of the text are what trimming used to discard.
        var pendingBreaks = 0
        var newlineRun = 0
        var atLineStart = true
        var previousValue: UInt32 = 0

        for scalar in text.unicodeScalars {
            let value = scalar.value
            let crlfContinuation = (value == 0x0A && previousValue == 0x0D)
            previousValue = value

            if TextStatistics.isWhitespaceScalar(value) && !crlfContinuation {
                whitespaceCharacters += 1
            }

            // Word separators (including ZWSP) are not paragraph content —
            // this mirrors the old code trimming whitespacesAndNewlines
            if !TextStatistics.isWordSeparatorScalar(value) {
                if paragraphTotal == 0 {
                    paragraphTotal = 1
                } else {
                    paragraphTotal += pendingBreaks
                }
                pendingBreaks = 0
            }

            if TextStatistics.isNewlineScalar(value) {
                if !crlfContinuation {
                    newlineRun += 1
                    if newlineRun == 2 { pendingBreaks += 1 }
                    atLineStart = true
                }
            } else {
                newlineRun = 0
                if atLineStart { lineTotal += 1 }
                atLineStart = false
            }
        }

        // Deliberate correction from the old text.filter-based count: filter
        // rebuilt a string and re-ran grapheme segmentation, so removing a
        // whitespace character could merge its neighbors into one grapheme
        // ("a" + newline + combining accent + "b" counted 2, not 3). This
        // subtraction keeps the original text's segmentation.
        characterCountNoSpaces = characterCount - whitespaceCharacters
        lineCount = lineTotal
        paragraphCount = paragraphTotal

        // Reading time at ~250 words per minute
        readingTimeSeconds = wordCount > 0 ? max(1, (wordCount * 60) / 250) : 0

        // Local formatter, not static: ByteCountFormatter has no Sendable
        // annotation or thread-safety guarantee, and one small allocation is
        // noise next to the document scan above.
        let byteFormatter = ByteCountFormatter()
        byteFormatter.allowedUnits = [.useBytes, .useKB, .useMB]
        byteFormatter.countStyle = .file
        fileSizeString = byteFormatter.string(fromByteCount: Int64(text.utf8.count))
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

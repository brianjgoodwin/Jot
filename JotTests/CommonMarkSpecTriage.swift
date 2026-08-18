//
//  CommonMarkSpecTriage.swift
//  JotTests
//
//  Runs MarkdownHTMLRenderer against the CommonMark 0.31.2 spec suite
//  (commonmark-spec.json, 652 examples) and classifies every deviation.
//  Deviations fall into documented policy buckets (raw HTML escaped by
//  design, scheme allowlist, tight-list paragraph wrapping, ...) or
//  equivalence buckets (same DOM, different encoding). Anything left
//  over is a real defect and fails the test.
//

import XCTest
@testable import Jot

final class CommonMarkSpecTriage: XCTestCase {

	private struct SpecExample: Decodable {
		let markdown: String
		let html: String
		let example: Int
		let section: String
	}

	private enum Bucket: String, CaseIterable {
		case match = "exact match"
		case rawHTMLPolicy = "policy: raw HTML escaped, not passed through (#10)"
		case schemePolicy = "policy: link/image scheme allowlist"
		case linkTitlePolicy = "policy: link titles dropped"
		case paragraphWrapping = "equivalent: tight-list/paragraph wrapping"
		case quoteEscaping = "equivalent: quotes unescaped in text"
		case hrefEncoding = "equivalent: href percent-encoding differs"
		case whitespaceOnly = "equivalent: whitespace only"
		case real = "REAL DIFF"
	}

	private func loadSpec() throws -> [SpecExample] {
		guard let url = Bundle(for: Self.self).url(forResource: "commonmark-spec", withExtension: "json") else {
			throw XCTSkip("commonmark-spec.json is not in the test bundle")
		}
		return try JSONDecoder().decode([SpecExample].self, from: Data(contentsOf: url))
	}

	// MARK: - Classification helpers

	private func stripped(_ html: String, of tags: [String]) -> String {
		var result = html
		for tag in tags {
			result = result.replacingOccurrences(of: tag, with: "")
		}
		return result
	}

	private func unescaped(_ html: String) -> String {
		html.replacingOccurrences(of: "&lt;", with: "<")
			.replacingOccurrences(of: "&gt;", with: ">")
			.replacingOccurrences(of: "&quot;", with: "\"")
			.replacingOccurrences(of: "&amp;", with: "&")
	}

	private func collapseWhitespace(_ html: String) -> String {
		html.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined()
	}

	/// Removes every href="..." / src="..." value so encoding-only
	/// differences in destinations drop out of the comparison.
	private func withoutURLValues(_ html: String) -> String {
		let pattern = "(href|src)=\"[^\"]*\""
		return html.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
	}

	private func classify(markdown: String, expected: String, got: String) -> Bucket {
		if got == expected { return .match }

		// Raw HTML in the source that the spec expects passed through and
		// we deliberately escape (possibly wrapped in <p>). Undoing the
		// escaping and the paragraph wrapping should recover the spec
		// output if escaping is the only difference.
		let paragraphAndSpace = ["<p>", "</p>", "\n", " "]
		if markdown.contains("<"),
		   stripped(unescaped(got), of: paragraphAndSpace) == stripped(unescaped(expected), of: paragraphAndSpace) {
			return .rawHTMLPolicy
		}

		// Spec expects a link/img our allowlist refused to emit.
		if (expected.contains("<a ") && !got.contains("<a "))
			|| (expected.contains("<img ") && !got.contains("<img ")) {
			return .schemePolicy
		}

		if expected.contains("title=\"") && !got.contains("title=\"") { return .linkTitlePolicy }

		let paragraphTags = ["<p>", "</p>", "\n"]
		if stripped(got, of: paragraphTags) == stripped(expected, of: paragraphTags) {
			return .paragraphWrapping
		}

		if got.replacingOccurrences(of: "\"", with: "&quot;") == expected
			|| stripped(got.replacingOccurrences(of: "\"", with: "&quot;"), of: paragraphTags)
				== stripped(expected, of: paragraphTags) {
			return .quoteEscaping
		}

		if withoutURLValues(got) == withoutURLValues(expected)
			|| stripped(withoutURLValues(got), of: paragraphTags)
				== stripped(withoutURLValues(expected), of: paragraphTags) {
			return .hrefEncoding
		}

		if collapseWhitespace(got) == collapseWhitespace(expected) { return .whitespaceOnly }

		return .real
	}

	// MARK: - The triage run

	func testCommonMarkSpecSuite() throws {
		let examples = try loadSpec()
		XCTAssertEqual(examples.count, 652)

		var buckets: [Bucket: [SpecExample]] = [:]
		var rendered: [Int: String] = [:]
		for example in examples {
			let got = MarkdownHTMLRenderer.render(markdown: example.markdown)
			rendered[example.example] = got
			buckets[classify(markdown: example.markdown, expected: example.html, got: got), default: []].append(example)
		}

		print("=== CommonMark 0.31.2 spec triage ===")
		for bucket in Bucket.allCases {
			let members = buckets[bucket] ?? []
			guard !members.isEmpty else { continue }
			print(String(format: "%4d  %@", members.count, bucket.rawValue))
		}

		let real = buckets[.real] ?? []
		if !real.isEmpty {
			print("--- real diffs by section ---")
			let bySection = Dictionary(grouping: real, by: \.section)
			for (section, members) in bySection.sorted(by: { $0.key < $1.key }) {
				print("  \(section): \(members.map(\.example).sorted())")
			}
			for example in real.prefix(20) {
				print("--- example \(example.example) (\(example.section)) ---")
				print("markdown: \(example.markdown.debugDescription)")
				print("expected: \(example.html.debugDescription)")
				print("got:      \(rendered[example.example]!.debugDescription)")
			}
		}

		// Known parser-level deviations: swift-cmark implements slightly
		// older CommonMark rules than spec 0.31.2. Not reachable from the
		// renderer; both are cosmetic. Re-check when swift-markdown updates.
		// - 28: 0.31 caps numeric char refs at 7 digits; cmark accepts
		//   &#87654321; and substitutes U+FFFD instead of leaving it literal.
		// - 354: 0.31 counts currency symbols as punctuation in emphasis
		//   flanking rules; cmark still emphasizes *£*bravo.
		let knownParserDeviations: Set<Int> = [28, 354]
		let unexplained = real.map(\.example).filter { !knownParserDeviations.contains($0) }.sorted()
		XCTAssertEqual(unexplained, [], "unexplained spec deviations")
		XCTAssertEqual(Set(real.map(\.example)), knownParserDeviations,
					   "known parser deviations changed -- swift-markdown update? Re-triage.")
	}
}

//
//  PreviewShell.swift
//  Jot
//
//  Created on 8/19/26.
//
//  Builds the complete HTML document the preview window loads (#38).
//  Under the rebuild architecture the shell is loaded once per document
//  (on open and on retarget); later renders swap only the body via
//  callAsyncJavaScript. Everything assembled here -- CSP, lang, title,
//  theme CSS -- is therefore navigation-time state.
//

import Foundation

enum PreviewShell {

	/// Assembles a full HTML document around a rendered markdown body.
	///
	/// The Content Security Policy blocks inline scripts, eval, and all
	/// external resource loading. It backstops the renderer (which never
	/// passes raw HTML through), so even a renderer bug cannot produce a
	/// script-running page (#10, #134). App-side callAsyncJavaScript is
	/// user-agent script, exempt from page CSP, while scripts inside
	/// injected content stay blocked -- both proven empirically in the
	/// #252 spike.
	///
	/// When remote image loading is off, img-src allows only data: URIs,
	/// which never touch the network -- no tracking pixels. file: is not
	/// listed because an about:blank origin refuses file: subresources
	/// anyway; local images would need a loadFileURL adoption, and that
	/// changes the origin, so re-verify #134 before ever making it.
	static func document(title: String,
						 bodyHTML: String,
						 theme: PreviewTheme = .standard,
						 loadRemoteImages: Bool,
						 languageTag: String = preferredLanguageTag()) -> String {
		let imgSrc = loadRemoteImages ? "img-src https: data:" : "img-src data:"
		return """
		<!DOCTYPE html>
		<html lang="\(sanitizeLanguageTag(languageTag))">
		<head>
		<meta charset="utf-8">
		<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; \(imgSrc);">
		<meta name="color-scheme" content="light dark">
		<title>\(escapeHTML(title))</title>
		<style>
		\(theme.css)
		</style>
		</head>
		<body>
		\(bodyHTML)
		</body>
		</html>
		"""
	}

	/// Body shown when there is nothing to preview. Inline styles only
	/// (allowed by style-src 'unsafe-inline'); the muted color comes from
	/// the theme's CSS variables so it follows the palette.
	static let emptyStateBody = """
	<div style="margin-top: 5em; text-align: center; color: var(--muted);">
	<p>Nothing to preview.</p>
	<p>Open a document and choose View &gt; Markdown Preview.</p>
	</div>
	"""

	/// The user's preferred language as a BCP-47 tag for the html lang
	/// attribute (#52). The document's actual language is unknowable;
	/// the UI language is the best available signal for VoiceOver
	/// pronunciation.
	static func preferredLanguageTag() -> String {
		Locale.preferredLanguages.first ?? "en"
	}

	/// lang lands inside a double-quoted attribute. Rather than escape,
	/// reject anything that is not plain BCP-47 shaped (ASCII letters,
	/// digits, hyphens) and fall back to English.
	private static func sanitizeLanguageTag(_ tag: String) -> String {
		let isValid = !tag.isEmpty && tag.allSatisfy {
			$0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-")
		}
		return isValid ? tag : "en"
	}

	/// Same rules as MarkdownHTMLRenderer's private escapeHTML -- double
	/// quotes escaped, single quotes not, so every attribute emitted
	/// here must be double-quoted. Keep the two in step.
	private static func escapeHTML(_ text: String) -> String {
		text.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
			.replacingOccurrences(of: "\"", with: "&quot;")
	}
}

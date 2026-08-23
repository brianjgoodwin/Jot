//
//  PreviewTheme.swift
//  Jot
//
//  Created on 8/19/26.
//
//  A preview theme is a named CSS payload injected into the preview
//  shell (#38). One built-in theme ships in 2.0; the curated set is
//  #40, and the Settings picker is #27 territory. Theme CSS must style
//  both screen and print -- print output is the heart of the preview
//  feature (see docs/preview-rebuild-plan.md), not an afterthought.
//

import Foundation

struct PreviewTheme {
	let name: String
	let css: String

	/// The built-in default. The target look is GitHub's markdown
	/// rendering (per the user stories in the rebuild plan): system
	/// sans, measured line length, bordered tables, quiet chrome.
	///
	/// Colors are CSS variables so the palette can switch with the
	/// system appearance and be forced light for print in one place.
	static let standard = PreviewTheme(name: "Standard", css: """
		:root {
			color-scheme: light dark;
			--fg: #1f2328;
			--bg: #ffffff;
			--muted: #59636e;
			--accent: #0969da;
			/* Decorative rules: heading underlines, hr, blockquote bar. */
			--rule: #d1d9e0;
			/* Tables are an information grid, not decoration: solid mid
			   gray clears the 3:1 non-text contrast guideline on both
			   palettes (#52). */
			--table-border: #808080;
			--code-bg: #f6f8fa;
		}

		@media (prefers-color-scheme: dark) {
			:root {
				--fg: #f0f6fc;
				--bg: #0d1117;
				--muted: #9198a1;
				--accent: #4493f8;
				--rule: #3d444d;
				--code-bg: #151b23;
			}
		}

		body {
			font-family: -apple-system, sans-serif;
			font-size: 16px;
			line-height: 1.5;
			color: var(--fg);
			background: var(--bg);
			max-width: 46em;
			margin: 0 auto;
			padding: 2em;
		}

		h1, h2, h3, h4, h5, h6 {
			margin: 1.5em 0 0.5em;
			font-weight: 600;
			line-height: 1.25;
		}
		h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid var(--rule); }
		h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid var(--rule); }
		h3 { font-size: 1.25em; }
		h4 { font-size: 1em; }
		h5 { font-size: 0.875em; }
		h6 { font-size: 0.85em; color: var(--muted); }

		a { color: var(--accent); }

		code, pre {
			font-family: ui-monospace, Menlo, monospace;
			font-size: 85%;
		}
		code {
			background: var(--code-bg);
			padding: 0.2em 0.4em;
			border-radius: 6px;
		}
		pre {
			background: var(--code-bg);
			padding: 1em;
			border-radius: 6px;
			line-height: 1.45;
			overflow-x: auto;
		}
		pre code { background: none; padding: 0; font-size: 100%; }

		blockquote {
			margin: 1em 0;
			padding: 0 1em;
			color: var(--muted);
			border-left: 0.25em solid var(--rule);
		}

		ul, ol { padding-left: 2em; }
		/* swift-markdown does not expose list tightness, so the renderer
		   wraps every list item's text in <p> (pinned in
		   MarkdownHTMLRendererTests). Collapse the wrapper's margins so
		   single-paragraph items read as a tight list. :only-of-type
		   rather than :only-child, so items that also carry a checkbox
		   <input> or a nested <ul> still collapse. */
		li > p:only-of-type { margin: 0; }
		/* A task-list item is <li><input/> <p>text</p></li>; the block
		   <p> would otherwise drop the text onto its own line below the
		   checkbox. */
		li > input[type="checkbox"] + p { display: inline; }

		table { border-collapse: collapse; margin: 1em 0; }
		th, td { border: 1px solid var(--table-border); padding: 6px 13px; }
		th { font-weight: 600; }
		tbody tr:nth-child(2n) { background: var(--code-bg); }

		img { max-width: 100%; }

		hr { border: 0; border-top: 2px solid var(--rule); margin: 1.5em 0; }

		@media print {
			/* Force the light palette: print strips backgrounds by
			   default, which would leave dark mode's light text invisible
			   on white paper. */
			:root {
				--fg: #1f2328;
				--bg: #ffffff;
				--muted: #59636e;
				--accent: #0969da;
				--rule: #d1d9e0;
				--table-border: #808080;
				--code-bg: #ffffff;
			}
			/* Page margins come from NSPrintInfo, not CSS. */
			body { max-width: none; margin: 0; padding: 0; }
			/* The gray background does not print, so a border keeps code
			   blocks delineated; wrapping beats clipping long lines on
			   paper. */
			pre { border: 1px solid var(--rule); white-space: pre-wrap; }
			h1, h2, h3, h4 { break-after: avoid; }
		}
		""")
}

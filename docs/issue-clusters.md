# Issue Clusters

Reference file for planning. Maps related issues into thematic clusters
around flagship features. Use this to reason about milestones, sequencing,
and dependencies -- not as a task list.

---

## Cluster: Markdown Preview and Parser Overhaul

The last major feature blocking "complete." Replaces the unmaintained Down
dependency with Apple swift-markdown, rebuilds the preview window, and
unlocks downstream features (export, themes, copy-as-HTML).

### Core (build the new pipeline)

| # | Title | Current milestone | Notes |
|---|-------|-------------------|-------|
| 30 | Replace Down with Apple swift-markdown | 1.1.1 preview overhaul | Parser swap. Visitor-based HTML renderer we own. |
| 38 | Rebuild preview as live-updating, printable window | 1.1.1 preview overhaul | Consumes #30. Tracks active editor, debounced updates. |
| 39 | Highlighting, footnotes, tables in rendering | 1.1.1 preview overhaul | Tables/strikethrough built into swift-markdown; highlighting and footnotes are custom extensions. |
| 137 | Release WKWebViews on close (memory) | 1.1.1 preview overhaul | Biggest controllable RAM cost. Do during the rebuild. |
| 134 | CSP inline-CSS gap (security) | 1.1.1 preview overhaul | Moot if the new renderer excludes raw HTML passthrough (which it should). Verify. |
| 52 | Preview accessibility (dark mode, contrast, lang) | 1.1.1 preview overhaul | Bake into the HTML template from day one. |
| 111 | Help overstates preview capabilities | 1.1.1 preview overhaul | Update help text after the preview is actually live. |

### Downstream (unlocked by the new pipeline)

| # | Title | Current milestone | Notes |
|---|-------|-------------------|-------|
| 40 | Curated preview CSS themes | 1.2 | Needs the new template/renderer. |
| 43 | Export to PDF and HTML | 1.2 | Shares the rendering pipeline. |
| 151 | Copy as HTML / rich text | 1.2 | Shares the rendering pipeline. |

### Editor-side (shares parsing layer or patterns)

| # | Title | Current milestone | Notes |
|---|-------|-------------------|-------|
| 97 | Nested list parsing and auto-continue | 1.1.0 editor polish | MarkdownProcessor work, not preview. But the parser swap is a chance to align patterns. |
| 166 | Styling leaks into code fences | 1.1.0 editor polish | Editor-only bug. Needs fence-aware range exclusion. |
| 164 | Fence position caching (perf) | -- | Feeds #166. Shared fence state for all passes. |
| 148 | Heading outline navigation | -- | Reuses heading regex; could also walk the swift-markdown AST. |

### Tangential (affected but not blocked)

| # | Title | Notes |
|---|-------|-------|
| 150 | Per-mode smart substitutions | No smart quotes in markdown mode. Independent but mode-aware. |
| 158 | Infer editor mode from file type | .md opens in markdown mode. Independent. |

### Key decisions

- **swift-markdown over custom parser** -- decided 2026-08-11. Apple-maintained, CommonMark-compliant, visitor pattern gives us full control over HTML output. Supply chain concern resolved.
- **Sequencing decided 2026-08-18** (see "Cross-milestone sequencing" at the end of this file): #30 first on a spike branch, then #38 with #137/#134/#52 folded in, then #39, then downstream (#40/#43/#151), then #111 last. Post-milestone-style review agents run at the phase boundary after #38 lands -- that is where the security surface (WKWebView, CSP) and the architecture get set -- rather than waiting for all twelve issues.

### Open questions

- Should the swift-markdown AST replace MarkdownProcessor's regexes for editor highlighting too, or keep them separate? (Performance implications for per-keystroke highlighting.) **Decision point scheduled: immediately after #30 lands, with the parser in hand.** The answer sequences #164/#166 in the editor cluster -- refining the regex layer before this call risks doing that work twice.
- Does #148 (heading outline) belong in this cluster's milestone or later?
- Where do #97 and #166 land relative to this work? They are editor-side but share conceptual ground.

---

## Cluster: Quick Wins -- Stock AppKit Wiring

Practically free items: one-liners, storyboard attributes, stock menu items.
No design decisions, no architectural thinking. The app just feels more
correct afterward. Afternoon-sized batch.

Origin: split from the original "Finishing the Editor" mega-cluster (2026-08-11).

| # | Title | Notes |
|---|-------|-------|
| 179 | Modern find bar with regex and match-case | Big UX win. Change findStyle from panel to bar. |
| 187 | Window frame autosave | Single attribute. Windows remember position/size. Split from #180. |
| 188 | Suppress stray untitled window on launch | One AppDelegate method. Split from #180. |
| 189 | Window tabbing menu items | Show Next/Prev Tab, Merge All Windows. Stock, zero code. Split from #180. |
| 190 | Remove dead toolbar menu items | View menu targets a toolbar that doesn't exist. Split from #180. |
| 191 | Automatic link detection in plain-text mode | One-liner. Consider disabling in markdown mode. Split from #180. |
| 192 | Continuous spell-checking by default | Changes the default, still togglable. Split from #180. |
| 197 | Migrate deprecated kUTType constants | macOS 12+ UniformTypeIdentifiers. Split from #181. |

---

## Cluster: File Handling and Document Identity

Making Jot a good citizen with files -- opening more types, preserving what
it opens, remembering how you had things set up. Real design surface;
some items depend on each other (#158 -> #157, #193 -> #194).

| # | Title | Notes |
|---|-------|-------|
| 126 | Duplicate, Rename, Move To menu items | HIG-standard for autosaving apps. NSDocument provides all three. |
| 98 | Dock icon file drops | Broken basic behavior. Pre-existing. |
| 173 | Legacy draft migration race | Low likelihood but unrecoverable data loss. Move aside, don't delete. |
| 158 | Infer editor mode from file type | .md opens in markdown mode. Also in preview cluster (tangential). |
| 157 | Per-document view settings via xattrs | "Reopens how I left it." Companion to #158. |
| 193 | File type coverage (JSON, XML, catch-all text) | Split from #181 items 1-4. Info.plist + drag-drop types. |
| 194 | Preserve original file encoding on save | Split from #181 items 5-6. Don't silently convert to UTF-8. |
| 196 | Print with user's selected font | Split from #181 item 10. printableView() ignores font choice. |
| 195 | Encoding and line ending indicators in status bar | Split from #181 items 7-8. Visibility, not a picker. |

---

## Cluster: Editor Features and Refinement

The items that need thought -- design decisions, menu restructuring,
accessibility, markdown processor bugs. Each one stands alone and requires
its own consideration.

| # | Title | Notes |
|---|-------|-------|
| 96 | Markdown formatting commands + Format menu cleanup | Remove rich-text items, add strikethrough/code/link/heading shortcuts. |
| 150 | Per-mode smart substitutions | No smart quotes in markdown mode. Also in preview cluster (tangential). |
| 144 | Keep on Top window toggle | Scratchpad identity feature. Floating window level. |
| 159 | Configurable word count metric | Reading time, character count, delta since open. |
| 172 | Word Count panel unreachable by keyboard/VO | Panel controllable but not consumable. Needs design decision. |
| 27 | Tabbed Settings window | Growing prefs need structure. |
| 175 | Table header bolding clamp | Cosmetic. Clamp to intersection range, handle offscreen. |
| 166 | Markdown styling inside code fences | Pre-existing. Also in preview cluster (editor-side). |
| 164 | Fence position caching (perf) | Feeds #166. Shared fence state for all passes. |
| 99 | Version tracking for first-launch/what's-new | Infrastructure only, no UI. |
| 171 | Fix Show Fonts (Cmd-T) doing nothing | Font panel opens but changes nothing. Needs responder chain work. |

---

## Cluster: Help Window Polish

Six issues all scoped to the help system. Bugs, accessibility, and content
accuracy. Self-contained; could be knocked out in a focused session or two.

| # | Title | Notes |
|---|-------|-------|
| 100 | External links open inside WKWebView instead of browser | Bug. Links should open in default browser. |
| 113 | Restore user-click gate in Help web view navigation policy | Security. Audit finding. |
| 114 | Wire Cmd+? and Help-menu search to the help window | Standard macOS help integration. |
| 115 | Help text fixed at 13px with no zoom support | Accessibility. |
| 117 | Help content and HelpViewController polish bundle | Chore. Catchall for remaining help cleanup. |
| 176 | Help pages missing lang and title; fallback support address | Accessibility + content fix. |

### Notes

- #111 (help overstates preview) is in the preview cluster -- it depends on the preview rebuild landing first.
- #137 (WKWebView memory) is also preview cluster -- it affects both Help and Preview but the fix is architectural.

---

## Cluster: Test Infrastructure

Testing, reliability, and the gutter follow-ups that are primarily test
coverage. Investment in confidence for a solo developer.

| # | Title | Notes |
|---|-------|-------|
| 135 | Cover restore flow and document lifecycle | Test harness for the save/restore path. |
| 170 | UI-scripted soak harness (100 docs, hours of churn) | Stress testing. Memory sampling. |
| 174 | Isolate preference tests from real UserDefaults | Test hygiene. Prevents developer config from leaking into tests. |
| 182 | Wrap-off text view keeps stale width when gutter toggles | Bug fix (gutter follow-up). |
| 183 | Drive the gutter scroll-repaint observer | Test coverage (gutter follow-up). |
| 184 | Seeded-random differential fuzz for LineIndex | Test coverage (gutter follow-up). |

### Notes

- #182 is a bug, not a test, but it's a gutter follow-up and fits better here than in the editor cluster.
- #170 is ambitious -- long-running soak test. Could be its own project or a rainy-day item.

---

## Cluster: Content and Capture

Getting text into Jot faster and in richer ways. Workflow features that
build on the editor foundation.

| # | Title | Notes |
|---|-------|-------|
| 161 | User-defined document templates (New from Template) | Folder-backed, dynamic menu. |
| 162 | User-defined snippets (insert text block at cursor) | Shares folder-backed menu mechanism with #161. Build once. |
| 147 | Opt-in global quick-capture (system-wide hotkey) | Menu-bar extra or hotkey. System integration. |
| 149 | Services menu entry ("New Jot Note from Selection") | macOS Services. Lightweight system integration. |

### Notes

- #161 and #162 share a folder-backed dynamic menu mechanism -- implement together.
- #147 is the most complex item here (menu-bar extra, hotkey registration).
- #149 is nearly free (NSServices declaration + a few lines).

---

## Unclustered

Issues that don't belong to a thematic group. Tracked individually.

| # | Title | Notes |
|---|-------|-------|
| 41 | Non-App Store distribution with Sparkle | Distribution strategy. Standalone. |
| 55 | Set up MkDocs site with GitHub Pages | Developer documentation. |
| 56 | Write walkthrough documentation | Developer documentation. Pairs with #55. |
| 180 | Remaining: Share menu, async saving, Dock menu | Items 8-10 from the original omnibus. Backlog odds and ends. |
| 237 | New Jot Note App Intent for Shortcuts | Moved off Content and Capture 2026-08-18. Distinct capability (App Intents framework); scheduled on its own. |
| 243 | Service note does not foreground when Jot already runs | Non-blocking. Both cooperative activate() and the deprecated forcing call fail empirically on Sequoia; investigation avenues recorded in the issue. |

---

## Cross-milestone sequencing (decided 2026-08-18)

With File Handling, Quick Wins, Help Window, and Content and Capture complete,
three milestones remain: Markdown Preview and Parser, Editor Refinement, and
Test Infrastructure. The order:

1. **#174 first, immediately** (test isolation from real UserDefaults).
   Small, and it makes every test run during the heavy milestones
   trustworthy -- test pollution from developer defaults is exactly the
   confusing failure not to be debugging mid-parser-swap.
2. **Markdown Preview core** (#30 spike branch, then #38 folding
   #137/#134/#52, then #39, then #40/#43/#151, then #111). Goes before
   Editor Refinement because of the AST-vs-regex open question, not just
   flagship status: #164/#166 are real work on the MarkdownProcessor regex
   layer, and refining that layer before deciding whether the swift-markdown
   AST replaces it risks doing the work twice. The decision is made right
   after #30, with the parser in hand.
3. **Editor Refinement**, sequenced by that decision: #164 -> #166 land
   per the AST call; the independents (#96 Format menu, #144 Keep on Top,
   #27 tabbed Settings, #171 Cmd-T, #159/#172 word count, #241 undo
   coalescing) stand alone and suit one-issue-per-session work in any
   order, interleaved with preview phases if a change of pace helps.
4. **Test Infrastructure mostly last, deliberately.** The gutter
   follow-ups (#182 bug, #183, #184) are self-contained palate cleansers --
   usable between preview phases, no need to hold them. But #170 (soak
   harness) is the final substantial item on purpose: hours-of-churn
   evidence pays most against a near-final app and is wasted against code
   about to be rewritten.

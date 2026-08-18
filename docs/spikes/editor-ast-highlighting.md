# Spike: swift-markdown AST for editor highlighting

Decision point scheduled in `docs/issue-clusters.md`: now that #30 proved
swift-markdown for the preview, should the AST also replace
MarkdownProcessor's regexes for in-editor highlighting? The answer
sequences #164 (fence caching) and #166 (fence-aware range exclusion).

This is a **measurement spike**. The deliverable is numbers and a
recommendation, not shippable code. Nothing here merges into
`spike/30-swift-markdown` or `develop`.

## What the editor does today

Per keystroke (EditorViewController):

1. An immediate `applyMarkdownStyling` pass bounded to the edited line
   range.
2. A 0.1 s debounced pass over the visible character range.
3. The one document-scale cost inside both: the fenced-code-block regex
   scans the full document every pass (#164).

An AST approach cannot do bounded passes -- cmark parses whole
documents. Its floor cost per styling pass is a full-document parse
plus mapping AST source locations onto NSTextStorage ranges.

## Kill criteria (written before measuring)

The AST replaces the regexes for highlighting only if ALL of these hold:

1. **Parse budget.** Full `Markdown.Document(parsing:)` of a 500 KB
   document stays under ~8 ms on this machine (half a 60 Hz frame,
   leaving room for attribute application on the main thread). Under
   ~2 ms at 100 KB.
2. **Range mapping works.** SourceLocation (line/column) maps correctly
   to NSRange (UTF-16) including non-ASCII text, without a full
   re-scan that costs more than the parse.
3. **No fidelity loss.** The AST surfaces the constructs the editor
   styles today (checklist state, table separator rows, delimiter
   symbols) with enough position detail to dim markers separately from
   content.

If criterion 1 fails: keep regexes, proceed with #164/#166 as planned
(shared fence state). A hybrid (AST for fences only, on the debounced
pass) is a fallback worth one look before closing the question.

## Results (2026-08-18, M-series Mac, JotTests/EditorASTBenchmarks)

Full-document `Markdown.Document(parsing:)`, average of 10 runs:

| Document size | Debug   | Release |
|--------------:|--------:|--------:|
| 10 KB         | ~5 ms   | --      |
| 100 KB        | ~50 ms  | ~16 ms  |
| 500 KB        | ~240 ms | ~76 ms  |

Current regex pass for comparison (identical Debug/Release -- the work
is in ICU):

- Bounded per-keystroke pass, 2 KB window of a 500 KB document,
  including the full-document fence scan: **~7.4 ms**
- Full-document pass (mode toggle / open), 500 KB: ~500 ms

### Verdict against the kill criteria

1. **Parse budget: FAIL.** ~76 ms at 500 KB in Release vs the ~8 ms
   budget; ~16 ms at 100 KB vs ~2 ms. An order of magnitude out, and
   that is parse-only -- before location mapping or attribute
   application.
2. **Range mapping: passes.** SourceLocation columns are 1-based UTF-8
   byte columns; exact spans recover correctly through multi-byte text
   (testSourceLocationColumnsAreUTF8Bytes), and delimiter runs are
   recoverable by subtracting child ranges from parent ranges
   (testDelimiterRangesAreRecoverable). Production mapping to UTF-16
   NSRanges would need a byte-offset conversion pass -- moot given (1).
3. **Fidelity: not evaluated.** Criterion 1 already decides.

The hybrid fallback (AST for fence positions on the debounced pass) is
also dead: a 76 ms parse to locate fences loses to a regex fence scan
that fits inside today's 7.4 ms bounded pass.

## Recommendation

Keep MarkdownProcessor's regexes for editor highlighting. The AST and
the editor styling layer stay separate: swift-markdown owns the preview
pipeline (#30/#38/#39), regexes own per-keystroke styling. Proceed
with #164 (fence position caching) and #166 (fence-aware range
exclusion) as shared-fence-state work on the regex layer, as the
cluster doc's sequencing anticipated.

Useful side-finding: the AST range-mapping probes stay valid for
non-keystroke consumers -- #148 (heading outline) can walk the AST on
document open/idle, where a 16-76 ms parse is fine.

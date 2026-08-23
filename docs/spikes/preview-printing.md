# Spike: WKWebView printing for the preview rebuild (#252)

Validates the #38 architecture (shell-loaded-once + body swap +
printOperation(with:)) before the window rebuild starts. See
docs/preview-rebuild-plan.md for the decisions this spike tests.

Branch: spike/252-preview-printing (throwaway; this doc graduates).
Harness: JotTests/PreviewPrintingSpikeTests.swift -- an offscreen
WKWebView driven exactly the way the rebuilt preview will drive it,
printed to PDF via jobDisposition = .save, verified with PDFKit.
Run 2026-08-19, local Xcode, macOS 15.6.

## Kill criteria (written before measuring)

| # | Criterion | Verdict |
|---|-----------|---------|
| 1 | Tables and code blocks paginate acceptably (no mid-row splits that damage readability) | PASS |
| 2 | Margins from NSPrintInfo are honored in the PDF output | PASS |
| 3 | @media print CSS is respected by the print operation | PASS |
| 4 | callAsyncJavaScript body swap runs despite default-src 'none' CSP, while scripts inside the injected content stay blocked | PASS |
| 5 | printOperation(with:) prints the swapped DOM, not the originally loaded string | PASS |

All five pass. The suite runs in ~2 s; print-to-PDF itself is fast
(a 7-page torture document in under half a second).

## Results

- **Pagination (1):** a real MarkdownHTMLRenderer document (120-row
  table + 80-line code fence + prose) produced a 7-page US Letter PDF.
  Table rows break cleanly between rows (verified visually page by
  page); the code fence breaks cleanly between lines; nothing clipped
  or truncated (first/last markers, row 120, and fence line 80 all
  present in extracted text).
- **Margins (2):** 1-inch margins set on NSPrintInfo are honored on
  every page, both visually and by page size (612x792).
- **Print CSS (3):** `@media print { display: none/block }` both work:
  a screen-only element is absent from the PDF text, a print-only
  element is present.
- **CSP vs body swap (4):** confirmed empirically -- app-side
  callAsyncJavaScript executes under `default-src 'none'` (WebKit
  treats it as user-agent script), while scripts inside the injected
  content stay dead: an injected `<script>` tag, an inline `onerror`
  handler on a valid data: image, and an `onerror` on a broken image
  all failed to execute (sentinel variable never set).
- **Swapped DOM prints (5):** the PDF contains the swapped body and not
  the originally loaded shell content.

## Notable observations (not kill criteria)

- **Layout width is the print width.** WKWebView paginates at its
  layout width. The harness sized the web view to the printable width
  (468 pt = US Letter minus 1" margins) and output came out 1:1. A
  preview window at an arbitrary screen width will either be scaled by
  horizontalPagination = .fit (shrinking type) or clip. For #38 the
  print path should render at page width -- resize the web view for the
  print operation, or keep the print styles width-tolerant and accept
  .fit scaling. Decide during the rebuild; the spike proves both knobs
  exist.
- **Table headers do not repeat on subsequent pages** (thead repetition
  is spotty in WebKit print). Fine for 2.0; worth remembering if a user
  ever reports it.
- **runModal(for:delegate:) is required.** NSPrintOperation.run()
  returns before WKWebView's async print pipeline produces output; the
  delegate-callback form completes reliably. The harness pumps the run
  loop until the callback fires.
- The RBS ProcessAssertion errors in test logs
  ("com.apple.runningboard.assertions.webkit") are sandbox noise from
  the test host, harmless.

## Post-spike addendum (2026-08-20, found during the #38 build)

The spike suppressed the print panel (showsPrintPanel = false,
jobDisposition = .save), and that hid a crash: WKWebView's
printOperation(with:) vends its printing view with a ZERO frame. The
.save path tolerates the empty frame; the print panel's preview pane
traps on it the moment runModal presents (EXC_BREAKPOINT). Fix:
set `operation.view?.frame = webView.bounds` before running. Verified
empirically (the vended NSView really is 0x0 while the web view is
468x648); regression-pinned in PreviewWindowControllerTests.

Lesson for future spikes: a kill-criteria list is only as good as the
code path it exercises -- the panel was the one branch the harness
skipped, and it was the one that failed.

## Recommendation

Proceed with the #38 architecture exactly as planned: shell loaded
once, body swapped via callAsyncJavaScript (HTML passed as an argument,
never string-built), printOperation(with:) with jobDisposition-driven
PDF export via the standard dialog. No fallback (createPDF or a
separate print-path render) is needed. Carry the layout-width
observation into the #38 design.

# Performance

Jot's identity is "fast and light." This document is the measurement story
behind that claim: what gets measured, how to run the measurements, and what
the numbers looked like when the harness was built (#142).

## Performance tests

`JotTests/PerformanceTests.swift` measures the two hot paths — `TextStatistics`
construction and `MarkdownProcessor.applyMarkdownStyling` — over deterministic
generated fixtures at 10 KB, 100 KB, and 1 MB.

Run them like any other test (`Cmd-U`, or `xcodebuild test`). The measured
tests record wall-clock and memory metrics; they only *fail* against a
baseline, and baselines are stored per-machine.

**Setting baselines (do this on your Mac, not in CI):** run the tests in
Xcode, open the Report navigator, click a performance test, and use
"Set Baseline" on the metric you want to defend. Xcode then fails the test
locally if a future run regresses past the baseline's tolerance. CI has no
baselines, so CI runs just record numbers and never fail on timing — that is
deliberate; shared runners are too noisy for hard perf assertions.

The pathological-input timing tests (catastrophic-backtracking guards from
\#122) live in `MarkdownProcessorTests.swift` and *do* hard-fail everywhere,
because they defend against hangs, not slowness.

## Signposts

The app marks its hot paths with `os_signpost` intervals (subsystem
`com.brian.jot`, category Points of Interest — see `PerformanceLog.swift`):

| Signpost name         | Marks                                                  |
|-----------------------|--------------------------------------------------------|
| Markdown Styling      | One styling pass; message notes styled vs total chars  |
| Word Count            | `TextStatistics` build for the editor label            |
| Document Sync         | Debounced `textView.string` → `document.text` copy     |
| Preview Render        | Markdown → HTML conversion + WKWebView load            |
| Legacy Draft Restore  | One-time migration of pre-1.0.9 unsaved-state files    |

In Instruments, add the **Points of Interest** instrument (it is included in
the Time Profiler template) and the intervals appear by name. On the command
line: `log stream --predicate 'subsystem == "com.brian.jot"' --signpost`.

## Instruments playbook (~20 minutes)

1. **Launch**: Instruments > App Launch template; cold-launch 3 times and
   record time-to-first-window.
2. **WKWebView cost**: in Activity Monitor, note memory for Jot plus the
   "Jot Web Content" helper; open Help, close it, compare. Repeat for
   Markdown Preview.
3. **Typing**: Time Profiler + Allocations; paste a 1 MB file and type
   continuously for 30 s in plain-text mode (word count on), then markdown
   mode. The Word Count and Markdown Styling signposts should bound the work;
   look for either dominating the trace.
4. **Idle**: leave a document open 5 minutes under Time Profiler — the trace
   should be flat. There are no repeating timers by design; verify it stays
   true.

## Recorded audit results (2026-08, develop @ 096dbda, pre-Phase-3)

Structural typing-smoothness envelope before the Phase 3 fixes:

- Plain text, word count off: ~5–10 MB documents
- Plain text, word count on: ~1 MB (#138)
- Markdown mode: a few hundred KB (#123, #141)

Deliberate do-nothings (checked during the audit; leave alone):

- `Document.text` duplicate model copy — correct model-layer design
- About/Settings/Word Count panels retained forever — KB-scale, fine
- No caching of stats or rendered preview HTML — debounce bounds frequency;
  caches would be over-engineering
- Regexes are already `static let`; release build uses `-O`, whole-module

Baseline numbers from the harness on the development machine (M-series, Debug
configuration) are recorded in the Phase 3 PR (#142 → the perf PR) for
before/after comparison.

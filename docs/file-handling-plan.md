# File Handling Milestone Plan

Drafted 2026-08-17. Covers the 8 open issues in the File Handling milestone
(#196 was closed during planning — already fixed by the #125 print overhaul).
Phases are ordered by user harm: data loss first, then correctness, then
features. Each phase is a separate branch/PR per the usual workflow, and the
milestone stays ship-when-ready — develop is releasable after every phase.

Research inputs: an adversarial code review of the #173 race, and a
documentation/empirical research pass on AppKit restoration signals and
encoding preservation (TextEdit sample code, CotEditor source, SDK headers).
Key findings are inlined where they matter.

---

## Phase 1 — #173: legacy draft migration data loss

### Archaeology (why this needs a decision, not a patch)

1. Jot 1.0.6 shipped a hand-rolled crash-recovery system (`.unsaved` files
   in Application Support) that duplicated NSDocument autosave.
2. #121 (1.0.9) removed it in favor of real autosave, leaving a migration
   shim (`Document.performLegacyMigration`) to rescue leftover drafts.
3. The shim has since accreted patches: VoiceOver announcement workarounds
   (#153), an actor-isolation fix, testability hooks (#135).
4. #173 reports that the shim's "already open?" check races window
   restoration and deletes the draft on a wrong guess.

The review surfaced a deeper flaw than the race: **the "stale duplicate"
check is wrong even when it wins the race.** Legacy drafts exist precisely
because they held edits *not saved to the file*. Window restoration reopens
the file *from disk* — a restored window never covers the draft's content.
Deleting (or silently archiving) the draft on an "already open" match can
discard the only copy of those edits.

### Decision point: Option A vs Option B — DECIDED: Option A (2026-08-17)

**Option A (recommended) — remove the racy question entirely.**

- Delete the `openPaths` snapshot and the stale-duplicate branch
  (`Document.swift:209-212, 235-239`).
- Every readable, non-empty draft always becomes a Recovered Draft window —
  visible, autosaving, user decides what to keep. Title it with the original
  filename ("Recovered Draft — notes.txt") so a side-by-side with the
  restored file explains itself.
- Unreadable / malformed drafts: move aside to a sibling archive folder
  (never delete what couldn't be inspected). Archive path derived from
  `unsavedStatesFolder` (e.g. sibling `UnsavedStates-Archived`) so the
  existing test override covers it and the empty-folder cleanup keeps
  working. UUID suffix on name collision.
- The post-recovery delete (line 270) stays: content now lives in a shown,
  autosaving document.
- No timing machinery of any kind. Net negative lines of code.
- Trade-off: a 1.0.6–1.0.8 upgrader whose file was open at quit sees two
  windows once — the file and the recovered draft. Honest, self-explaining,
  one-time, small population.

**Option B (documented alternative) — keep dedup, make it safe-ish.**

- Stale-duplicate match → move draft aside instead of deleting.
- Gate the migration on `NSApplication.didFinishRestoringWindowsNotification`
  so the dedup check runs after restoration has settled. Research finding:
  this is better-founded than initially feared — the `NSWindowRestoration.h`
  header documents that the notification posts on *every* launch (including
  nothing-to-restore, between will/didFinishLaunching) and only after all
  restoration completion handlers have run, which (per the documented
  NSDocumentController reopen path) means restored documents are present in
  `NSDocumentController.shared.documents` by then. Observer must be
  registered in `applicationWillFinishLaunching` (the notification can beat
  `applicationDidFinishLaunching`). One open verification item: behavior
  with `NSQuitAlwaysKeepsWindows=0` (documented text covers "no windows to
  restore"; disabled-restoration is an inference — 5-minute empirical test).
- Residual flaw: a correct dedup match still silently archives edits that
  may exist nowhere else. The user never sees them.

A is recommended because it fixes the content-loss flaw B retains, and
because this subsystem's history argues for removing logic, not adding
launch-sequence machinery. B is written up so the choice is explicit.

### End of life

Unchanged from the shim's own comments: delete the entire migration section
one or two releases after 1.1.0. Track with a follow-up issue when Phase 1
merges.

### Tests (either option)

Existing migration tests in `JotTests/DocumentTests.swift` (folder-override
helper) continue to pass, minus any dedup-specific test if A removes that
branch. New:

- Unreadable draft (raw non-UTF-8 bytes) → archived, not deleted, no window.
- Malformed sentinel (no newline after path) → archived.
- Archive name collision → both files survive.
- Option A: draft whose original file is open → still recovered as a window
  (inverse of the old dedup test).
- Recovered-draft window title carries the original filename.

---

## Phase 2 — #194 + #195: encoding and line-ending preservation

Two issues, one subsystem, one branch. Research-grounded design (TextEdit
sample code pattern, verified API behavior):

### Per-document state (new fields on `Document`)

- `readEncoding: String.Encoding` — the rung of the existing detection
  ladder that succeeded (UTF-8 → UTF-16 BOM → CP1252 → Latin-1 → MacRoman).
  Ladder stays; it's already more capable than `usedEncoding:` (verified:
  that API is not a general sniffer — it throws on xattr-less Latin-1).
  Improvement: consult the `com.apple.TextEncoding` xattr first when
  present (format: `<IANA name>;<CFStringEncoding decimal>`, e.g.
  `windows-1252;1280`).
- `hadUTF8BOM: Bool` — verified: `String(data:encoding:.utf8)` keeps U+FEFF
  in the string. Strip it on read (it silently pollutes editing otherwise:
  invisible, offsets counts), record the flag, re-emit the BOM bytes on
  save. Never add a BOM to files that lacked one; UTF-16 writes its BOM
  automatically.
- `lineEnding: LineEnding` (`lf`, `crlf`, `cr`) — detect by first occurrence
  on read (`\r\n` before `\r`), normalize the buffer to `\n` internally
  (the pre-4.2 CotEditor pattern; NSTextView inserts `\n` on Return
  regardless, so normalize-internally avoids mixed buffers for free),
  convert back on save. Ignore U+2028/2029/0085 for the indicator.

### Saving

- `data(ofType:)` encodes with `readEncoding` (with line-ending conversion
  applied), not hard-coded UTF-8.
- Write the `com.apple.TextEncoding` xattr via
  `fileAttributesToWrite(to:ofType:for:originalContentsURL:)`
  (`NSFileExtendedAttributes` key) so it survives safe-save — the same
  mechanism #157 already plans for view settings; build it once here.
- **Representability**: if `text.data(using: readEncoding)` returns nil
  (user typed characters the original encoding can't hold — verified: emoji
  in CP1252 → nil; lossy conversion destroys content), do not silently
  convert. TextEdit's pattern: fail the save with a recoverable error.
  Jot-scale UX: alert offering "Save as UTF-8" (updates `readEncoding`
  forward) or "Cancel". Check at autosave-safety time too
  (`checkAutosavingSafety`), since autosave has no save-panel moment.

### Status bar (#195)

- Word-count bar gains two passive indicators: encoding name ("UTF-8",
  "CP1252", "UTF-8 BOM") and line endings ("LF"/"CRLF"/"CR"). No picker in
  this phase — visibility only, per the issue.

### Tests

- Round-trip per ladder rung: read fixture bytes → edit → save → byte
  comparison (encoding preserved, line endings preserved, BOM preserved).
- BOM stripped from buffer on read; re-emitted on save; absent stays absent.
- Representability: CP1252 document + emoji → save produces the error path,
  "Save as UTF-8" converts and succeeds.
- xattr written on save and consulted on read (real save cycle, not
  setxattr, per the #157 trap notes).
- Mixed-endings fixture: first-occurrence detection is deterministic.

---

## Phase 3 — #98 + #193: document types and Dock drop

Likely one root-cause area (Launch Services type declarations), so
diagnose together; may split into two PRs if the causes turn out unrelated.

- #98 diagnosis first, before any fix: reproduce via `open -a Jot file.txt`
  (same odoc path as Dock drop), check Console for Launch Services errors,
  test dev build vs App Store build, verify with a file whose UTI
  unambiguously matches a declared type. NSDocument apps need no
  `application(_:open:)` — if the plumbing is right, absence of it is not
  the bug; resist adding one as a bandaid until the actual failure is
  understood.
- #193 changes (Info.plist): add `public.json` + `public.xml` (Editor /
  Alternate), add `public.text` catch-all (Viewer / None), fix
  `public.source-code` role Viewer → Editor to match actual behavior.
- Sync `EditorTextView.supportedTypes` — or better, derive from
  `NSDocumentController` so the list can't drift again (same
  source-of-truth lesson as #211).
- Tests: unit-test the type-acceptance logic; Dock drop itself is a manual
  test matrix (Dock drop, Finder Open With, drag to editor window, File >
  Open) across .txt/.md/.json/.xml/.yaml.

## Phase 4 — #158: infer initial mode from file type

Small, but the precedence chain must be explicit because three systems now
touch mode (found during planning: `EditorViewController` already encodes
`currentMode` in window restorable state, lines 315/350):

1. Window restoration state (relaunch) — wins; already implemented.
2. Per-document xattr override (#157, Phase 6) — wins over inference when
   present.
3. UTI-based inference (this issue): document type conforms to
   `net.daringfireball.markdown` → markdown; else plain text.
4. Stock default (plain text) for untitled documents.

Implement as a computed initial mode at document-open time, set before
initial styling (avoid a plain-text render followed by a markdown restyle).
Tests: mode after opening .md fixture vs .txt fixture; untitled default;
restoration still wins on relaunch.

## Phase 5 — #126: Duplicate / Rename… / Move To…

Storyboard-only: three menu items targeting First Responder
(`duplicateDocument:` ⇧⌘S, `renameDocument:`, `moveDocument:`). NSDocument
provides implementations and validation; the existing `duplicate()`
override finally becomes reachable. Manual test: duplicate carries text and
mode; rename/move behave with autosave; Option-key File menu shows
"Save As…" substitution.

## Phase 6 — #157: per-document view settings via xattr

Last because it builds on Phase 2's `fileAttributesToWrite` mechanism and
Phase 4's precedence chain. The issue's own design notes are already
thorough (store overrides not snapshots; xattr via safe-save attributes;
untitled documents hold pending overrides in memory). Scope for this
milestone: mode + line-numbers overrides only. Tests per the issue: xattr
round-trip through a real save, override-vs-default fall-through,
duplication behavior.

---

## Sequencing and risk notes

- Phases are independent enough to reorder if something blocks, except
  Phase 6 (needs 2 and 4).
- Phase 2 is the largest and touches every save path — spike branch
  (`spike/encoding-preservation`) if `data(ofType:)` changes feel risky,
  per the usual workflow for risky refactors.
- Phase 3's Dock-drop fix may require App Store build verification
  (sandbox/LS behavior can differ from dev builds) — plan a TestFlight or
  archive-build check before release.
- Test-infra tie-ins: #174 (isolate preference tests) becomes more urgent
  once Phase 6 writes per-document state; #135's restore-flow coverage
  overlaps Phase 1's tests — check both when closing this milestone.

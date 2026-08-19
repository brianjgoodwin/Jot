# Jot

Opinionated macOS text editor. Pure AppKit, no SwiftUI. Solo developer;
readable, obvious code beats clever code.

## Building and testing

- `xcodebuild` needs `DEVELOPER_DIR=/Applications/Xcode.app` set.
- Build: `DEVELOPER_DIR=/Applications/Xcode.app xcodebuild -scheme Jot build`
- Test: `DEVELOPER_DIR=/Applications/Xcode.app xcodebuild -scheme Jot test`
- Release-configuration tests need `ENABLE_TESTABILITY=YES` (the tests use
  `@testable import`).
- CI runs a newer Xcode than the local install. Local green is not CI
  green — always verify PR checks after pushing.

## Branch and release model

- Work happens on `develop`. PRs target `develop`, never `main` — which
  means GitHub never auto-closes issues from PR merges; close them
  manually.
- `main` mirrors the shipped App Store version and is only fast-forwarded
  to release tags (e.g. `v1.0.10`) after Apple approval. To reason about
  shipped behavior, read the release tag, not `main`.
- Current cycle (2026): updates stack on `develop` toward a 2.0 release.
  No version bumps on feature PRs during this cycle. `develop` stays
  releasable at all times.
- Conventional commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`),
  with the issue number in the subject, e.g. `feat: emit link titles in
  preview HTML (#30)`.
- Don't push branches or open PRs until Brian says so for that specific
  branch. Brian tests locally before any PR.

## Project gotchas

- The Xcode project uses filesystem-synchronized groups (objectVersion
  70): files on disk auto-join targets — no pbxproj editing needed to add
  a file. Branches based on old release tags (v1.0.9 and earlier) predate
  this and need explicit pbxproj entries.
- Xcode silently re-serializes storyboards and the pbxproj when it has
  the project open. Check `git status` for churn before committing, and
  close the Xcode project before switching branches.
- Jot's own `Document` class shadows `Markdown.Document` from
  swift-markdown — always qualify the module type.
- swift-markdown enables cmark smart punctuation by default; the preview
  renderer passes `.disableSmartOpts` deliberately. The preview must show
  markdown as written.

## Testing rules

- Tests must never touch the real UserDefaults domain (#174) — use the
  isolated-suite pattern in the preference tests.
- Tests must never present real UI. Anything that can raise a dialog gets
  a stub override (see `ConsentStubDocument` in `DocumentTests.swift`);
  a test run that stalls for seconds has probably opened a live modal.
- The preview renderer is pinned against the CommonMark 0.31.2 spec suite
  (`CommonMarkSpecTriage.swift`) with exact bucket counts. If a change
  shifts any count, re-triage the affected examples — don't just bump the
  number.

## Reference docs

- `docs/issue-clusters.md` — issue-to-cluster map, milestone sequencing,
  and recorded decisions. Start here for planning.
- `docs/help-notes.md` — user-facing help content. Brian writes the
  personality prose; keep his voice.
- `docs/spikes/` — measurement spike findings (e.g. editor AST
  highlighting performance).
- `docs/PERFORMANCE.md` — performance notes and signpost conventions.

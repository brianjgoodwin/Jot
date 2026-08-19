# Preview Rebuild Plan (#38)

Planning scaffold for the preview window rebuild. Consumes #30 (swift-markdown
renderer, PR #251); folds in #137 (WKWebView memory), #134 (CSP verification),
#52 (accessibility). Captured 2026-08-19 from user-story discussion.

---

## User stories

### The meeting agenda (Brian)

Brian keeps a plain-text document open in the background at work all day,
dropping file names and list names into it for later reference. He realizes
he has a meeting in 30 minutes, he's supposed to set the agenda, and he
forgot. He hates Microsoft Word. He opens a new window from his
meeting-agenda template (a couple of headings in a standard format),
populates it, and opens the markdown preview -- which isn't fancy; it looks
more or less like GitHub's markdown rendering. He prints, chooses Open in
Preview, saves the PDF, and Slacks it to his team. They compliment the
beautifully minimal agenda. They can't put their finger on it, but it
doesn't "feel" like it was made with Word.

### The Substack draft (Nick)

Nick is a comedy writer. He drafts his Substack posts in markdown and keeps
a folder of drafts in various states of done-ness. A friend asks to see the
piece whose ending punchline he'd mentioned struggling with. He opens the
draft, opens the preview, and does the same print-to-PDF export -- but with
a different theme, one that reads like a traditional print publication's
website (serif fonts, wider horizontal padding). He sends it to his friend.

---

## What the stories establish

1. **Output is the climax, not the preview.** Both stories end at
   print-to-PDF via the standard macOS print dialog. Print fidelity is the
   heart of #38, not a checkbox: real margins, sane page breaks, tables
   that don't split mid-row, no screen-only chrome on paper.
2. **The print dialog's PDF dropdown is the export feature.** Once
   printing works, PDF export exists. #43 (Export to PDF/HTML) shrinks to
   a convenience menu item later -- not a separate pipeline.
3. **The default theme is GitHub-ish.** Concrete, testable target for
   #38's one built-in theme.
4. **The theme architecture gets set here.** Nick's serif theme is #40,
   but #38 must build the CSS injection point theme-shaped from day one
   (no hardcoded style block), and themes must apply to both screen and
   print. #40 (curated themes) is confirmed 2.0 core, per the scope
   contract ("syntax highlighting with preview, themes, and printing").
5. **Jot is a leave-it-running app.** The all-day background scratch doc
   is the real-world case for #137: a preview window that holds its
   WKWebView after close bleeds memory against an all-day session.

---

## Decisions

- **One preview window, not one per document.** (Decided 2026-08-19.)
  The singleton follows the classic Mac grammar Jot is built on: document
  windows multiply, utility windows don't (one Find panel, one Fonts
  panel, one preview) -- same pattern as Marked. Per-document previews
  fail concretely: they're incoherent with tabbed editors, they multiply
  WKWebViews (recreating #137 by construction), and they make "which
  window does Cmd+P print" ambiguous. Accepted cost: no side-by-side
  preview of two documents (niche; print both to PDF if ever needed).
  - **Tracking rule:** the preview follows the frontmost *markdown-mode*
    document and holds its last target when a non-markdown window becomes
    main -- plain-text windows are invisible to it (the scratchpad in
    Brian's agenda story must not blank the preview). If the previewed
    document closes, fall to the frontmost remaining markdown document,
    else show the empty state (needed anyway for "preview opened with no
    markdown doc in front").
  - "Pin preview to this document" is possible 2.x territory if users ask;
    not 2.0.
- **Update mechanism: load the shell once, swap the body.** (Decided
  2026-08-19.) The Cmd+R-style flash comes from loadHTMLString being a
  full navigation. Instead, load the HTML shell (head, CSP meta, theme
  CSS) once when the preview opens, then inject updates via
  callAsyncJavaScript ("document.body.innerHTML = html" with the HTML
  passed as a real argument -- never string-built into a JS literal).
  No navigation, no flash, and scroll position survives for free because
  the document never reloads. Full loadHTMLString only where a "new page"
  is honest: preview open and document retarget.
- **Debounce: classic perform(afterDelay:), trailing.** (Decided
  2026-08-19.) textDidChange cancels the pending render
  (cancelPreviousPerformRequests) and re-arms perform(#selector,
  afterDelay: 0.75). Render fires after typing stops. 0.75 s is a taste
  constant (0.5 attentive, 1.5 document-like), trivially tunable since
  the body swap makes eager renders visually free. No Combine, no timer
  bookkeeping.
- **No renders while occluded.** Skip rendering when
  NSWindow.occlusionState says the preview is closed, miniaturized, or
  fully covered; one catch-up render when it becomes visible. The preview
  costs nothing during an all-day session in other windows.
- **No print headers/footers.** Bare pages are part of the not-Word feel;
  word-processor territory starts there. Explicitly open to reversal on
  user feedback, but the current answer is no. (Decided 2026-08-19.)
- **Editor windows keep their own plain-text print path**, mirroring
  TextEdit ("sometimes you just need a piece of paper that says 'sign in
  here'"). Cmd+P routes by responder chain: editor focused prints plain
  text, preview focused prints the rendered document. No mode, no chooser.
  Pulls #196 (printableView() ignores the user's font choice) into this
  phase's orbit -- that bug is the sign-in-sheet story failing.
- **Theme picker lives in Settings.** (Decided 2026-08-19, superseding an
  earlier lean toward a picker on the preview window.) App-wide setting,
  not per-document. Feeds the #27 tabbed-Settings pressure -- another
  reason that window needs structure.
- **Print margins: system defaults.** (Decided 2026-08-19.) No
  opinionated page setup; the standard Page Setup dialog already exists
  for anyone who cares.

---

## Technical risks

- **WKWebView printing is the roughest edge of the API.** Proper
  printOperation(with:) support only arrived in macOS 11 and pagination
  has known quirks. Since printing is the heart of both stories, run a
  small proof-of-concept spike *before* the window rebuild -- same
  measure-first discipline as the editor-AST spike. Kill criteria to
  write before spiking: acceptable pagination of tables/code blocks,
  margins honored, print CSS respected. Two more items for the same
  spike, forced by the body-swap decision: (1) confirm app-injected
  callAsyncJavaScript runs despite the page's default-src 'none' CSP
  (WebKit treats it as user-agent script, exempt from page CSP -- prove
  it, don't assume it; the CSP must still block scripts in the *injected
  content*), and (2) confirm printOperation(with:) prints the swapped
  DOM, not the originally loaded string.
- **Local images need loadFileURL** (deferred from the #30 review batch):
  an about:blank origin cannot load file: subresources. Switching to
  loadFileURL changes the origin and therefore the CSP posture -- re-verify
  #134 after this change, not before.

---

## Open questions

- Scroll position across *retargets*: re-renders preserve scroll for free
  now (body swap, no navigation), but when the preview switches from
  document A to B and back, should it remember where you were in A?
  **Deliberately left open** (2026-08-19): the assumptions here may not
  survive first contact with AppKit -- answer it during the build, with
  the real behavior in hand.

---

## Deferred notes with homes here

- Tight-list rendering: renderer wraps loose-list items in <p>; pinned in
  tests, cosmetic decision deferred to the rebuild.
- #52 a11y checklist (9 items from the review batch) -- bake into the HTML
  template from the start: prefers-color-scheme dark mode, contrast,
  lang attribute, reduced-motion, focus visibility.
- #111 (help overstates preview) lands last, after the rebuild ships, in
  Brian's voice.

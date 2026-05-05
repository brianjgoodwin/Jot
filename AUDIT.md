# Jot App Audit

*Audited: 2026-05-05*

---

## Security

### HIGH — Markdown XSS / Data Exfiltration
**File:** `Jot/MarkdownPreviewViewController.swift`

The Down library passes raw HTML through by default. A user who opens a malicious `.md` file can have `<script>` tags execute in the preview WebView. Because `com.apple.security.network.client` is enabled, those scripts can make outbound HTTP requests — meaning document contents could be silently exfiltrated on preview.

**Fix:** Pass `DownOptions.safe` to Down:
```swift
let htmlString = try? down.toHTML(flags: .safe)
```

---

### MEDIUM — Help WebView Loads Arbitrary External URLs In-App
**File:** `Jot/HelpViewController.swift`

The navigation delegate only handles `github.com/brianjgoodwin/Jot/` and `mailto:` links. All other URLs — including arbitrary `http://` links — load inside the app's WKWebView rather than opening in Safari.

**Fix:**
```swift
if url.isFileURL {
    decisionHandler(.allow)
} else {
    NSWorkspace.shared.open(url)
    decisionHandler(.cancel)
}
```

---

### LOW — `network.client` Entitlement Has No Documented Purpose
**File:** `Jot/Jot.entitlements`

No app code makes outbound network calls for a legitimate feature. This entitlement is what makes the XSS issue meaningfully exploitable. If truly unused, remove it.

---

### LOW — Silent Error Suppression in Markdown Rendering
**File:** `Jot/MarkdownPreviewViewController.swift`

`try? down.toHTML()` silently swallows errors. Use `do/catch` and log the failure so users aren't left with a blank preview and no explanation.

---

## Performance

### HIGH — Full-Document Restyling on Every Keystroke
**Files:** `Jot/ViewController.swift`, `Jot/MarkdownProcessor.swift`

`textDidChange` calls `MarkdownProcessor.applyMarkdownStyling` synchronously on every keypress with no debounce. Word count is debounced at 0.5s but the far more expensive styling pass is not. Apply the same debounce to styling.

---

### HIGH — Regex Compiled Fresh on Every Call
**File:** `Jot/MarkdownProcessor.swift`

Every sub-function (`applyHeadings`, `applyStyle`, `applyCodeStyle`, `applyLinks`, `applyStrikethrough`, both list functions) calls `NSRegularExpression(pattern:options:)` inline on every invocation. Cache all patterns as `private static let` properties — compilation then happens once per process lifetime.

---

### HIGH — Font Conversion Inside Match Loop
**File:** `Jot/MarkdownProcessor.swift`

`NSFontManager.shared.convert(selectedFont, toHaveTrait:)` is called once per regex match inside `applyHeadings` and `applyStyle`. The input font and trait mask are fixed for the entire enumeration — hoist the conversion above `enumerateMatches`.

---

### MEDIUM — No `beginEditing`/`endEditing` Bracketing
**File:** `Jot/MarkdownProcessor.swift`

Without wrapping all `textStorage.addAttribute` calls in `beginEditing()`/`endEditing()`, the layout engine can be invoked dozens of times per keystroke instead of once. Bracket the entire `applyMarkdownStyling` call.

---

### MEDIUM — `range` Parameter Is Ignored by Half the Sub-Functions
**File:** `Jot/MarkdownProcessor.swift`

`applyMarkdownStyling` accepts a `range` for incremental updates, but `applyCode`, `applyLinks`, `applyStrikethrough`, and `applyListStyling` all ignore it and scan the full document. Either remove the parameter and be explicit about full-document cost, or actually thread the range through every sub-function.

---

### MEDIUM — Preview Window Leaked on Every Open
**File:** `Jot/AppDelegate.swift`

`showMarkdownPreview` instantiates a new `MarkdownPreviewWindowController` + `WKWebView` every time it's called. The `previewWindowController` property exists but is never assigned. Each leaked `WKWebView` carries significant memory cost. Apply the same cache-and-reuse pattern the other four window controllers already use.

---

## Code Quality

### Correctness Bugs

- **`Document.duplicate()`** — uses `as! Document` force cast; will crash if `super.duplicate()` returns an unexpected type. Use `guard let` with a proper error throw.
- **Font size type mismatch** (`SettingsViewController.swift`) — size stored as `Int` in `NSMenuItem.representedObject` but read back from `UserDefaults` as `Float`. Use a consistent type throughout.
- **`setupWordCountToggle()`** (`ViewController.swift`) — always forces state to `.on`, ignoring any persisted user preference.

---

### Dead Code — Delete These Files

- `Jot/temp.swift` — old snapshot of MarkdownFormatter, entirely commented out
- `Jot/MarkdownFormatter.swift` — entirely commented out
- `Jot/FontManager.swift` — entirely commented out

---

### Dead Code — Remove From Existing Files

- `EditorMode.swift`: global `var currentEditorMode` — never read anywhere; `ViewController` tracks its own `currentMode`
- `ViewController.swift`: `isUpdatingText`, `updateDocumentSize()`, `formatFileSize(_:)`, `applyMarkdownStyles()`, empty `viewWillAppear`, empty `representedObject` didSet, duplicate `textView.delegate = self` assignment
- `AppDelegate.swift`: `getCurrentViewController()` — defined but never called

---

### Debug Prints in Production Code

Remove or guard behind `#if DEBUG`:

- `ViewController.didSelectFont`: `print("Setting font to: ...")`
- `SettingsViewController.changeFont`: two `print()` calls
- `AppDelegate.openAcknowledgements`: `print("Acknowledgements file not found")`

---

### Dark Mode — Hardcoded Colors
**File:** `Jot/MarkdownProcessor.swift`

`NSColor.darkGray`, `NSColor.blue`, and `NSColor(white: 0.95, alpha: 1.0)` don't adapt to dark mode. Replace with semantic colors: `NSColor.secondaryLabelColor`, `NSColor.linkColor`, `NSColor.textBackgroundColor`.

---

### Logic Duplication

Word count and paragraph count logic is independently implemented in both `ViewController` and `WordCountViewController`. Extract into a shared utility.

---

### Print View Ignores Paper Size
**File:** `Jot/Document.swift`

`printableView()` uses a hardcoded `NSRect(0, 0, 400, 600)` — size it from `NSPrintInfo` instead.

---

## Priority Order

| Priority | Item |
|---|---|
| 1 | Fix markdown XSS — pass `DownOptions.safe` to Down |
| 2 | Fix Help WebView navigation policy |
| 3 | Debounce markdown styling + cache regexes + hoist font conversion |
| 4 | Add `beginEditing`/`endEditing` around attribute changes |
| 5 | Fix preview window leak in `showMarkdownPreview` |
| 6 | Fix dark mode colors in `MarkdownProcessor` |
| 7 | Delete `temp.swift`, `MarkdownFormatter.swift`, `FontManager.swift` |
| 8 | Remove remaining dead code and debug prints |
| 9 | Consider removing `network.client` entitlement if unneeded |

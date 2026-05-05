# Jot 1.0.5 Audit

*Audited: 2026-05-05 — branch `1.0.5`, diffed against `main`*

This audit covers new issues introduced in 1.0.5, notes which issues from the `main` audit were fixed, and which remain open.

---

## Fixes Since `main` — Good Work

- `Document.duplicate()` force cast replaced with `guard let` + proper error throw ✅
- Force unwrap `aboutWindowController!.showWindow` → optional chaining ✅
- Font size validation (clamped to 6–144pt) in `didSelectFontSize` and `loadFontPreferences` ✅
- File size limits added to `Document.read(from:ofType:)` (100MB hard limit, 10MB warning) ✅
- File size limit added to `Document.write(to:ofType:)` ✅
- `NSLocalizedDescriptionKey` added to error `userInfo` dicts for user-readable messages ✅

---

## New Issues Introduced in 1.0.5

### SECURITY / PRIVACY — HIGH: Debug Log Written to Downloads Unconditionally
**File:** `Jot/Logger.swift`, `Jot/Jot.entitlements`

`logToFile()` writes a plain-text log to `~/Downloads/Jot_Debug.log` on every run — in production, for all users, always. To support this, the entitlement `com.apple.security.files.downloads.read-write` was added, which is a significant sandbox expansion.

Problems:
- The log includes full file-system paths (e.g., `unsavedStateURL.path`, `fileURL.path`) which could expose the user's directory layout.
- `applicationDidFinishLaunching` contains `logToFile("Test log message")` — an obvious debug artifact that was never removed.
- The log file grows indefinitely with no rotation or size cap.
- `~/Downloads` is user-visible, meaning the log file will surprise users who notice it.
- The `downloads.read-write` entitlement grants write access to a high-value folder; it was added solely for debugging and has no production purpose.

**Fix:** Remove `logToFile` calls from production builds entirely, or gate the entire function behind `#if DEBUG`. Remove the `com.apple.security.files.downloads.read-write` entitlement. If persistent logging is genuinely needed in production, write to `Application Support/Jot/` (already used for unsaved states) rather than Downloads — no additional entitlement needed since that location is within the existing sandbox.

```swift
public func logToFile(_ message: String) {
    #if DEBUG
    // ... existing implementation, but write to Application Support, not Downloads
    #endif
}
```

---

### BUG — HIGH: Unicode/NSRange Mismatch in `applyInvisibleCharactersDisplay`
**File:** `Jot/ViewController.swift` (~line 383)

```swift
for (index, char) in text.enumerated() {
    let range = NSRange(location: index, length: 1)
    textStorage.addAttribute(.backgroundColor, ..., range: range)
}
```

`String.enumerated()` yields `Character` indices (grapheme cluster offsets), but `NSRange` expects UTF-16 code unit offsets. For any document containing emoji, accented characters, or other multi-codepoint characters, `index` and the correct UTF-16 offset will diverge — causing attributes to be applied to the wrong characters, or crashing with an out-of-bounds range.

**Fix:** Use `NSString` offsets directly:
```swift
var utf16Offset = 0
for char in text {
    let charLength = char.utf16.count
    let range = NSRange(location: utf16Offset, length: charLength)
    if char == " " { ... }
    else if char == "\t" { ... }
    utf16Offset += charLength
}
```

---

### PERFORMANCE — HIGH: `applyInvisibleCharactersDisplay()` Called on Every Keystroke
**File:** `Jot/ViewController.swift` (~line 607)

When invisible characters are enabled, `textDidChange` calls `applyInvisibleCharactersDisplay()` synchronously on every keypress. This is a full O(n) character-by-character scan of the entire document with individual `addAttribute` calls, and it's not debounced at all. Combined with the existing markdown restyling pass (also not debounced), a user typing with both modes active triggers two full-document scans per keypress.

**Fix:** Debounce `applyInvisibleCharactersDisplay()` with the same timer used for word count, or limit it to the changed range.

---

### BUG — MEDIUM: Dead Code Branches in `convertSmartQuotes`
**File:** `Jot/ViewController.swift` (~line 519)

The `"` handling block checks `prevChar` context to decide which quote to emit — but both `if` and `else` branches execute identical code: append the same quote character and toggle `inDoubleQuote`. The context check is completely dead:
```swift
if prevChar.isWhitespace || prevChar.isPunctuation || index == 0 {
    convertedString.append(inDoubleQuote ? "\u{201D}" : "\u{201C}")
    inDoubleQuote.toggle()
} else {
    convertedString.append(inDoubleQuote ? "\u{201D}" : "\u{201C}") // identical
    inDoubleQuote.toggle()
}
```
The intent was presumably to distinguish opening vs. closing quotes based on context, but the implementation doesn't achieve it.

---

### RELIABILITY — MEDIUM: Two `asyncAfter` Time-Based Hacks
**File:** `Jot/ViewController.swift` (lines 50, 69)

`viewDidLoad` uses `DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)` to apply restored document text, and `viewWillAppear` uses `asyncAfter(.now() + 0.1)` to restore cursor position. These are race conditions waiting to happen — if the system is slow, the 0.5s delay may fire before the view is ready; if it's fast, it's unnecessary latency. The fix for the text-not-appearing problem should be architectural (e.g., proper `NSDocument`/`NSWindowController` coordination), not a sleep.

---

### CODE QUALITY — LOW: `IMPLEMENTATION_NOTES.md` Committed to Repo
This is a developer planning document. It shouldn't live in the main source tree and shouldn't ship in a release branch. Move to a wiki, PR description, or personal notes — or delete once the features are shipped.

---

### CODE QUALITY — LOW: Entitlement Without Matching Privacy Description
**File:** `PrivacyInfo.xcprivacy`, `Jot/Jot.entitlements`

`com.apple.security.files.downloads.read-write` was added to the entitlements but there is no corresponding entry in `PrivacyInfo.xcprivacy` explaining why the app accesses the Downloads folder. Apple's privacy manifest requirements may flag this during App Store review.

---

## Issues From `main` Audit Still Open

The following issues from the `main` audit were **not addressed** in 1.0.5:

| Issue | Severity | File |
|---|---|---|
| Markdown XSS — `DownOptions.safe` not set | HIGH | `MarkdownPreviewViewController.swift` |
| Help WebView allows arbitrary external URLs in-app | MEDIUM | `HelpViewController.swift` |
| `network.client` entitlement unused by app features | LOW | `Jot.entitlements` |
| Markdown regex compiled fresh on every keystroke | HIGH | `MarkdownProcessor.swift` |
| No `beginEditing`/`endEditing` bracketing | MEDIUM | `MarkdownProcessor.swift` |
| Markdown styling not debounced | HIGH | `ViewController.swift` |
| `showMarkdownPreview` creates new window every call | MEDIUM | `AppDelegate.swift` |
| Hardcoded `NSColor` values don't adapt to dark mode | MEDIUM | `MarkdownProcessor.swift` |
| `removeMarkdownStyling` uses hardcoded black/white | MEDIUM | `ViewController.swift` |
| `temp.swift`, `FontManager.swift`, `MarkdownFormatter.swift` — entirely dead | LOW | Various |
| `var currentEditorMode` global never used | LOW | `EditorMode.swift` |
| `isUpdatingText` declared but never used | LOW | `ViewController.swift` |
| `updateDocumentSize()` / `formatFileSize()` never called | LOW | `ViewController.swift` |
| `applyMarkdownStyles()` unused | LOW | `ViewController.swift` |
| `getCurrentViewController()` unused | LOW | `AppDelegate.swift` |
| `representedObject` didSet empty | LOW | `ViewController.swift` |
| Debug `print` in `SettingsViewController.changeFont` | LOW | `SettingsViewController.swift` |
| Debug `print` in `ViewController.didSelectFont` | LOW | `ViewController.swift` |
| `setupWordCountToggle()` always forces `.on` | LOW | `ViewController.swift` |
| Print view hardcoded 400×600 frame | LOW | `Document.swift` |
| Word count logic duplicated across two view controllers | LOW | `ViewController.swift`, `WordCountViewController.swift` |

---

## Priority Order for 1.0.5

| Priority | Item |
|---|---|
| 1 | Remove `logToFile` from production / remove `downloads.read-write` entitlement |
| 2 | Fix Markdown XSS — `DownOptions.safe` |
| 3 | Fix Help WebView navigation policy |
| 4 | Fix Unicode/NSRange bug in `applyInvisibleCharactersDisplay` |
| 5 | Debounce markdown styling + cache regexes + hoist font conversion |
| 6 | Debounce or limit range of `applyInvisibleCharactersDisplay` |
| 7 | Fix dead-code branches in `convertSmartQuotes` |
| 8 | Replace `asyncAfter` hacks with proper document coordination |
| 9 | Fix preview window leak in `showMarkdownPreview` |
| 10 | Fix dark mode colors throughout |
| 11 | Delete `IMPLEMENTATION_NOTES.md` (or move to wiki) |
| 12 | Remaining dead code cleanup from `main` audit |

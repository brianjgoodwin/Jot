# Quality of Life Features - Implementation Notes

## Features Implemented

### 1. ✅ Updated Font Size Menu
**File:** `SettingsViewController.swift:67-79`

Changed from 43 font sizes (6-48 by 1) to 15 common sizes:
- [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 72]
- Much cleaner UI and easier selection

### 2. ✅ Character Count Alongside Word Count
**File:** `ViewController.swift:194-207`

The word count label now shows:
- Format: "1,234 words • 5,678 chars"
- Uses the existing number formatter for consistency
- Updates in real-time as user types

### 3. ✅ Show Invisible Characters Toggle
**Files:**
- `ViewController.swift:317-343` (implementation)
- `SettingsViewController.swift:145-154` (UI)

New setting in preferences to show/hide:
- Spaces
- Tabs
- Control characters
- Persisted in UserDefaults as "showInvisibleCharacters"

**UI Required:** Add checkbox to Settings storyboard with IBOutlet `invisibleCharactersCheckbox` and IBAction `toggleInvisibleCharacters`

### 4. ✅ Tab Width Preference
**Files:**
- `ViewController.swift:345-356, 304-308` (implementation)
- `SettingsViewController.swift:156-181` (UI)

User can select tab width:
- Options: 2, 4, or 8 spaces
- Default: 4 spaces
- Dynamically calculates width based on current font
- Persisted in UserDefaults as "tabWidth"

**UI Required:** Add popup button to Settings storyboard with IBOutlet `tabWidthPopupButton`

### 5. ✅ Save/Restore Last Used Mode
**File:** `ViewController.swift:213-245`

Editor mode (Markdown/Plain Text) now persists:
- Saves whenever mode is changed
- Restores on app launch
- Updates UI to reflect saved mode
- Persisted in UserDefaults as "lastUsedEditorMode"

### 6. ✅ Zoom In/Out Keyboard Shortcuts
**File:** `ViewController.swift:400-419`

Three new actions:
- `zoomIn`: Increases font size by 1pt (max 144)
- `zoomOut`: Decreases font size by 1pt (min 6)
- `resetZoom`: Resets to user's saved font preference

**UI Required:** Add menu items in Main.storyboard:
- "Zoom In" → Cmd+Plus → connect to First Responder → zoomIn
- "Zoom Out" → Cmd+Minus → connect to First Responder → zoomOut
- "Reset Zoom" → Cmd+0 → connect to First Responder → resetZoom

### 7. ✅ Restore Cursor Position
**Files:**
- `ViewController.swift:64-77, 421-442` (implementation)
- `Document.swift:152-159` (cursor position key)

Cursor position now persists per document:
- Saves when view disappears
- Restores when view appears
- Uses document-specific key (file path or unsaved ID)
- Validates position is within bounds before restoring

## Next Steps

### Storyboard Updates Needed

You'll need to open `Main.storyboard` and make these connections:

1. **Settings Window** - Add UI controls:
   - Checkbox: `invisibleCharactersCheckbox`
     - Action: `toggleInvisibleCharacters`
   - Popup Button: `tabWidthPopupButton`
     - (Setup handled in code)

2. **View Menu** - Add zoom menu items:
   - Menu Item: "Zoom In" (⌘+)
     - Connect to First Responder → `zoomIn:`
   - Menu Item: "Zoom Out" (⌘−)
     - Connect to First Responder → `zoomOut:`
   - Menu Item: "Reset Zoom" (⌘0)
     - Connect to First Responder → `resetZoom:`

### Protocol Updates

The `TextSettingsDelegate` protocol was extended in `SettingsViewController.swift:10-17` to include:
- `func setShowInvisibleCharacters(_ enabled: Bool)`
- `func setTabWidth(_ width: Int)`

These are already implemented in `ViewController` which conforms to the protocol.

## Testing Checklist

- [ ] Font size menu shows 15 common sizes instead of 43
- [ ] Word count displays both words and characters
- [ ] Invisible characters toggle works (may need storyboard connection)
- [ ] Tab width can be changed in settings (may need storyboard connection)
- [ ] Last used mode (Markdown/Plain Text) persists between sessions
- [ ] Zoom in/out keyboard shortcuts work (may need menu items)
- [ ] Cursor position restores when reopening documents

## Notes

- All features use UserDefaults for persistence
- All features have logging statements for debugging
- Code follows existing patterns in the codebase
- No breaking changes to existing functionality

<div align="center">
  <h1>Jot</h1>
  <p>A plain text editor for macOS with markdown syntax highlighting.</p>

  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
  [![Platform: macOS](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)]()
  [![Swift](https://img.shields.io/badge/Swift-5-orange.svg)]()
</div>

## About

Jot is a lightweight, opinionated text editor for macOS. It sits somewhere between TextEdit and a full IDE -- a place to write plain text and markdown without the overhead of a feature-heavy editor.

Built entirely with AppKit and Cocoa. No Electron, no SwiftUI, no web views in the editor. A mac-assed mac app.

![Jot in dark mode](/Screenshot3.png)

![Jot in light mode](/Screenshot4.png)

### Features

- Plain text editing with a clean, distraction-free interface
- Markdown syntax highlighting (headings, bold, italic, code, links, lists, blockquotes, tables, strikethrough, horizontal rules)
- Markdown preview via WebKit
- Word count, line count, and file size statistics
- Configurable font and font size
- Word wrap toggle
- Autosave (toggleable)
- Unsaved document state restoration on relaunch
- Encoding fallback for non-UTF-8 files
- Dark mode support with adaptive syntax highlighting colors

### Built With

- Swift
- AppKit / Cocoa
- [Down](https://github.com/johnxnot/Down) (markdown-to-HTML for preview)
- WebKit (preview rendering only)

## Getting Started

### Prerequisites

- macOS 10.15 (Catalina) or later
- Xcode 15 or later (to build from source)

### Installation

Jot is available on the [Mac App Store](https://apps.apple.com/app/jot).

To build from source:

1. Clone the repository
   ```sh
   git clone https://github.com/brianjgoodwin/Jot.git
   ```
2. Open `Jot.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## Usage

Jot opens plain text and markdown files. Use the mode popup in the toolbar to switch between Plain Text and Markdown modes (or Cmd+Shift+M). In Markdown mode, syntax is highlighted in the editor as you type.

Open the Markdown Preview (Cmd+Opt+P) to see rendered output.

## Roadmap

See the [open issues](https://github.com/brianjgoodwin/Jot/issues) and [milestones](https://github.com/brianjgoodwin/Jot/milestones) for planned features and known issues.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Down](https://github.com/johnxnot/Down) for markdown-to-HTML conversion
- [Best-README-Template](https://github.com/othneildrew/Best-README-Template) for README structure

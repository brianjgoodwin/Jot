# Jot - Text Editor Help

Table of Contents

- Getting Started
- Features Overview
- Markdown Styling Guide
- Feedback and Support

## Getting Started

Jot this down with Jot - Text Editor, a lightweight, speedy application for working with plain text (.txt) and Markdown (.md) files. It has optional, light syntax highlighting for Markdown as well as previews to see how your writing will look when rendered for the web.

It isn’t an IDE, and it isn’t a full-blown word processor. It’s more of a scratchpad. Keep it open and save code snippets, or jot down meeting notes. Oh, and it feels like an old-fashioned Mac app (if you’re into that).

## Features Overview

Modes: the bottom, right of each editor window has a popup with two options - plain text and markdown. Markdown Mode applies lightweight syntax highlighting to your file’s contents. Plain text mode is just what it sounds like. You can toggle this on an off in `View > Toggle Format` or ⇧⌘M. The mode has no bearing on what file formats you can read and save, it’s just how you prefer to write.

Word Count: the bottom, left of each editor window shows the live word count of the document you’re editing. You can toggle that off. More document statistics are availabe in `View > Show Word Count` which shows words, characters, lines, paragraphs, estimated reading time, and file size in a floating window. If you have multiple editor windows open, the Word Count window will show the *active* window’s statistics.

Markdown Preview: selecting `View > Markdown Preview` (or pressing ⌥⌘P) will open Markdown Preview. This parses your file’s content and renders it as HTML. Note: previews do not live-update. 


# Markdown Styling Guide

Markdown is a lightweight markup language, created by John Gruber, that allows writers to write human-readable text that converts to HTML easily. 

> Markdown is intended to be as easy-to-read and easy-to-write as is feasible.
> 
> Readability, however, is emphasized above all else. A Markdown-formatted document should be publishable as-is, as plain text, without looking like it’s been marked up with tags or formatting instructions.
[John Gruber](https://daringfireball.net/projects/markdown/syntax)

Jot - Text Editor uses its own, custom engine for markdown syntax highlight. It’s lightweight and fast. It doesn’t support every possible edge case. This is for jotting down meeting notes.

Headers

To create headers, use the # symbol followed by a space. The number of # symbols corresponds to the header level:

# Header 1
## Header 2
### Header 3
#### Header 4
##### Header 5
###### Header 6

Bold

To make text bold, wrap it in two asterisks ** or two underscores __:

**bold text**
__bold text__

Keboard shortcut: ⌘B

Italic

To italicize text, wrap it in one asterisk * or one underscore _:

*italic text*
_italic text_

Keboard shortcut: ⌘I

Strikethrough

To strikethrough text, wrap it in two tildes ~~:

~~strikethrough text~~

Code

Blockquotes

For block quotes, start a line with an angle bracket `>`

> This is a block quote

For inline code, wrap the text in backticks `:

`inline code`

For code blocks, wrap the text in triple backticks ``` with an optional language identifier:

```javascript
		console.log('Hello, world!');
		```
		
Links

To create a link, wrap the link text in square brackets [] and the URL in parentheses ():

[link text](https://example.com)
In Markdown Mode, you can also select some text and paste a copied URL over it: the selection becomes the link text. To replace the selection with the URL instead, use Edit > Paste and Match Style (⌥⇧⌘V).

Lists

For unordered lists, use -, +, or * followed by a space:

- Item 1
+ Item 2
* Item 3
For ordered lists, use numbers followed by a period and a space:

1. Item 1
2. Item 2
3. Item 3
In Markdown Mode, pressing Return inside a list item starts the next item automatically (numbered lists count up as you go). Press Return on an empty item to end the list. Jot doesn't renumber the rest of a numbered list when you insert an item in the middle — adjust the following numbers by hand.

Checklists

For task lists, use a bullet followed by brackets:

- [ ] An open task
- [x] A completed task
Completed tasks appear crossed out in Markdown Mode. Use Format > Toggle Checklist (⌘L) to check or uncheck the current line or every selected line. On lines that have no checkbox yet, the same command adds one — plain lines and bullet items become open tasks.


# Feedback

If you have feedback, you can [email the developer](brian.goodwin@protonmail.com). This is a free project and a labor of love, so we appreciate your understanding and patience.

# NoteDad

NoteDad is a minimal, fast, native macOS note-taking app that stores your notes as plain `.md` and `.txt` files.

## Features

- Native macOS app built with SwiftUI and `NSTextView`.
- Notes are stored in `~/Documents/NoteDad`.
- Human-readable files: Markdown notes use `.md`, plain text notes use `.txt`.
- Inline Markdown rendering while keeping raw Markdown on disk and copy.
- Clickable Markdown tasks with `[ ]` and `[x]` support.
- Fast note switching with `Cmd+P`.
- New notes with `Cmd+N`.
- Minimal editor UI without a permanent sidebar.
- Configurable default note format and editor text size.
- Optional menu bar Quick Note.

## Markdown Support

NoteDad keeps Markdown lightweight and editor-first. Markdown files render common syntax inline:

- Headings
- Lists
- Task checkboxes
- Blockquotes
- Inline code and code blocks
- Bold and italic text
- Links

Plain text notes stay plain and do not apply Markdown styling.

## Storage

Notes are ordinary UTF-8 files:

```text
~/Documents/NoteDad/
```

The title is derived from the first meaningful line. Files remain readable and editable from Finder, TextEdit, VS Code, or any other text editor.

## Shortcuts

- `Cmd+N`: create a new note.
- `Cmd+P`: search and open notes.
- `Esc`: close the command palette.
- `Up` / `Down`: move through command palette results.
- `Enter`: open the selected result.

## Build

```sh
xcodebuild -scheme NoteDad -destination 'platform=macOS' -derivedDataPath /private/tmp/NoteDadDerivedData build
```

## Current Scope

NoteDad is built for direct/local use first. It does not use a database, cloud sync, or a rich toolbar-heavy editor. The goal is a quiet, file-based note app that opens quickly and stays out of the way.

# Snip

**A tiny text expander for your Mac's menu bar.** Type a short trigger like `;sig` anywhere and Snip replaces it with the full text, line breaks included.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Universal](https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-blue)
![Size](https://img.shields.io/badge/download-~110%20KB-brightgreen)
![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)

```
;sig   →   Best regards,
           Your Name
```

---

## Contents

- [Features](#features)
- [Install](#install)
- [Usage](#usage)
- [Permissions](#permissions)
- [Tips](#tips)
- [Limitations](#limitations)
- [Build from source](#build-from-source)
- [How it works](#how-it-works)
- [Privacy](#privacy)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Works everywhere you type:** browsers, Mail, Messages, Slack, Notes, and any other app.
- **Keeps line breaks.** Multi-line messages come out exactly as you wrote them, unlike the built-in macOS and iOS text replacements.
- **Instant.** The text is pasted in one go, not typed out letter by letter.
- **Leaves your clipboard alone.** Whatever you had copied is restored right after.
- **Menu bar only.** No Dock icon and no window to manage. Add, edit and delete snippets from a small panel.
- **Pause switch** for when you need to type a trigger literally.
- **Tiny.** About 270 lines of Swift, no dependencies, no network access.

## Install

### Download

1. Download `Snip.zip` from the [latest release](https://github.com/yossev/snip/releases/latest).
2. Unzip it and drag **Snip.app** into your **Applications** folder.
3. The app isn't notarized by Apple, so the first time you open it, **right-click Snip.app → Open → Open**.

   If macOS still refuses, run this once in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Snip.app
   ```

4. Grant the Accessibility permission (see [Permissions](#permissions)).
5. Optional: to start Snip automatically, add it under **System Settings → General → Login Items**.

### Build it yourself

See [Build from source](#build-from-source).

## Usage

1. Click the **text cursor icon** in the menu bar.
2. Click **+** to add a snippet:
   - **Trigger:** what you type, for example `;addr`
   - **Expands to:** the full text. Multiple lines are fine.
3. Click **Save**, then type the trigger anywhere.

Click a snippet in the list to edit or delete it. Use the switch at the top to pause Snip. The menu bar icon changes to ⏸ while it's paused.

Snip comes with three example snippets (`;sig`, `;thx`, `;shrug`) that you can edit or delete.

## Permissions

Snip needs the **Accessibility** permission. macOS requires it for any app that reads keystrokes and types on your behalf.

1. When Snip first opens, macOS shows a prompt. Click **Open System Settings**.
2. In **Privacy & Security → Accessibility**, turn on **Snip**.
3. That's it. Snip notices the permission within a couple of seconds, no restart needed.

If you missed the prompt, the Snip panel shows a button that opens the right settings page.

> If you update or rebuild Snip, macOS may treat it as a new app. If expansions stop working, remove Snip from the Accessibility list and add it again.

## Tips

- **Start triggers with a symbol** such as `;`. Triggers fire as soon as they're typed, so a plain word like `addr` would also fire inside "address".
- **Longer triggers win.** If you have both `;mail` and `;mailw`, typing `;mailw` uses the longer one.
- **Ideas:** your email (`;mail`), phone number (`;num`), address (`;addr`), email sign-offs (`;sig`), and common replies (`;thx`, `;omw`).

## Limitations

- **Password fields** are hidden from all apps by macOS, so triggers don't expand there.
- **Keyboard layouts:** pasting sends ⌘V using the key position of V on QWERTY and QWERTZ layouts. Layouts that move the V key, such as Dvorak, may not work yet.
- **Apps that block pasting** won't receive the snippet.
- **No placeholders** such as dates or cursor positions, yet.
- Requires **macOS 14 Sonoma** or later.

## Build from source

You need the Xcode Command Line Tools (`xcode-select --install`). Xcode itself isn't required.

```bash
git clone https://github.com/yossev/snip.git
cd snip
./build.sh
```

This produces a universal `Snip.app` in the same folder.

### Project layout

```
.
├── main.swift   # the entire app: expansion engine + SwiftUI panel
├── build.sh     # compiles, bundles, and ad-hoc signs Snip.app
├── README.md
└── LICENSE
```

## How it works

1. A [Quartz event tap](https://developer.apple.com/documentation/coregraphics/cgevent/1454426-tapcreate) watches key presses and keeps the **last 64 typed characters** in memory. Clicking, pressing Return, Tab, Esc, an arrow key, or a ⌘ or ⌃ shortcut clears that buffer.
2. When the buffer ends with one of your triggers, Snip sends one backspace per trigger character.
3. It saves your current clipboard, puts the snippet on it, presses ⌘V, and restores your clipboard half a second later. The temporary clipboard entry is marked as [transient](http://nspasteboard.org) so clipboard managers ignore it.
4. Keys that Snip sends itself are tagged so it never reacts to its own typing.

Snippets are stored in the app's preferences (`UserDefaults`).

## Privacy

- Snip never writes down, logs, or sends what you type. Only the last 64 characters are kept, in memory, to check for triggers.
- It makes no network connections.
- Your snippets stay on your Mac.

The whole app is one file, so you can read [`main.swift`](main.swift) to confirm.

## Contributing

Issues and pull requests are welcome. Some ideas:

- Placeholders such as `{date}` and `{clipboard}`
- Import and export of snippets
- A ⌘V fallback for non-QWERTY layouts

Please keep the app small and dependency-free. Before opening a pull request, run `./build.sh` and check that expansion still works in a couple of apps.

## License

[MIT](LICENSE) © 2026 yossev

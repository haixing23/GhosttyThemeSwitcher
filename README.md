# Ghostty Theme Switcher

> A tiny native macOS app for one-click switching between [Catppuccin](https://catppuccin.com/) themes in [Ghostty](https://ghostty.org/).

[简体中文](README.zh-CN.md) · English

![Catppuccin](https://img.shields.io/badge/theme-Catppuccin-f5c2e7?style=flat-square)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?style=flat-square)
![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

## Screenshots

![Main window](assets/screenshot-main.png)

## Features

- Searchable previews for 512 bundled Ghostty-compatible themes, generated from the Ghostty theme format.
- Apply a single theme, or pair a light theme and a dark theme using Ghostty's native `theme = light:...,dark:...` syntax.
- One click rewrites your `config.ghostty` and reloads Ghostty automatically (via AppleScript).
- Bundled themes are installed on demand into Ghostty's application support directory before they are referenced.
- A safety backup (`config.ghostty.bak`) is written before every change.
- Bilingual UI (English / 简体中文): follows your macOS system language by default, switchable in-app from the 🌐 menu.
- Optional CLI mode for scripts and shortcuts.

## Requirements

- macOS 13 (Ventura) or newer
- Apple Silicon Mac
- [Ghostty](https://ghostty.org/) installed in `/Applications`

## Install

### Option 1 — Download a release

1. Grab the latest Apple Silicon release from the [Releases](../../releases) page.
2. Download either the `.dmg` or `.zip` artifact. You do **not** need Xcode, Swift, or any other developer tools.
3. Move **Ghostty Theme Switcher.app** into `/Applications`.
   - If you downloaded the `.dmg`, drag the app onto the `Applications` shortcut in the mounted window.
   - If you downloaded the `.zip`, unzip it first and then drag the app into `/Applications`.
3. **First launch:** because this app isn't signed by an Apple-paid Developer ID, macOS will block it the first time. Don't double-click it — instead:
   - Open `/Applications` in Finder
   - **Right-click** (or hold `Control` and click) on **Ghostty Theme Switcher**
   - Choose **Open** from the menu
   - In the dialog, click **Open** again
   - It now launches normally on every future double-click.

> **If macOS says the app "is damaged and can't be opened":** that's the quarantine attribute attached to anything downloaded via a browser. Open Terminal and run:
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Ghostty Theme Switcher.app"
> ```
> Then try opening it again.

> **Architecture:** current release builds are for **Apple Silicon** (`arm64`) Macs running macOS 13 or newer.

### Option 2 — Build from source

```sh
git clone https://github.com/haixing23/GhosttyThemeSwitcher.git
cd GhosttyThemeSwitcher
zsh tools/build_app.sh
open dist/Ghostty\ Theme\ Switcher.app
```

The bundled app appears in `dist/`.

To produce the release-ready `.app`, `.zip`, and `.dmg` artifacts in one step:

```sh
zsh tools/build_release.sh
```

That script runs tests first, then emits versioned artifacts such as:

```text
dist/GhosttyThemeSwitcher-v1.0.1-macos-arm64.zip
dist/GhosttyThemeSwitcher-v1.0.1-macos-arm64.dmg
```

## Usage

1. Launch the app.
2. Use search to filter themes.
3. In **Single** mode, click any theme card to apply it.
4. In **Follow System** mode, choose one light theme and one dark theme, then click **Apply Pair**. Ghostty will follow macOS appearance using its native light/dark theme syntax.

### Permissions

The first time the app reloads Ghostty, macOS will ask for **Automation** permission. If you accidentally deny it, re-enable it under:

> System Settings → Privacy & Security → Automation → Ghostty Theme Switcher → Ghostty

If you install from a downloaded release, give macOS permission after the first successful right-click launch. The app can still switch themes without this permission, but automatic Ghostty reloads will not work until you allow Automation.

### CLI mode

The same binary doubles as a CLI, useful for shell scripts, Raycast, or Shortcuts:

```sh
"/Applications/Ghostty Theme Switcher.app/Contents/MacOS/Ghostty Theme Switcher" --apply mocha
"/Applications/Ghostty Theme Switcher.app/Contents/MacOS/Ghostty Theme Switcher" --apply-system catppuccin-latte catppuccin-mocha
"/Applications/Ghostty Theme Switcher.app/Contents/MacOS/Ghostty Theme Switcher" --list
```

`--list` prints tab-separated `id`, title, source, and appearance values.

## How it works

The app reads `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`, replaces (or appends) the `theme = …` line, then asks the running Ghostty to reload via AppleScript. The previous config is always saved as `config.ghostty.bak` next to it. Bundled themes are copied into `~/Library/Application Support/com.mitchellh.ghostty/themes/ghostty-theme-switcher/` the first time they are applied.

## Project layout

```
GhosttyThemeSwitcher/
├── Sources/
│   └── GhosttyThemeSwitcher/         # SwiftUI app + CLI entry point
│       └── Resources/
│           ├── bundled-themes.json   # Generated theme metadata
│           ├── themes.json           # Compatibility copy of generated metadata
│           └── BundledThemes/        # Generated Ghostty theme files
├── Tests/
│   └── GhosttyThemeSwitcherTests/
├── tools/
│   ├── build_app.sh                  # Builds the .app bundle into dist/
│   ├── generate_theme_catalog.py     # Regenerates bundled Ghostty themes
│   ├── build_icon.sh
│   ├── Info.plist
│   ├── AppIcon.icns
│   ├── AppIcon.png
│   └── AppIcon.iconset/
├── assets/
│   └── screenshot-main.png           # Screenshot used in the README
├── Package.swift
├── README.md
├── README.zh-CN.md
├── LICENSE
└── .gitignore
```

## Contributing

Issues and PRs are welcome. To run the tests:

```sh
swift test
```

## Manual release flow

1. Run `zsh tools/build_release.sh`.
2. Sanity-check the artifacts in `dist/`.
3. Open the built app locally from `dist/` or after moving it into `/Applications`.
4. Upload the generated `.zip` and `.dmg` files to GitHub Releases.
5. In the release notes, call out:
   - Apple Silicon only
   - macOS 13+
   - first launch requires right-click `Open`
   - quarantine fix command if macOS says the app is damaged

## Acknowledgments

- [**Ghostty**](https://ghostty.org/) by Mitchell Hashimoto — the terminal that makes this app worth writing.
- [**Catppuccin**](https://catppuccin.com/) — the soothing pastel theme this app is built around.

Huge thanks to both communities. ❤️

## License

Released under the [MIT License](LICENSE).

Catppuccin is © the Catppuccin community and used here only by name; no Catppuccin assets are bundled.

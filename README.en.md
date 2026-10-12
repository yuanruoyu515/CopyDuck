<p align="center"><img src="docs/assets/duck.png" alt="CopyDuck" width="128"></p>

# CopyDuck · CopyDuck

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md)

**Copy it. Let the duck type.**

A simple macOS menu bar utility. Use a customizable shortcut to insert the latest clipboard text through the system input method.

[Three-language introduction](https://yuanruoyu515.github.io/CopyDuck/en/index.html) · [All releases](https://github.com/yuanruoyu515/CopyDuck/releases)

## Downloads

Apple Silicon · macOS 14 or later · Tested on macOS 27.0.1

| Version | Download | Notes |
| --- | --- | --- |
| 1.1 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.dmg) · [App ZIP](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.app.zip) | [Release notes](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.1) |
| 1.0 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.dmg) · [App ZIP](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.app.zip) | [Release notes](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.0) |

## Features

- **Your shortcut**：Start with ⌃⌥V, or choose your own in Settings.
- **A home in the menu bar**：No Dock icon. Closing Settings keeps the duck running.
- **Optional launch at login**：Enable it when you want CopyDuck ready after login.
- **Text stays on your Mac**：Reads the clipboard only when triggered. No history, no network connection.

## Install and use

1. Download the DMG and drag “复制鸭” into Applications.
2. Open CopyDuck and click "Install input component" on first use.
3. Once "Input component ready" appears, copy text, focus a field and press your shortcut.

Version 1.1 starts an installed component automatically. Opening a newer build also updates the component while preserving your shortcut.

Default shortcut: **⌃⌥V** (Control + Option + V).

## How it works

CopyDuck appears under Simplified Chinese input sources. When you press the shortcut, it reads the clipboard, temporarily selects its input source, commits the text, then restores your previous input method.

`NSPasteboard → TISSelectInputSource → IMKTextInput.insertText → restore previous input source`

## Compatibility and signing

Plain text, including Chinese, English, line breaks and emoji. Images, files and rich text are not supported. The target field must support system input methods; some secure fields or custom controls may restrict input.

Add “复制鸭” under System Settings → Keyboard → Text Input → Edit → ＋ → Simplified Chinese, then reopen the app. Some first-time installations require logging out and back in.

The downloads are locally signed, without Developer ID signing or Apple notarization. Another Mac may require confirmation in Privacy & Security before opening the app.

Choose “退出复制鸭” (Quit CopyDuck) in its menu. Before uninstalling, disable launch at login, remove its keyboard input source, then remove the app from Applications and ~/Library/Input Methods/复制鸭.app.

## Version history

1.1 fixes the repeated-install startup issue and centers the duck icons in the menu bar and input source menu. 1.0 preserves the original feature release.

Git history preserves the v1.0 and v1.1 tags. Maintain future changes on main. See the release workflow in [the development guide](DEVELOPMENT.md).

## Build from source

Install Apple Command Line Tools and Python 3, then run from the project directory:

```sh
zsh build.sh
```

Produces build/复制鸭.app. Release builds exclude the test trigger. The app uses system frameworks and has no third-party runtime dependencies.

Check icon alignment at standard and Retina resolutions:

```sh
zsh scripts/test_icons.sh
```

Generate an App ZIP and a drag-to-install DMG:

```sh
zsh scripts/package.sh
```

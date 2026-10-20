<p align="center"><img src="docs/assets/duck.png" alt="CopyDuck" width="128"></p>

# CopyDuck · CopyDuck

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md)

> [!WARNING]
> **Compatibility and resource usage warning**
> Currently verified only on macOS 27.0.1. Compatibility with macOS versions earlier than 27 is not guaranteed. A user reported extremely high memory and CPU usage on macOS 26 with a version released before the startup fix; the newer version has not yet been verified on that system. If this occurs, quit CopyDuck; if it is unresponsive, end its process in Activity Monitor.

**Copy it. Let the duck type.**

💢 An input field blocks pasting or distinguishes pasted text from regular input, leaving you to type everything again?

🐤 CopyDuck is a lightweight macOS menu bar utility. Press a shortcut to insert plain text from your clipboard into the active input field through the system input method. It helps with some websites and apps that disable pasting or intercept paste shortcuts while still supporting system input methods, saving you from retyping long passages. It supports Chinese, English, line breaks and emoji. All text processing happens locally on your Mac, with no uploads or clipboard history.

## 💦 The inspiration

The author was struggling to finish assignments in AP CSA when Albert was configured to block pasting. The workaround was to keep changing the input method’s text shortcuts to get the text into the field, bit by bit… That frustration led to CopyDuck.

[Three-language introduction](https://yuanruoyu515.github.io/CopyDuck/en/index.html) · [All releases](https://github.com/yuanruoyu515/CopyDuck/releases)

## Downloads

Apple Silicon · Minimum build target: macOS 14 · Verified only on macOS 27.0.1

| Version | Download | Notes |
| --- | --- | --- |
| 1.2.2 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2.2/CopyDuck-1.2.2-arm64.dmg) · [App ZIP](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2.2/CopyDuck-1.2.2-arm64.app.zip) | [Release notes](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.2.2) |
| 1.2.1 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2.1/CopyDuck-1.2.1-arm64.dmg) · [App ZIP](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2.1/CopyDuck-1.2.1-arm64.app.zip) | [Release notes](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.2.1) |
| 1.2 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2/CopyDuck-1.2-arm64.dmg) · [App ZIP](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2/CopyDuck-1.2-arm64.app.zip) | [Release notes](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.2) |
| 1.1 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.dmg) · [App ZIP](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.app.zip) | [Release notes](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.1) |
| 1.0 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.dmg) · [App ZIP](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.app.zip) | [Release notes](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.0) |

## Features

- **Your shortcut**：Start with ⌃⌥V, or choose your own in Settings.
- **A home in the menu bar**：No Dock icon. Closing Settings keeps the duck running.
- **Optional launch at login**：Enable it when you want CopyDuck ready after login.
- **Text stays on your Mac**：Reads the clipboard only when triggered. No history, no network connection.
- **Simulated typing**：Switch between Normal and Simulated Typing in Settings or the menu bar. Medium, Fast and Very Fast average about 5, 10 and 20 characters per second, with pauses at punctuation and line breaks. Mode and speed are remembered; speed changes apply to the next request. Press the shortcut again, type manually or change input focus to stop. Text already entered is kept.
- **Input reliability and resource cleanup**：Improve first-trigger behavior in Word and prevent unintended typing cancellation. Release the Settings view on close; clear text references, callbacks and scheduled tasks when input finishes or is cancelled.

## A little duck, in real use.

The Settings and menu bar screenshots were supplied by the maintainer while testing 1.2-beta.1 and show the new 1.2 features. The interface is in Simplified Chinese; ⌥D is a custom shortcut, while the default is ⌃⌥V.

### Settings window

<img src="docs/assets/settings.png" alt="Settings window" width="560">

Switch input modes and choose Medium, Fast or Very Fast in Settings, alongside shortcut and launch-at-login options.

### System input sources

<img src="docs/assets/input-sources.png" alt="System input sources" width="560">

CopyDuck appears in the list of installed system input sources.

### Menu bar menu

<img src="docs/assets/menu-bar.png" alt="Menu bar menu" width="360">

Open the duck menu to switch Normal / Simulated Typing and choose one of three speeds in the submenu.

## Install and use

1. Download the DMG and drag “复制鸭” into Applications.
2. Open CopyDuck and click "Install input component" on first use.
3. Once "Input component ready" appears, copy text, focus a field and press your shortcut.

Opening a newer build automatically updates and starts the input component, preserving your shortcut and launch-at-login setting.

Default shortcut: **⌃⌥V** (Control + Option + V).

## How it works

CopyDuck appears under Simplified Chinese input sources. When you press the shortcut, it reads the latest clipboard text, temporarily selects its input source, inserts the whole text at once or types it character by character, then restores your previous input method. Copying something else while typing does not change the current request.

`NSPasteboard → TISSelectInputSource → IMKTextInput.insertText → restore previous input source`

## Compatibility and signing

Plain text, including Chinese, English, line breaks and emoji. Images, files and rich text are not supported. The target field must support system input methods; some secure fields or custom controls may restrict input.

Add “复制鸭” under System Settings → Keyboard → Text Input → Edit → ＋ → Simplified Chinese, then reopen the app. Some first-time installations require logging out and back in.

The downloads are locally signed, without Developer ID signing or Apple notarization. Another Mac may require confirmation in Privacy & Security before opening the app.

Choose “退出复制鸭” (Quit CopyDuck) in its menu. Before uninstalling, disable launch at login, remove its keyboard input source, then remove the app from Applications and ~/Library/Input Methods/复制鸭.app.

## Version history

1.2.2 fixes startup process failures and repeated launches that cause excessive resource usage, and fixes Settings failing to open. 1.2.1 improves first-trigger behavior in Word, prevents unintended input cancellation, and strengthens resource cleanup when cancelling input or closing Settings. 1.2 adds Normal / Simulated Typing and three speeds; 1.1 fixes component startup and centers the icons; 1.0 preserves the original feature release.

Git history preserves stable and beta version tags. Maintain future changes on main. See the release workflow in [the development guide](DEVELOPMENT.md).

## Build from source

Install Apple Command Line Tools and Python 3, then run from the project directory:

```sh
zsh build.sh
```

Produces build/复制鸭.app. Release builds exclude the test trigger. The app uses system frameworks and has no third-party runtime dependencies.

Test simulated typing, speed and cancellation, and check icon alignment at standard and Retina resolutions:

```sh
zsh scripts/test_typing.sh
zsh scripts/test_icons.sh
```

Generate an App ZIP and a drag-to-install DMG:

```sh
zsh scripts/package.sh
```

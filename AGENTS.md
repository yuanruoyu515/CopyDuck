# CopyDuck project

This is the primary Git checkout for 复制鸭 / 複製鴨 / CopyDuck.

- Maintain Swift source in `Sources/` and metadata in `Resources/`.
- Keep the input component ID and shared preferences domain `com.copyduck.inputmethod.CopyDuck`; the launcher uses `com.copyduck.app`. Never give both bundles the same ID. Preserve existing shortcuts and login settings.
- Text insertion must use the InputMethodKit client, not simulated paste or direct accessibility writes.
- Remain a menu bar app without a Dock icon. Closing Settings must keep the background component running.
- Distinguish an installed component from a running component; reopen the installed component automatically.
- Increment `CFBundleVersion` for updates to the installed input component.
- Release builds must exclude DEBUG test triggers.
- Current builds are Apple Silicon only, target macOS 14+, and were tested on macOS 27.0.1. Do not claim Intel support, notarization, or testing on other systems without verification.
- Keep Simplified Chinese, Traditional Chinese and English documentation consistent. Edit `website/content.json` and `website/style.css`, then run `python3 scripts/build_site.py`.
- Preserve version tags and release assets. Do not rewrite released tags.
- Keep generated app bundles, installers, caches and local credentials out of Git. Upload installers to GitHub Releases.
- Use `zsh build.sh` and the existing icon alignment checks for relevant native changes. Tests requiring the installed component must run on the user's Mac with a real desktop session.

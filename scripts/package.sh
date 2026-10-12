#!/bin/zsh
set -eu
cd "${0:A:h}/.."
zsh build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ROOT="$PWD"
OUT="$ROOT/.release/$VERSION"
STAGE="$OUT/stage"
MOUNT="$OUT/volume"
mkdir -p "$STAGE/.background" "$MOUNT"
if [[ ! -x .venv/bin/python ]]; then python3 -m venv .venv; fi
.venv/bin/python -m pip install -r scripts/requirements-dmg.txt
ditto build/复制鸭.app "$STAGE/复制鸭.app"
ln -sfn /Applications "$STAGE/应用程序"
swiftc -module-cache-path build/module-cache -swift-version 5 \
  Sources/DuckArtwork.swift Sources/DMGArtwork.swift -o build/DMGArtwork
build/DMGArtwork "$STAGE/.background/install.png"
python3 - "$ROOT" "$OUT" "$VERSION" <<'PY'
from pathlib import Path
import sys, zipfile
root, output, version = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
app = root / 'build/复制鸭.app'
with zipfile.ZipFile(output / f'CopyDuck-{version}-arm64.app.zip', 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    archive.write(app, app.name + '/')
    for path in sorted(app.rglob('*')):
        archive.write(path, str(Path(app.name) / path.relative_to(app)))
PY
hdiutil create -volname 复制鸭 -srcfolder "$STAGE" -ov -fs HFS+ -format UDRW "$OUT/install-rw.dmg"
hdiutil attach -nobrowse -mountpoint "$MOUNT" "$OUT/install-rw.dmg"
cleanup() { hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
.venv/bin/python scripts/layout_dmg.py "$MOUNT"
codesign --verify --deep --strict "$MOUNT/复制鸭.app"
hdiutil detach "$MOUNT"
trap - EXIT
hdiutil convert "$OUT/install-rw.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$OUT/CopyDuck-$VERSION-arm64.dmg"
hdiutil verify "$OUT/CopyDuck-$VERSION-arm64.dmg"
python3 - "$OUT" "$VERSION" <<'PY'
from pathlib import Path
import sys, hashlib
output, version = Path(sys.argv[1]), sys.argv[2]
paths = [output / f'CopyDuck-{version}-arm64.dmg', output / f'CopyDuck-{version}-arm64.app.zip']
(output / 'SHA256SUMS.txt').write_text(''.join(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n' for path in paths))
PY
print "Release files: $OUT"

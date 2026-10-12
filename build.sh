#!/bin/zsh
set -eu
cd "${0:A:h}"
APP="$PWD/build/复制鸭.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/icons build/CopyDuck.iconset build/module-cache
SDK=$(xcrun --show-sdk-path)
FLAGS=()
if [[ "${1:-}" == "--debug" ]]; then FLAGS=(-D DEBUG); fi
swiftc "${FLAGS[@]}" -module-cache-path "$PWD/build/module-cache" -swift-version 5 -O -target arm64-apple-macos14.0 -sdk "$SDK" \
    Sources/main.swift Sources/DuckArtwork.swift Sources/InputSources.swift Sources/HotKey.swift Sources/Insertion.swift Sources/Settings.swift \
    -framework AppKit -framework Carbon -framework InputMethodKit -framework SwiftUI -framework ServiceManagement \
    -o "$APP/Contents/MacOS/CopyDuck"
swiftc -module-cache-path "$PWD/build/module-cache" -swift-version 5 -O Sources/DuckArtwork.swift Sources/IconMaker.swift -o build/IconMaker
build/IconMaker "$PWD/build/icons"
for SIZE in 16 32 128 256 512; do
    cp "build/icons/duck-$SIZE.png" "build/CopyDuck.iconset/icon_${SIZE}x${SIZE}.png"
    DOUBLE=$((SIZE * 2))
    cp "build/icons/duck-$DOUBLE.png" "build/CopyDuck.iconset/icon_${SIZE}x${SIZE}@2x.png"
done
python3 make_icns.py build/icons "$APP/Contents/Resources/CopyDuck.icns"
cp build/icons/InputIcon-v2.tiff "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/zh-Hans.lproj Resources/en.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"

#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p build/module-cache
swiftc -module-cache-path build/module-cache -swift-version 5 \
  Sources/Typing.swift Tests/TypingSequence.swift -o build/TypingTests
build/TypingTests
swiftc -module-cache-path build/module-cache -swift-version 5 \
  Sources/InputSources.swift Sources/HotKey.swift Tests/ShortcutEvents.swift \
  -framework AppKit -framework Carbon -o build/ShortcutEventTests
build/ShortcutEventTests

#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p build/module-cache
swiftc -module-cache-path build/module-cache -swift-version 5 \
  Sources/Typing.swift Tests/TypingSequence.swift -o build/TypingTests
build/TypingTests

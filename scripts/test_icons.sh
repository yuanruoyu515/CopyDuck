#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p build/module-cache
swiftc -module-cache-path build/module-cache -swift-version 5 \
  Sources/DuckArtwork.swift Tests/IconAlignment.swift -o build/IconAlignment
build/IconAlignment

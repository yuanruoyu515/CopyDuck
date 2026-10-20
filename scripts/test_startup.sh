#!/bin/zsh
set -eu
cd "${0:A:h}/.."
python3 - <<'PY'
import plistlib
from pathlib import Path
launcher = plistlib.loads(Path('Resources/Info.plist').read_bytes())
component = plistlib.loads(Path('Resources/InputMethodInfo.plist').read_bytes())
assert launcher['CFBundleIdentifier'] == 'com.copyduck.app'
assert component['CFBundleIdentifier'] == 'com.copyduck.inputmethod.CopyDuck'
assert 'InputMethodConnectionName' not in launcher and 'ComponentInputModeDict' not in launcher
assert component['InputMethodConnectionName'] == component['CFBundleIdentifier'] + '_Connection'
for key in ['CFBundleVersion', 'CFBundleShortVersionString']:
    assert launcher[key] == component[key], key
print('Bundle identities, input-method metadata separation and component upgrade versions passed')
PY
mkdir -p build/module-cache
swiftc -parse-as-library -module-cache-path build/module-cache -swift-version 5 \
  Sources/InstanceLock.swift Tests/InstanceLockTests.swift -o build/InstanceLockTests
build/InstanceLockTests
swiftc -parse-as-library -module-cache-path build/module-cache -swift-version 5 \
  Tests/StartupIntegration.swift -o build/StartupIntegration

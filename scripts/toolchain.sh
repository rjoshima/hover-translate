#!/bin/bash
# Sourced by build/check. A stale CLT module map can duplicate SwiftBridging.
# Overlay only this compiler invocation; never modify the installed toolchain.
SWIFT_FLAGS=()
TOOLCHAIN_INCLUDE="$(xcode-select -p)/usr/include/swift"
if [ -f "$TOOLCHAIN_INCLUDE/module.modulemap" ] && [ -f "$TOOLCHAIN_INCLUDE/bridging.modulemap" ] \
  && grep -q 'module SwiftBridging' "$TOOLCHAIN_INCLUDE/module.modulemap" \
  && grep -q 'module SwiftBridging' "$TOOLCHAIN_INCLUDE/bridging.modulemap"; then
  mkdir -p .build/toolchain
  : > .build/toolchain/empty.modulemap
  python3 - "$TOOLCHAIN_INCLUDE/module.modulemap" <<'PY'
import json, os, sys
with open('.build/toolchain/overlay.json', 'w') as f:
    json.dump({'version': 0, 'roots': [{'type': 'file', 'name': sys.argv[1],
        'external-contents': os.path.abspath('.build/toolchain/empty.modulemap')}]}, f)
PY
  SWIFT_FLAGS=(-vfsoverlay "$PWD/.build/toolchain/overlay.json")
fi

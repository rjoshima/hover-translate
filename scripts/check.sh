#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p .build/check
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -whole-module-optimization \
  -emit-module -emit-object -module-name HoverCore \
  -emit-module-path .build/check/HoverCore.swiftmodule \
  Sources/HoverCore/*.swift -o .build/check/HoverCore.o
xcrun swiftc "${SWIFT_FLAGS[@]}" -I .build/check scripts/check.swift .build/check/HoverCore.o -o .build/check/check
.build/check/check

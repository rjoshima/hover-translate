#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p .build/check
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -whole-module-optimization \
  -emit-module -emit-object -module-name TranslationCore \
  -emit-module-path .build/check/TranslationCore.swiftmodule \
  Sources/TranslationCore/*.swift -o .build/check/TranslationCore.o
xcrun swiftc "${SWIFT_FLAGS[@]}" -I .build/check scripts/check.swift .build/check/TranslationCore.o -o .build/check/check
.build/check/check

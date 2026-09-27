#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p .build/manual
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -whole-module-optimization -O \
  -emit-module -emit-object -module-name HoverCore \
  -emit-module-path .build/manual/HoverCore.swiftmodule \
  Sources/HoverCore/*.swift -o .build/manual/HoverCore.o
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -O -I .build/manual \
  Sources/HoverTranslate/*.swift .build/manual/HoverCore.o \
  -o .build/manual/HoverTranslate
app="$PWD/dist/Hover Translate.app"
mkdir -p "$app/Contents/MacOS"
cp .build/manual/HoverTranslate "$app/Contents/MacOS/HoverTranslate"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>jp.ryota.HoverTranslate</string>
<key>CFBundleName</key><string>Hover Translate</string>
<key>CFBundleExecutable</key><string>HoverTranslate</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier jp.ryota.HoverTranslate "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"

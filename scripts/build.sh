#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p .build/manual
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -whole-module-optimization -O \
  -emit-module -emit-object -module-name TranslationCore \
  -emit-module-path .build/manual/TranslationCore.swiftmodule \
  Sources/TranslationCore/*.swift -o .build/manual/TranslationCore.o
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library -O -I .build/manual \
  Sources/SelectTranslate/*.swift .build/manual/TranslationCore.o \
  -o .build/manual/SelectTranslate
app="$PWD/dist/Select Translate.app"
mkdir -p "$app/Contents/MacOS"
cp .build/manual/SelectTranslate "$app/Contents/MacOS/SelectTranslate"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>jp.ryota.HoverTranslate</string>
<key>CFBundleName</key><string>Select Translate</string>
<key>CFBundleDisplayName</key><string>Select Translate</string>
<key>CFBundleExecutable</key><string>SelectTranslate</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Keep the original signing/bundle identity to retain existing settings and Keychain namespace.
codesign --force --sign - --options runtime --identifier jp.ryota.HoverTranslate "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"

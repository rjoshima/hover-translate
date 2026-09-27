#!/bin/bash
# Local source installer. No sudo, remote scripts, TCC edits or Keychain migration.
set -euo pipefail
cd "$(dirname "$0")/.."
install_dir="$HOME/Applications"
open_after=true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-open) open_after=false; shift ;;
    --destination)
      [ "$#" -ge 2 ] && [ -n "$2" ] || { echo "--destination needs a directory" >&2; exit 2; }
      install_dir="$2"; shift 2 ;;
    *) echo "Usage: $0 [--no-open] [--destination DIRECTORY]" >&2; exit 2 ;;
  esac
done
[ "$(uname -s)" = Darwin ] || { echo "macOS 26 or later is required." >&2; exit 1; }
mac_version="$(sw_vers -productVersion)"
[ "${mac_version%%.*}" -ge 26 ] || { echo "macOS 26 or later is required." >&2; exit 1; }
xcrun --find swiftc >/dev/null 2>&1 || {
  echo "Install Apple Command Line Tools first: xcode-select --install" >&2; exit 1;
}
mkdir -p "$install_dir"
install_dir="$(cd "$install_dir" && pwd -P)"
validate_targets() {
  for name in 'Select Translate' 'Hover Translate'; do
    existing="$install_dir/$name.app"
    if [ -e "$existing" ] || [ -L "$existing" ]; then
      [ ! -L "$existing" ] && [ -d "$existing" ] || {
        echo "Refusing to replace a symlink or non-app: $existing" >&2; exit 1;
      }
      identifier="$(/usr/libexec/PlistBuddy -c Print:CFBundleIdentifier "$existing/Contents/Info.plist" 2>/dev/null || true)"
      [ "$identifier" = jp.ryota.HoverTranslate ] || {
        echo "Refusing to replace an unrelated app: $existing" >&2; exit 1;
      }
      if ps -axo comm= | awk -v prefix="$existing/Contents/MacOS/" 'index($0, prefix) == 1 { found=1 } END { exit !found }'; then
        echo "Quit $name from its settings, then run the installer again." >&2; exit 1
      fi
    fi
  done
}
validate_targets
./scripts/check.sh
./scripts/build.sh
stage="$(mktemp -d "$install_dir/.select-translate-stage.XXXXXX")"
backup=""
installed=false
finish() {
  result=$?
  trap - EXIT
  if [ "$installed" = false ] && [ -n "$backup" ]; then
    for saved in "$backup"/*.app; do
      [ -e "$saved" ] || continue
      original="$install_dir/$(basename "$saved")"
      if [ ! -e "$original" ] && [ ! -L "$original" ]; then mv "$saved" "$original"; fi
    done
  fi
  if [ "$result" -ne 0 ] && [ -n "$backup" ]; then printf 'Recovery backup: %s\n' "$backup" >&2; fi
  # Only the newly created staging directory is removed; old apps stay in the backup.
  rm -rf "$stage"
  exit "$result"
}
trap finish EXIT
/usr/bin/ditto 'dist/Select Translate.app' "$stage/Select Translate.app"
/usr/bin/codesign --verify --strict "$stage/Select Translate.app"
# Recheck after building in case an existing app was opened while compiling.
validate_targets
for name in 'Select Translate' 'Hover Translate'; do
  existing="$install_dir/$name.app"
  if [ -e "$existing" ]; then
    if [ -z "$backup" ]; then backup="$(mktemp -d "$install_dir/.select-translate-backup.XXXXXX")"; fi
    mv "$existing" "$backup/"
  fi
done
mv "$stage/Select Translate.app" "$install_dir/Select Translate.app"
installed=true
printf 'Installed: %s\n' "$install_dir/Select Translate.app"
if [ -n "$backup" ]; then printf 'Previous app backup: %s\n' "$backup"; fi
printf '%s\n' 'First run: prepare Apple translation, then grant Accessibility access to the installed app.'
if [ "$open_after" = true ]; then open "$install_dir/Select Translate.app"; fi

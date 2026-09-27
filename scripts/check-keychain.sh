#!/bin/bash
# Integration test of the same KeyStore code with a unique synthetic-only service.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p .build/keychain-check
python3 - <<'PY'
from pathlib import Path
import uuid
source = Path('Sources/SelectTranslate/KeyStore.swift').read_text()
source = source.replace('jp.ryota.HoverTranslate.OpenRouter', 'jp.ryota.HoverTranslate.Test.' + uuid.uuid4().hex)
Path('.build/keychain-check/KeyStore.swift').write_text(source)
PY
cat > .build/keychain-check/Check.swift <<'SWIFT'
import Foundation
@main struct KeychainCheck {
    @MainActor static func main() throws {
        guard try KeyStore.read() == nil else { fatalError("Test namespace must be empty") }
        defer { try? KeyStore.delete() }
        try KeyStore.save("synthetic-value-not-a-real-key")
        guard try KeyStore.read() == "synthetic-value-not-a-real-key", KeyStore.isConfigured() else {
            fatalError("Keychain roundtrip failed")
        }
        try KeyStore.save("synthetic-updated-value")
        guard try KeyStore.read() == "synthetic-updated-value" else { fatalError("Keychain update failed") }
        try KeyStore.delete()
        guard try KeyStore.read() == nil, !KeyStore.isConfigured() else { fatalError("Test cleanup failed") }
        print("PASS: isolated Keychain save, read, update, presence, deletion; no real API key accessed")
    }
}
SWIFT
xcrun swiftc "${SWIFT_FLAGS[@]}" -parse-as-library .build/keychain-check/KeyStore.swift \
  .build/keychain-check/Check.swift -o .build/keychain-check/check
codesign --force --sign - .build/keychain-check/check
.build/keychain-check/check

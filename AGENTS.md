# Hover Translate

- Keep this a small native macOS utility with no third-party dependencies.
- Translate only an explicitly selected English passage when the user clicks the menu-bar 「訳」 button. No automatic hover trigger, clipboard monitoring, or screenshot capture.
- Never commit API keys, captured text, translations, build output, or local preferences.
- Read selections only on a user action and only from the chosen foreground app. Never send automatically at launch. No telemetry or disk transcript history.
- Use `scripts/check.sh` and `scripts/build.sh`. Verify actual runtime behavior separately; a build is not proof that Codex exposes its text.
- Do not weaken provider price limits, request bounds, or Keychain storage to bypass an error.

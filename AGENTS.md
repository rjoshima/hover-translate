# Hover Translate

- Keep this a small native macOS utility with no third-party dependencies.
- Preserve hover → nearby Japanese tooltip. Do not replace it with clipboard or screenshot workflows.
- Never commit API keys, captured text, translations, build output, or local preferences.
- Keep capture opt-in, scoped to chosen apps, and disabled at launch. No telemetry or disk transcript history.
- Use `scripts/check.sh` and `scripts/build.sh`. Verify actual runtime behavior separately; a build is not proof that Codex exposes its text.
- Do not weaken provider price limits, request bounds, or Keychain storage to bypass an error.

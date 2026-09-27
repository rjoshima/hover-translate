# Security

This is an experimental local macOS utility, not a notarized release.

Security boundaries:

- Only explicit shortcut/menu actions may read selected text. Apple translation stays on device; sending the selected text to OpenRouter requires a separate explicit AI action. Never fall back to AI automatically. Never add automatic capture, clipboard monitoring, or whole-document fallbacks.
- Keep API keys in the local macOS Keychain; never put them in source, preferences, fixtures, screenshots, issues, or logs.
- Keep the fixed HTTPS endpoint, redirect refusal, input byte/character limits, attempt budget and provider privacy/price settings.
- Target-app Accessibility labels, macOS permission enforcement, Keychain ACLs and provider policies remain external dependencies. A text filter is not a complete DLP system.
- Review and build source before granting Accessibility access. Ad-hoc signing does not authenticate a public distributor or provide notarization.

Do not post secrets, captured private text, exploit details, or raw logs in public issues. Use GitHub's **Security → Report a vulnerability** if that private reporting option is available. If it is unavailable, open an issue requesting a private contact route without technical details or sensitive data; wait for a private route before disclosing the report.

Only the current source is maintained. Do not interpret passing local checks or a past source review as proof of security on every target app or Mac.

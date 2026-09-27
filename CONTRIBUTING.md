# Contributing

Small, focused issues and pull requests are welcome. Explain the user-visible problem and how you verified the change. Do not attach private selected text, API keys, screenshots containing personal data, or raw logs. Report vulnerabilities through the route in [SECURITY.md](SECURITY.md).

The project is a dependency-free Swift macOS utility. Keep Apple on-device translation as the default. AI must remain optional and require a separate explicit action; never add automatic network fallback, clipboard monitoring, or background capture. Keep request limits and local Keychain storage intact.

Run `./scripts/check.sh` and `./scripts/build.sh` on macOS 26+ with Swift 6.2+. For Keychain changes, also run `./scripts/check-keychain.sh`; it uses synthetic values in an isolated test namespace. Do not use a real API key in tests.

For changes to selection, shortcuts or panels, verify the actual flow in a supported target app with public test text, including fullscreen and no-selection behavior. State untested applications and OS versions. Builds and static checks alone do not prove target-app compatibility.

Changes are contributed under the repository's MIT license. Build outputs, local settings and credentials must remain outside Git.

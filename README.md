# Select Translate

[MIT License](LICENSE) · [Security policy](SECURITY.md)

Select English text in a supported Mac app and press **Option+T** to show a Japanese translation using Apple's on-device Translation framework. Works in fullscreen. The interface and translation direction are currently Japanese and English → Japanese.

This is a small native Swift app, not a browser extension or a standalone translation script. Previously called Hover Translate. The current implementation contains no automatic hover translation or clipboard monitoring; older implementations remain only in Git history. The legacy bundle/signing identifier and Keychain namespace `jp.ryota.HoverTranslate` remain for compatibility with saved settings and keys.

**Source preview:** macOS 26+, Swift 6.2+ Command Line Tools. No third-party dependencies. Builds use ad-hoc signing and are not notarized. There is no prebuilt signed installer.

## Install on a new Mac

Install Apple's Command Line Tools with `xcode-select --install` if needed, and finish the system installer first. Then run:

```sh
mkdir -p ~/Projects
cd ~/Projects
git clone https://github.com/rjoshima/select-translate.git
cd select-translate
./scripts/install.sh
```

The installer runs the local checks, builds and verifies the app, installs it into `~/Applications`, and opens settings. It does not need administrator access, download third-party code, set up auto-start, or change macOS security settings. Quit the app before updating. Existing Select Translate or Hover Translate bundles with the expected identifier are moved to a printed backup directory; unrelated apps are never replaced.

The first two setup steps below must be completed on each Mac. They cannot be silently carried over from another Mac. After setup, open Select Translate when you want to use it; it stays running after closing its settings window. To start it at login, optionally add it yourself under System Settings → General → Login Items.

For a manual build, run `./scripts/check.sh` and `./scripts/build.sh`, then copy `dist/Select Translate.app` into Applications. The installer also accepts `--no-open` and `--destination DIRECTORY`.

1. Click **Apple翻訳を準備** to prepare English and Japanese. macOS downloads language data if needed.
2. Grant Accessibility access to the installed app through **Macのアクセス設定を開く**.
3. Select an English passage in Claude or Codex, then press **Option+T**. Close the result with ×.

Targets can be changed in settings. The shortcut is registered only while a chosen target is frontmost. It takes precedence over that app's existing Option+T behavior; Command+T is untouched. Other apps' selection support varies. If the shortcut cannot be registered, settings show an error.

To reopen settings, open the app again or right-click its menu bar item **訳**. Fullscreen use does not require the menu bar. This app does not insert a Translate item into another app's context menu.

On a replacement Mac, run the installation command, then repeat language preparation, Accessibility permission, and target selection. Apple translation needs no API key. Ad-hoc builds may require renewed Accessibility or Keychain permission after rebuilding. Do not disable macOS security features to install it.

## Optional AI translation

Apple is the default and failures never trigger a network fallback. **AIで訳し直す（外部送信）** explicitly sends the selected source text to OpenRouter and its model provider using `openai/gpt-4.1-nano`. Connection checks and comparisons send fixed public samples. Apple and AI share selection, shortcuts and display code, while their translation backends remain separate.

Save an optional OpenRouter key in the app's secure input. It stays in this Mac's local Keychain, **without iCloud synchronization**. Enter it separately on each Mac that needs AI. Never copy keys into Git, issues, configuration files or shared folders.

AI requests use a fixed HTTPS endpoint, reject redirects, request `data_collection: deny` and `zdr: true`, and cap provider prices at $0.10 input / $0.40 output per million tokens. Provider compliance and account policies remain external dependencies. There is a local limit of 500 attempts per day, including failed and cancelled attempts, with no automatic retries. These controls do not cap spending across the entire OpenRouter account; use a dedicated key with a spending limit.

## Privacy and limitations

- Text is read only following an explicit translation action, from a configured foreground app's selected text. No clipboard monitoring, screenshot capture, whole-document fallback, analytics, or saved translation history.
- Input is bounded to 1,800 graphemes and 7,200 UTF-8 bytes. Recognizable credentials are rejected, but filtering cannot identify all private or confidential content.
- Apple and AI each keep up to 64 translations in memory until cache clearing or quit. Close visible results before screen sharing.
- Accessibility permission is powerful. Review the source before granting it. This is a Hardened Runtime build, **not App Sandbox**, and ad-hoc signing does not identify a trusted distributor.
- Apple language data is managed by macOS and is not included in this repository. No local general-purpose LLM is bundled.

## Development and verification

```sh
./scripts/check.sh
./scripts/check-keychain.sh # isolated UUID namespace and synthetic values only
./scripts/build.sh
```

The build script invokes the Apple compiler directly. A scoped VFS overlay handles a duplicate module-map issue on affected Command Line Tools installations, without modifying system files. Use the resulting app bundle; `Package.swift` alone does not install a working application.

Tests cover input bounds, cache behavior, fixed endpoints, credential filtering, provider privacy/price settings, redirects and failure responses. On 2026-09-27, selection → Option+T → Apple translation and explicit AI retranslation were exercised in the Claude desktop app in fullscreen. **Codex's actual UI and a second Mac remain unverified.** Warm Apple translation of three fixed samples took 0.09–0.30 seconds on an M4 Mac; this is not a general performance or quality guarantee.

The current release has been built and installed on the development Mac; a clean source-only build also passed. A completely fresh Mac setup has not been tested.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). MIT licensed. Independent of Apple, OpenAI, Anthropic and OpenRouter. No Apple model or operating-system code is redistributed.

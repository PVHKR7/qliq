# Qliq

A menu-bar dictation app for macOS. Hold a key, speak, and the text lands at the cursor of whatever app is focused.

Qliq is a locally built derivative of [FreeFlow](https://github.com/zachlatta/freeflow) (MIT). See [NOTICE.md](NOTICE.md) for attribution and the list of changes.

## Status

**P0 — first usable build.** It compiles, launches, and its test suite passes. It has **not** yet been exercised with a real microphone, a real provider key, or against a target application. Treat the current build as a skeleton that needs a permission and provider pass before you rely on it for real work.

Verified so far:

- `make` produces `build/Qliq.app` (arm64, ad-hoc signed, macOS 13 deployment target).
- `make test` passes (`AppContextServiceTests`).
- The app launches, creates `~/Library/Application Support/Qliq/`, and quits cleanly.
- No upstream bundle identifier, URL, or organisation string remains in the binary.

Not verified: audio capture, transcription against a live provider, clipboard restore, global shortcut handling, permission recovery, overlay placement.

## Requirements

- macOS 13 or later.
- Command Line Tools with Swift 6.4 (`xcode-select --install`). Full Xcode is **not** required.

## Build

```sh
make            # build build/Qliq.app
make run        # build and launch
make test       # run the unit tests
make clean
```

### About the SDK pin

The macOS 27 SDK declares SwiftUI's `@State`, `@Binding` and `@Environment` as external macros, and the plugin that expands them ships inside Xcode rather than the Command Line Tools. With CLT alone, every SwiftUI view fails with:

```
error: external macro implementation type 'SwiftUIMacros.StateMacro' could not be found
```

The `Makefile` therefore pins `/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`, the last CLT SDK that still declares those attributes as property wrappers. The app itself still targets macOS 13. If you install Xcode, override the pin:

```sh
make SDK="$(xcrun --show-sdk-path)"
```

## Permissions

| Permission | Needed for | When it is requested |
|---|---|---|
| Microphone | recording | first recording attempt |
| Accessibility | pasting text into other apps, global shortcut | setup step |
| Screen Recording | the optional context feature only | only if you enable context |

## Signing

The default build is **ad-hoc signed** (`CODESIGN_IDENTITY=-`). macOS ties privacy grants to the code signature, so after every rebuild the microphone and Accessibility grants are invalidated and you will be asked again. That is expected, not a bug.

If you have a signing identity, pass it:

```sh
make CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
```

## Configuration

Qliq is a direct client to an OpenAI-compatible provider. Defaults match the upstream app: `https://api.groq.com/openai/v1`, `whisper-large-v3` for transcription, `openai/gpt-oss-20b` for cleanup. Any compatible base URL and model IDs can be entered during setup.

Provider settings and the API key are stored in `~/Library/Application Support/Qliq/.settings` with `0600` permissions. **This is a plaintext file, not the Keychain.** Moving credentials to the Keychain is the first item of P1; see [docs/STATUS.md](docs/STATUS.md).

## What differs from upstream

- New product identity: bundle ID `com.pvhkr.qliq`, own data directory, own log subsystems, own file-name prefixes.
- Removed the GitHub star/contributor panels and every request to `api.github.com`.
- Replaced the self-updater (which polled an upstream release feed and could install over the app) with a no-op that explains updates arrive by rebuilding.
- Removed the unused `NSSpeechRecognitionUsageDescription` and `NSAccessibilityUsageDescription` plist keys — neither is read by the system, and no Apple Speech API is linked.
- Dropped the DMG and notarization targets; this build is for local use.
- Original icon, generated reproducibly by `scripts/make-icon.py`.

## Attribution

Qliq is derived from FreeFlow, Copyright (c) 2026 Zach Latta, MIT licensed. The original licence is retained verbatim in [LICENSE](LICENSE). See [NOTICE.md](NOTICE.md).

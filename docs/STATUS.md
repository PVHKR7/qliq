# Qliq build status

Recorded 16 November 2026 on the machine the app is being built for.

## Environment

| Item | Value |
|---|---|
| macOS | 27.0.1 (build 26A434) |
| CPU | arm64 |
| Swift | 6.4 (swiftlang-6.4.0.34.1) |
| Xcode | not installed |
| Command Line Tools | `/Library/Developer/CommandLineTools` |
| Available CLT SDKs | 26, 26.5, 27.0 |
| Codesigning identities | none (0 valid) |

## Build path

The default SDK (27.0) cannot compile any SwiftUI view with Command Line Tools alone. `@State` is declared as an external macro and the `SwiftUIMacros` plugin ships only inside Xcode:

```
error: external macro implementation type 'SwiftUIMacros.StateMacro' could not be found
       for macro 'State()'; plugin for module 'SwiftUIMacros' not found
```

A ten-line probe app reproduces it, so the failure is the toolchain, not this codebase.

`MacOSX26.5.sdk` still declares those attributes as property wrappers and compiles cleanly. The Makefile pins it and falls back to `xcrun --show-sdk-path` if that SDK is absent.

## Evidence

```
$ make check-sdk
SDK:  /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
Arch: arm64
Sign: -

$ make ARCH=arm64
Built build/Qliq.app          # 14.3s, no errors

$ make test
AppContextServiceTests passed
```

Bundle:

```
CFBundleName              Qliq
CFBundleIdentifier        com.pvhkr.qliq
CFBundleShortVersionString 0.1.0
LSMinimumSystemVersion    13.0
Mach-O                    64-bit executable arm64
size                      9.3M
signature                 adhoc
entitlements              com.apple.security.device.audio-input = true
upstream strings in binary 0  ("freeflow", "zachlatta")
```

Launch smoke test: `open build/Qliq.app` started the process, created its data directory, and quit cleanly on request. No crash, no log write.

Data directory created on first launch:

```
~/Library/Application Support/Qliq/
  .settings                 0600, 34 bytes
  PipelineHistory.sqlite
```

It does not read or write `~/Library/Application Support/FreeFlow/`.

## Known gaps, in priority order

These are inherited from upstream. None are fixed yet.

1. **Credentials are plaintext.** `.settings` holds the provider API key as JSON with `0600` permissions, despite the class being named `KeychainStorage`. Upstream's own behaviour, documented as D01 in the reference spec. Move to the Keychain.
2. **History is on by default and retains sensitive material.** SQLite rows include raw and final transcripts, prompts and context metadata; audio is written to `audio/<UUID>.wav`, and screenshots may be stored. Default to off, or make retention an explicit choice at setup.
3. **No session integrity guard.** A cancelled or superseded session's asynchronous completion can still paste, and focus changes are not checked before insertion. Upstream behaviour; D05 proposes per-session IDs and a focus guard.
4. **Storage failure handling is destructive upstream.** Upstream may recreate the store on corruption. Replace with a visible error and non-destructive recovery (D06).
5. **The Fn default collides with the system.** Holding Fn can race with macOS's own press-Fn-twice Dictation and the emoji picker. Needs either a first-run prompt to disable system Dictation or a different default binding.
6. **Context mode has no explicit off switch in setup.** It is gated on Screen Recording, but the distinction between "not enabled" and "permission missing" is not surfaced (D02).

## Not yet tested

Everything that requires a human at the keyboard: microphone capture, provider round-trip, clipboard preservation and restore, global shortcut latching, cancellation, permission recovery, overlay placement, and insertion into real target applications. The acceptance matrix in the reference investigation is still entirely unrun.

## Next

P1, in the order above, starting with Keychain storage and history defaults. Provider tests need a real OpenAI-compatible key.

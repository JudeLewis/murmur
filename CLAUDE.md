# Murmur: Claude context

## What it is

A Mac menu bar app for dictation: a free replacement for Wispr Flow and for Apple's own dictation, which Jude found missed too much of what they said. Double-tap Fn to start listening, double-tap Fn again to stop, and the text appears wherever the cursor is, in any app. Speech turns into text on the Mac itself, with NVIDIA's Parakeet model (the Bark 3.0 Clean version, which drops "um", false starts and repeated words). Nothing leaves the Mac.

Built for one person: Jude, on an M3 MacBook Air with 16 GB, macOS 26. Not for sale or the App Store.

Separate from Clocked In (~/Developer/clocked-in). Never touch that folder from here.

## Stack

- Swift 6.2 and Swift Package Manager. No Xcode project: everything is plain text files.
- AppKit for the menu bar, the event tap and the floating pill; SwiftUI inside the pill.
- FluidAudio (github.com/FluidInference/FluidAudio) for speech to text, with `traits: []` so only its speech-to-text part is built.
- Swift Testing for unit tests (`import Testing`, `@Test`, `#expect`).
- Signed with Jude's Apple Development certificate, so macOS permissions survive rebuilds.

## Commands

| What | Command |
| --- | --- |
| build | `swift build` |
| unit tests | `swift test` |
| check the speech model end to end | `./scripts/check-speech.sh` (makes speech with `say`, transcribes it, prints OK or NOT OK) |
| try any recording | `.build/debug/Murmur --transcribe file.wav [--exact]` |
| install and run Jude's copy | `./scripts/install.sh` (build, wrap as Murmur.app, sign, copy to /Applications, open) |
| read the app's log | `/usr/bin/log show --last 10m --predicate 'subsystem == "com.judelewis.murmur"' --style compact` |

The pre-commit hook (.githooks/pre-commit) runs `swift build` and `swift test`. A fresh clone needs `git config core.hooksPath .githooks` once.

## Folder map

```
Sources/MurmurCore/        Plain logic, no AppKit or audio; all of it tested
  DoubleTap.swift          When Fn presses and releases make a double tap
  FnWatcher.swift          Raw key events to "double tap" or "Escape"
  DictationFlow.swift      The on/off switch: idle, recording, transcribing
  Tidy.swift               Model text to pasted text; the recent list
  BritishSpelling.swift    American to British spelling, from a fixed word list
  WordList.swift           Jude's own word list (words.txt)
Sources/Murmur/            The app: wires the logic to the Mac
  main.swift               Starts the app; also the --transcribe test mode
  AppDelegate.swift        Menu bar, and each dictation from microphone to paste
  FnKeyMonitor.swift       Event tap that spots Fn and Escape
  Recorder.swift           Microphone into memory
  Transcriber.swift        Loading the Parakeet model and transcribing
  Paster.swift             Clipboard and Command-V, then restores the clipboard
  Pill.swift               The black pill at the bottom of the screen
  Permissions.swift        Microphone, Accessibility, and the Fn key setting
  Settings.swift           Menu choices and where the word list lives
  Log.swift                The app's log: Fn timings and what Murmur did, never words or typed keys
Tests/MurmurCoreTests/     Unit tests, named by SPEC.md section
Resources/Info.plist       Bundle id com.judelewis.murmur; menu bar only; microphone reason
scripts/                   install.sh, check-speech.sh
docs/architecture.md       Why each choice was made
archive/                   Finished TODO items
```

## Rules

- Plan first. For anything beyond a trivial change, show the plan and wait for Jude's go-ahead.
- Logic goes in `MurmurCore` as plain functions with tests. The `Murmur` target only connects AppKit, audio and FluidAudio. If something is hard to test, the logic is in the wrong place.
- Add or update tests in the same change as any feature. Each test suite's name starts with the SPEC.md section it proves, such as "2.1 Double tap Fn".
- When behaviour changes, update SPEC.md in the same change, and move finished TODO.md items to `archive/`.
- After changing the app, run `./scripts/install.sh` so the copy in Applications is the new one. Jude tests by dictating into real apps.
- After upgrading FluidAudio, run `./scripts/check-speech.sh`.
- British English in all user-facing text. No em dashes anywhere, in text or comments. Menu and pill wording must make sense to someone who doesn't code.
- Never commit anything from `.env` files. `.env.local.example` holds names only.

## Gotchas

Format: **Rule**: why it matters.

- **In Claude's sandbox, fetch packages with `--disable-dependency-cache`**: `swift package resolve` failed on 2 Nov 2026 because the shared cache in ~/Library/Caches is out of bounds. `swift build` and `swift test` work once packages are fetched.
- **The 🌐 key sends its own key press (code 179) as well as Fn (63)**: Murmur counted it as "another key" and the double tap never fired on Jude's MacBook Air (2 Nov 2026). FnWatcher ignores Fn's own codes. Enforced by the "2.1 Double tap Fn: keyboard events" tests.
- **Use `/usr/bin/log`, not `log`**: in zsh `log` is a built-in command, so `log show` fails with "too many arguments" (2 Nov 2026).
- **Don't use `CGEvent.timestamp` for timing**: on Apple silicon it counts clock ticks, not nanoseconds. FnKeyMonitor uses `ProcessInfo.systemUptime` (2 Nov 2026).
- **The first load of each speech model takes about a minute**: macOS prepares the model for the Neural Engine once; later loads take under a second (seen 2 Nov 2026). Not a hang.

## Sources of truth

- SPEC.md: what Murmur does. Wins on behaviour.
- docs/architecture.md: why it is built this way.
- TODO.md: what to do next.
- FUTURE_TEST.md: what is not tested automatically, and why.

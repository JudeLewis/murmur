# Murmur: Claude context

## What it is

A Mac menu bar app for dictation: a free replacement for Wispr Flow and for Apple's own dictation, which Jude found missed too much of what they said. Double-tap Fn to start listening, double-tap Fn again to stop, and the text appears wherever the cursor is, in any app. Speech turns into text on the Mac itself, with NVIDIA's Parakeet model (the Bark 3.0 Clean version, which drops "um", false starts and repeated words). Nothing leaves the Mac.

Built for one person: Jude, on an M3 MacBook Air with 16 GB, macOS 26, and on their iPhone 16 as an app plus a keyboard (SPEC.md 9). Not for sale or the App Store. Jude is not a coder: read docs/working-with-jude.md before replying.

Separate from Clocked In (~/Developer/clocked-in). Never touch that folder from here.

## Stack

- Swift 6.2 and Swift Package Manager for the Mac app, with no Xcode project. Everything is plain text files.
- Apple's FoundationModels (Apple Intelligence, on the Mac, free and offline) for Command Mode and fixing self-corrections. Checked available on Jude's Mac on 2 Nov 2026.
- AppKit for the menu bar, the event tap and the floating pill; SwiftUI inside the pill.
- iPhone: an app and a keyboard extension in SwiftUI and UIKit, built from iPhone/Murmur.xcodeproj (written by hand; its folders App, Keyboard and Shared are picked up automatically, so new files need no project edits). It uses MurmurCore and MurmurSpeech from the Swift package.
- FluidAudio (github.com/FluidInference/FluidAudio) for speech to text, with `traits: []` so only its speech-to-text part is built.
- Swift Testing for unit tests (`import Testing`, `@Test`, `#expect`).
- Signed with Jude's Apple Development certificate, so macOS permissions survive rebuilds.

## Commands

| What | Command |
| --- | --- |
| build | `swift build` |
| unit tests | `swift test` |
| check the speech model end to end | `./scripts/check-speech.sh` (makes speech with `say`, transcribes it, prints OK or NOT OK) |
| try any recording | `.build/debug/Murmur --transcribe file.wav [--exact] [--whisper]` |
| try Type as I speak on a recording | `.build/debug/Murmur --live file.wav` (what would be on screen each second, then the finished text and the all-at-once text) |
| try the on-device AI | `.build/debug/Murmur --rewrite "make this friendlier" "Send me the report."` or `--fix "Monday, no wait, I mean Tuesday."` |
| install and run Jude's copy | `./scripts/install.sh` (build, wrap as Murmur.app, sign, copy to /Applications, open) |
| install on Jude's iPhone | `./scripts/install-phone.sh` (build, sign, install, open; phone unlocked, plugged in or on the same Wi-Fi) |
| read the iPhone's trace | `xcrun devicectl device copy from --device 00008140-000834E10E82801C --domain-type appGroupDataContainer --domain-identifier group.com.judelewis.murmur --source Library/Murmur/trace-app.txt --destination <scratchpad>/trace-app.txt` (also trace-keyboard.txt, status.json) |
| read the app's log | `/usr/bin/log show --last 10m --predicate 'subsystem == "com.judelewis.murmur"' --style compact` |

The pre-commit hook (.githooks/pre-commit) runs `swift build` and `swift test`, and builds the iPhone app when anything it uses has changed. A fresh clone needs `git config core.hooksPath .githooks` once.

## Folder map

```
Sources/MurmurCore/        Plain logic, no AppKit or audio; all of it tested
  DoubleTap.swift          When Fn presses and releases make a double tap
  FnWatcher.swift          Raw key events to "double tap" or "Escape"
  DictationFlow.swift      The on/off switch: idle, recording, transcribing
  Tidy.swift               Model text to pasted text; the recent list
  BritishSpelling.swift    American to British spelling, from a fixed word list
  WordList.swift           Jude's own word list (words.txt), and writing it back
  WordFix.swift            Spotting word list fixes in a corrected dictation
  Snippets.swift           Say a phrase, get saved text
  SpokenCommands.swift     "new line", "new paragraph", "press enter"; casual style; Tidy.dictation, the whole order
  Ducking.swift            Turning music down while listening (Mac)
  OnDeviceAIPrompts.swift  Command Mode and self-correction prompts and checks; Whisper mode; ⌃⌘V; microphone choice
  LiveTyping.swift         Type as I speak: which words have settled, and what to delete and type
  PhoneLink.swift          iPhone: what the keyboard shows, sends and types; the 10 minute session
  LinkStore.swift          iPhone: the files the app and keyboard share, and their trace
Sources/MurmurSpeech/      Shared by Mac and iPhone: needs FluidAudio, the microphone or Apple Intelligence
  Transcriber.swift        Loading the Parakeet model and transcribing
  SpeechModel.swift        Tidy (Bark 3.0 Clean) or exact (Bark 3.0)
  MonoMix.swift            One microphone buffer to mono samples and a loudness level
  OnDeviceAI.swift         Apple's on-device AI model (FoundationModels): Command Mode, self-corrections, time limits
Sources/MurmurUI/          SwiftUI screens shared by Mac and iPhone: the word list and snippets (WordsView, WordsModel)
Sources/Murmur/            The app: wires the logic to the Mac
  main.swift               Starts the app; also the --transcribe test mode
  AppDelegate.swift        Menu bar, and each dictation from microphone to paste
  FnKeyMonitor.swift       Event tap that spots Fn (double tap and hold) and Escape
  Recorder.swift           Microphone into memory
  Paster.swift             Clipboard and Command-V, then restores the clipboard
  Pill.swift               The black pill at the bottom of the screen
  Permissions.swift        Microphone, Accessibility, and the Fn key setting
  Settings.swift           Menu choices, and where the word list and snippets live
  SystemVolume.swift       The Mac's output volume, for turning music down
  Selection.swift          The selected text in the app in front, for Command Mode
  LiveTyper.swift          Type as I speak: reads the recording again each second and types settled words
  Microphones.swift        The Mac's microphones (Core Audio) and whether the lid is shut
  Log.swift                The app's log: Fn timings and what Murmur did, never words or typed keys
iPhone/                    The iPhone app and keyboard
  Murmur.xcodeproj         Two targets: MurmurPhone (the app) and MurmurKeyboard
  App/                     PhoneMurmur (model, sessions, answering the keyboard), SessionMic, the screen
  Keyboard/                KeyboardViewController and KeyboardView
  Shared/                  The shared folder and Bell (nudges between app and keyboard)
  Config/                  Info.plist and entitlements for each target
Tests/MurmurCoreTests/     Unit tests, named by SPEC.md section; RulesTests checks project rules
Resources/Info.plist       Bundle id com.judelewis.murmur; menu bar only; microphone reason
Resources/Logo/murmur.svg  The logo (B1, starlings at dusk); scripts/make-icons.sh turns it into both app icons
scripts/                   install.sh, install-phone.sh, check-speech.sh, make-icons.sh
docs/architecture.md       How a dictation works step by step, where things live, and why
docs/working-with-jude.md  How Jude likes replies, steps and the way work is done
archive/                   Finished TODO items
```

## Rules

- Plan first. For anything beyond a trivial change, show the plan and wait for Jude's go-ahead.
- The order of work: plan, build with tests, /code-review and fix what it finds, `./scripts/install.sh`, Jude tests, commit (Claude commits checked work without asking; pushes only when Jude asks). Details in docs/working-with-jude.md.
- Keep the docs current without asking: in the same turn as any change or decision, update SPEC.md, docs/architecture.md, TODO.md (finished items to archive/) and Claude's memory, and say in one line what changed.
- Logic goes in `MurmurCore` as plain functions with tests. The `Murmur` target only connects AppKit, audio and FluidAudio. If something is hard to test, the logic is in the wrong place.
- Add or update tests in the same change as any feature. Each test suite's name starts with the SPEC.md section it proves, such as "2.1 Double tap Fn"; RulesTests checks those sections still exist.
- A repeated mistake becomes a test in RulesTests, not another line of prose.
- When behaviour changes, update SPEC.md in the same change, and move finished TODO.md items to `archive/`.
- After changing the app, run `./scripts/install.sh` so the copy in Applications is the new one. Jude tests by dictating into real apps.
- After upgrading FluidAudio, run `./scripts/check-speech.sh`.
- British English in all user-facing text. No em dashes anywhere, in text or comments (RulesTests checks). Menu and pill wording must make sense to someone who doesn't code.
- Murmur is on GitHub, public since 2 Nov 2026: github.com/JudeLewis/murmur. Anyone can read what is pushed, so keep secrets and personal details out of committed files. Push only when Jude asks.
- Never commit anything from `.env` files. `.env.local.example` holds names only.

## Gotchas

Format: **Rule**: why it matters.

- **In Claude's sandbox, fetch packages with `--disable-dependency-cache`**: `swift package resolve` failed on 2 Nov 2026 because the shared cache in ~/Library/Caches is out of bounds. `swift build` and `swift test` work once packages are fetched.
- **The 🌐 key sends its own key press (code 179) as well as Fn (63)**: Murmur counted it as "another key" and the double tap never fired on Jude's MacBook Air (2 Nov 2026). FnWatcher ignores Fn's own codes. Enforced by the "2.1 Double tap Fn: keyboard events" tests.
- **Use `/usr/bin/log`, not `log`**: in zsh `log` is a built-in command, so `log show` fails with "too many arguments" (2 Nov 2026).
- **Don't use `CGEvent.timestamp` for timing**: on Apple silicon it counts clock ticks, not nanoseconds. FnKeyMonitor uses `ProcessInfo.systemUptime` (2 Nov 2026).
- **The Mac only sees Library/ inside an iPhone App Group folder**: `devicectl` listed nothing and couldn't copy files at the top of group.com.judelewis.murmur, though the app had written them (2 Nov 2026). The shared files live in Library/Murmur.
- **Open a newly installed iPhone app by hand the first time**: `devicectl` refused to launch it ("invalid code signature, inadequate entitlements") until Jude tapped the icon once; after that it launched fine (2 Nov 2026).
- **Every iPhone install makes the model get ready again, for minutes**: iOS drops the copy prepared for the iPhone's chip when the app is reinstalled. On 2 Nov 2026 it took 75 seconds to 5.5 minutes per install, and Jude twice saw "Writing" for ages. Keeping the same build number doesn't help (tested: still 75 seconds). Later opens of the same install take 0.4 seconds. The app now shows a "Getting Murmur ready" card with a timer and keeps the screen awake; install-phone.sh keeps trying to open the app until the phone is unlocked. Still bundle phone changes into few installs.
- **The first load of each speech model takes about a minute**: macOS prepares the model for the Neural Engine once; later loads take under a second (seen 2 Nov 2026). Not a hang.

## Sources of truth

- SPEC.md: what Murmur does. Wins on behaviour.
- docs/architecture.md: how it works and why it is built this way.
- docs/working-with-jude.md: how Jude likes to work.
- TODO.md: what to do next.
- FUTURE_TEST.md: what is not tested automatically, and why.
- "How Murmur works on your Mac" (https://claude.ai/artifact/G7DUw2Ba9G9wmsFacXimHT): Jude's plain-English guide, a Claude Doc with a flow diagram. Edit it with the Claude Docs tools when Mac behaviour changes; SPEC.md still wins.

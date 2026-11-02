# How Murmur works, and why

The project's memory: how the pieces fit, where things live, and why each choice was made. Keep it current with every change (see docs/working-with-jude.md).

## One dictation, start to finish

1. **Launch** (AppDelegate). Murmur adds its wave icon to the menu bar, asks for the microphone and Accessibility, starts watching the keyboard (FnKeyMonitor), and loads the speech model in the background (Transcriber). Once Accessibility is allowed, the pill says "Murmur is ready".
2. **Fn, Fn** (FnKeyMonitor, then FnWatcher and DoubleTapDetector in MurmurCore). An event tap passes every key straight on to the app in front, and hands Fn's presses and releases to FnWatcher, which decides when they make a double tap. Escape is reported the same way.
3. **Listening** (DictationFlow, Recorder, Pill). The on/off switch moves to recording. A fresh Recorder takes the default microphone into memory, mixed to mono. A timer feeds its loudness to the pill's bars 20 times a second. A 15-minute limit stops it if forgotten.
4. **Fn, Fn again**. The switch moves to transcribing. The recorder stops and hands over its samples.
5. **Speech to text** (Transcriber). The samples are resampled to 16 kHz, padded to at least a second, and given to Parakeet through FluidAudio's AsrManager. Bark 3.0 Clean writes the text without fillers.
6. **Tidying** (Tidy, BritishSpelling, WordList in MurmurCore). Spaces squeezed, silence dropped, first letter made a capital, British spelling, then Jude's word list, which always has the last say.
7. **Pasting** (Paster). The text goes on the clipboard, Murmur presses Command-V, then puts back the old clipboard after 0.6 seconds. The text is added to Recent.
8. **Done**. The switch goes back to idle. If anything failed, the recording is kept so the menu can offer "Try the last recording again".

## Where things live

| What | Where |
| --- | --- |
| The installed app | /Applications/Murmur.app (built into build/Murmur.app first) |
| Speech models | ~/Library/Application Support/FluidAudio/Models (about 400 MB each) |
| Jude's word list | ~/Library/Application Support/Murmur/words.txt |
| Menu choices and recent dictations | Murmur's preferences (`defaults read com.judelewis.murmur`) |
| Murmur's log | The Mac's system log, subsystem com.judelewis.murmur |
| Permissions | System Settings > Privacy & Security (Microphone, Accessibility), tied to the app's signature |

## Changing things safely

- **New rule about text or keys**: put it in MurmurCore as a plain function, test it, then call it from the app.
- **New menu option**: add its setting to Settings.swift, its item to `menuNeedsUpdate` in AppDelegate.swift, and a line to SPEC.md 6.3.
- **New pill message**: add it to SPEC.md 5 and keep it short and plain.
- **Upgrading FluidAudio**: change the version in Package.swift, run `swift package resolve --disable-dependency-cache`, then `./scripts/check-speech.sh`.
- **Anything that changes behaviour**: SPEC.md in the same change.

# Why it's built this way

Decided 2 November 2026, when the first version was built.

## A native Swift app, not Electron or Python

Watching the Fn key, pasting into other apps and floating a pill over everything are all Mac system features, easiest from Swift. A native menu bar app also starts instantly and uses little memory, apart from the speech model itself.

## Swift Package Manager, not an Xcode project

Every file is plain text that Claude can read and edit, and one script (scripts/install.sh) turns the build into Murmur.app. An Xcode project file is hard to edit by hand and easy to break.

## Parakeet (Bark 3.0 Clean) through FluidAudio, not Whisper

- Accuracy: FluidAudio's own benchmarks on an M5 Pro put Parakeet v3 at 2.27% word errors on LibriSpeech test-clean, and Bark 3.0 Clean at 2.37%, counting the fillers it deliberately drops as errors.
- Speed: about 140 times faster than real time on the Neural Engine. On Jude's M3 a 10-second clip is written out in about a tenth of a second.
- Bark 3.0 Clean leaves out "um", false starts and repeated words, which is most of what Wispr Flow's AI tidy-up does, at no cost and without the internet.
- English only. If Jude ever needs another language, Parakeet v3 covers 25 European languages through the same code (`AsrModelVersion.v3`).

## Double tap Fn, not hold

Jude's choice: tap twice to start and twice to stop, so long dictations don't need a finger held down. Fn is otherwise rarely used alone, once "Press 🌐 key to" is set to Do Nothing.

## Pasting through the clipboard

Putting the text on the clipboard and pressing Command-V works in every app, including browsers, Electron apps and terminals. Typing it letter by letter is slow and breaks in some apps. The clipboard is put back afterwards.

## Signed with an Apple Development certificate

macOS ties the Microphone and Accessibility permissions to the app's signature. With Jude's certificate the signature stays the same between builds, so the permissions survive reinstalls. Ad hoc signing would mean allowing them again after every build.

## The word list fixes text afterwards

The simplest approach that works: plain find and replace on whole words. FluidAudio can also use the list to guide the model as it listens (custom vocabulary boosting), at the cost of a second model; that is in TODO.md for if the simple version isn't enough.

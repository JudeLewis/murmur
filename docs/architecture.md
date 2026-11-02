# Why Murmur is built this way

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

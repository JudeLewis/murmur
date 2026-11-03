# How Murmur works, and why

The project's memory: how the pieces fit, where things live, and why each choice was made. Keep it current with every change (see docs/working-with-jude.md).

## One dictation, start to finish

1. **Launch** (AppDelegate). Murmur adds its wave icon to the menu bar, asks for the microphone and Accessibility, starts watching the keyboard (FnKeyMonitor), and loads the speech model in the background (Transcriber). Once Accessibility is allowed, the pill says "Murmur is ready".
2. **Fn, Fn** (FnKeyMonitor, then FnWatcher and DoubleTapDetector in MurmurCore). An event tap passes every key straight on to the app in front, and hands Fn's presses and releases to FnWatcher, which decides when they make a double tap. Escape is reported the same way.
3. **Listening** (DictationFlow, Recorder, Pill). Holding Fn for half a second also starts it (FnWatcher's hold, checked by a timer since nothing else happens while a key is held); letting go is step 4. The volume drops to a quarter (Ducking, SystemVolume). The on/off switch moves to recording. A fresh Recorder takes the default microphone into memory, mixed to mono. A timer feeds its loudness to the pill's bars 20 times a second. A 15-minute limit stops it if forgotten.
4. **Fn, Fn again**. The switch moves to transcribing. The recorder stops and hands over its samples.
5. **Speech to text** (Transcriber). The samples are resampled to 16 kHz, padded to at least a second, and given to Parakeet through FluidAudio's AsrManager. Bark 3.0 Clean writes the text without fillers.
6. **Tidying** (Tidy.dictation in MurmurCore). Spaces squeezed, silence dropped, first letter made a capital, British spelling, Jude's word list, then "press enter" taken off the end, "new line" and "new paragraph" turned into breaks, casual style if the app in front is ticked, and last snippets, so their saved text is never changed.
7. **Pasting** (Paster). The text goes on the clipboard, Murmur presses Command-V, then puts back the old clipboard after 0.6 seconds, and presses Return if "press enter" was said. The text is added to Recent.
8. **Done**. The switch goes back to idle. If anything failed, the recording is kept so the menu can offer "Try the last recording again".

## One dictation from the iPhone keyboard

1. **Tap Talk with no session** (KeyboardTalker). The keyboard sees no fresh heartbeat in status.json, so it opens murmur://start. Keyboards aren't allowed to open apps, so it finds the app object in its responder chain and calls openURL there.
2. **The app starts a session** (PhoneMurmur, SessionMic). It turns the microphone on (category playAndRecord, mixing with other audio, iPhone microphone only) and keeps it running, which is what lets iOS keep the app alive in the background. Sound is thrown away as it arrives. A timer updates the heartbeat every 2 seconds and ends the session 10 minutes after the last dictation (PhoneSession). Jude taps ◀ to go back.
3. **Tap Talk again**. The keyboard writes request.json ("start", with an id) and rings the app's bell (a Darwin notification). The app reads it, DictationFlow decides, and SessionMic starts keeping sound. The app writes status.json and rings the keyboard's bell, so the keyboard shows Listening.
4. **Tap to stop**. Same route with "stop". The app hands the samples to Transcriber and tidies the text exactly as on the Mac, then puts the result, with the recording's id, in status.json.
5. **Typing** (KeyboardLink.delivery). The keyboard types the text only if the id is the one it is waiting for, adding spaces as needed (Tidy.forInsertion). Both sides add a line to their trace file.

## Where things live

| What | Where |
| --- | --- |
| The installed app | /Applications/Murmur.app (built into build/Murmur.app first) |
| Speech models | ~/Library/Application Support/FluidAudio/Models (about 400 MB each) |
| Jude's word list | ~/Library/Application Support/Murmur/words.txt (edited in the Word list and snippets window) |
| Mac settings (microphone, Command Mode, Whisper mode and the rest) | Murmur's preferences (`defaults read com.judelewis.murmur`) |
| Snippets | ~/Library/Application Support/Murmur/snippets.json; on iPhone, the app's preferences |
| Menu choices and recent dictations | Murmur's preferences (`defaults read com.judelewis.murmur`) |
| Murmur's log | The Mac's system log, subsystem com.judelewis.murmur |
| Permissions | System Settings > Privacy & Security (Microphone, Accessibility), tied to the app's signature |
| The logo and app icons | Resources/Logo/murmur.svg; `./scripts/make-icons.sh` makes iPhone/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png and Resources/AppIcon.icns |
| iPhone app and keyboard code | iPhone/ (the Xcode project, App, Keyboard, Shared, Config) |
| iPhone speech model | Inside the app on the phone, Application Support/FluidAudio |
| iPhone settings, word list and recent | The app's own preferences on the phone |
| iPhone shared files | App Group group.com.judelewis.murmur, in Library/Murmur: status.json, request.json, trace-app.txt, trace-keyboard.txt |

## Changing things safely

- **New rule about text or keys**: put it in MurmurCore as a plain function, test it, then call it from the app.
- **The word list and snippets screens**: one SwiftUI view in Sources/MurmurUI used by both the Mac window and the iPhone app; each platform only says where things are saved.
- **New menu option**: add its setting to Settings.swift, its item to `menuNeedsUpdate` in AppDelegate.swift, and a line to SPEC.md 6.3.
- **New pill message**: add it to SPEC.md 5 and keep it short and plain.
- **Upgrading FluidAudio**: change the version in Package.swift, run `swift package resolve --disable-dependency-cache`, then `./scripts/check-speech.sh`.
- **Anything that changes behaviour**: SPEC.md in the same change.
- **A new file for the iPhone**: put it in iPhone/App, iPhone/Keyboard or iPhone/Shared; Xcode picks it up without editing the project. Run `./scripts/install-phone.sh` to try it.

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

## iPhone: a keyboard that asks the app (decided 2 Nov 2026)

Jude chose a keyboard (option B) over an app on the Action button (A) and a Shortcut sending audio online (C), because it types straight into any app, like the Mac. iOS doesn't let keyboards use the microphone, so the app does the listening and writing and the keyboard is only a remote control. Wispr Flow's keyboard works the same way, including the trip to the app to start a session.

- **Two small files and a bell, not shared settings.** status.json and request.json in the App Group folder, each written by one side only, plus a Darwin notification to say "read it". Files are read fresh every time, so there are no stale caches between the two processes.
- **A heartbeat.** iOS can close the app in the background without warning. The keyboard trusts the session only while the heartbeat is under 6 seconds old, and checks every second.
- **Start and stop are separate requests, not a toggle,** so a keyboard showing an old state can't stop a recording it meant to start.
- **The iPhone's own microphone, music left playing.** Letting AirPods be the microphone would drop their sound quality for the whole 10-minute session.
- **The model stays in the app.** Keyboards get about 50 MB of memory, far too little for a 400 MB model.
- **A hand-written Xcode project.** Swift Package Manager can't build an iPhone app with a keyboard extension. The project uses folders that Xcode reads automatically, so it rarely needs editing, and no extra tools (like XcodeGen) are needed.
- **A trace, not just the system log.** Reading an iPhone's log from the Mac is awkward; two small text files in the shared folder can be copied over with one command.

## The logo (chosen 2 Nov 2026)

A flowing wave of white starlings on a dusk sky, navy to purple to coral: a murmuration, for the name, shaped like a sound wave. Jude picked it (B1) from two rounds of ideas. It is the app icon on the iPhone and the Mac. The menu bar keeps its simple wave symbol, because a flock of dots turns to noise at menu bar size.

## Wispr Flow features (added 2 Nov 2026)

Jude asked for Wispr Flow's best ideas and picked six: snippets, spoken commands, a proper word list screen with fixes from recent dictations, casual style, hold Fn, and music down. All run on the device, free.

- **One order for everything after the model** (Tidy.dictation), tested as a whole, so the Mac and iPhone can't drift apart.
- **Snippets last**, so British spelling or casual style never touch an email address or a sign-off.
- **Casual style per app on the Mac, a switch on the iPhone.** The Mac knows which app is in front; an iPhone keyboard isn't told which app it's typing into.
- **Fixes from a corrected dictation** compare words, not letters, and only suggest changes of up to four words, so rewording a sentence doesn't fill the word list.
- **Hold Fn** waits half a second, longer than a tap, so double tap still works and Fn+key shortcuts throw the recording away rather than leaving Murmur listening.
- **Music down** lowers the whole Mac's volume, since there's no general way to lower just other apps. It goes back only if untouched, so Murmur never undoes a change you made.
- **The keyboard looks like Wispr Flow's**: a top bar for talking and number and punctuation keys for small edits, so you don't need to switch keyboards as often.

## Mac extras from Wispr Flow (added 2 Nov 2026)

Jude asked what Wispr Flow's computer version does and picked five: Command Mode, fixing self-corrections, paste again, Whisper mode and choosing the microphone.

- **Apple's on-device AI, not Claude or Wispr's servers.** Apple Intelligence runs on the Mac through FoundationModels: free, private, offline. Tested before building: a friendlier rewrite in 2.5 seconds; with three examples in the prompt, self-corrections fixed in about a second and ordinary text left alone (without examples it changed nothing).
- **Self-corrections can only take words out** (SelfCorrection.accept): a small model that rewords or adds would be worse than none. It is only asked when a correction word is present.
- **Command Mode is Fn and Control held**, Wispr's own shortcut, built on the same hold timing as Hold Fn. The selected text is read after the keys are let go, through Accessibility, with Command-C only for apps that don't answer, so the copy never mixes with held keys.
- **Whisper mode is a volume boost before the model**, off by default. Parakeet already copes with quiet speech; the boost only helped real whispering at low volume (tested with the Mac's Whisper voice), and boosting near-silence could turn hiss into words.
- **Microphone choice sets the recorder's own input**, leaving the Mac's default alone; Automatic only steps in with the lid shut. Rules in MicChoice.
- **Murmur's own key presses are tagged** (eventSourceUserData) so its keyboard watch lets them through, and it waits for Control, Command and Fn to be let go before pressing keys itself, so they never mix.
- **Apple's gentler safety setting** (`permissiveContentTransformations`, meant for rewriting the user's own text): the default one blocked "turn this into bullet points" on a shopping list about one time in three.
- **Every AI call has a time limit** (3 seconds for self-corrections, 20 for Command Mode), so a slow model can't stop the next dictation.
- **Test modes**: `.build/debug/Murmur --rewrite "instruction" "text"` and `--fix "text"` run the same AI steps as the app.
- **The menu's ticks moved into a Settings submenu**, as the menu had grown long.
- **The time limit doesn't wait for the model to stop** (OnDeviceAI.respond races the answer against a timer through one continuation). A task group would have waited for the model to notice it was cancelled, so a stuck model could still hold up the next dictation (found in review, 3 Nov 2026).

## The extras on iPhone (added 3 Nov 2026)

Jude asked for the "no wait" fix, Whisper mode, paste again and Command Mode on the phone, in one install. Choosing the microphone was left out: iOS switches to AirPods or a wired mic itself, and there's no lid.

- **OnDeviceAI moved to MurmurSpeech** so the Mac and the iPhone app share it. The keyboard doesn't link it: only the app asks Apple Intelligence.
- **The whole order with the fix lives in MurmurCore** (`Tidy.dictation(_:…fix:)`), with the AI call passed in, so both apps use one tested order.
- **The app does the AI work, usually in the background**, as it does the listening. iOS has a `rateLimited` error for background apps asking too much; it shows as "Apple Intelligence is busy". The trace says whether the app was on screen each time, so a real phone shows how often that happens.
- **Command Mode's selection is what iOS gives the keyboard** (`selectedText`). The answer only goes over the selection if that's still what's selected when it arrives; otherwise it stays in Recent. Undo puts the selection back.
- **The last dictation is its own file** (last.txt), written once per dictation, for the "again" key: status.json is written ten times a second while listening, so long text doesn't belong in it.

## Type as I speak (added 3 Nov 2026)

Jude asked for the words to appear while talking, not at the end, and picked "type words as they settle" over words in the pill only or a different, live-only model (NVIDIA Nemotron, which keeps "um" and needs 600 MB more).

- **Same model, read again each second.** LiveTyper reads the audio from 5 seconds before the settled words to now; LiveTranscript (MurmurCore) settles a word once two readings in a row agree on it, using FluidAudio's word timings. A reading takes about 60 ms on Jude's M3, so the text runs a second or two behind. FluidAudio's own SlidingWindowAsrManager was no good for this: it only confirms text after about 10 seconds.
- **Words from the context part are dropped by time** (most of the word before the settled end), and the last settled word heard again a little later is dropped by spelling: on 3 Nov 2026 "part" came out twice without that. A word ending in the last 0.3 s waits, as it may be cut off.
- **The last reading gets 0.6 s of silence after it**: without it the last sentence lost its question mark and a capital. With it (and 5 s of context), both test recordings came out exactly as reading them all at once (`Murmur --live`).
- **The whole order runs on the settled text each time**, and LiveEdit types only the difference: usually just new words; a few deletions when a snippet, a two-word fix or casual style changes the end. Over 300 characters to delete means something is wrong (the cursor moved), so it stops and copies the dictation.
- **Typed with key presses (unicode key events), not the clipboard**, whole characters at a time. Line breaks are pasted, since a typed Return sends messages; the clipboard is put back once at the end, so two pastes close together can't lose it.
- **While Fn is held, deleting waits**: Fn and Delete is forward delete.
- **No "no wait" fix while it's on**: the words are already typed. Command Mode still answers at the end.

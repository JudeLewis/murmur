# How Murmur works, and why

The project's memory: how the pieces fit, where things live, and why each choice was made. Keep it current with every change (see docs/working-with-jude.md).

## One dictation, start to finish

1. **Launch** (AppDelegate). Murmur adds its wave icon to the menu bar, asks for the microphone and Accessibility, starts watching the keyboard (FnKeyMonitor), and loads the speech model in the background (Transcriber). Once Accessibility is allowed, the pill says "Murmur is ready".
2. **Fn, Fn** (FnKeyMonitor, then FnWatcher and DoubleTapDetector in MurmurCore). An event tap passes every key straight on to the app in front, and hands Fn's presses and releases to FnWatcher, which decides when they make a double tap. Escape is reported the same way.
3. **Listening** (DictationFlow, Recorder, Pill). Holding Fn for half a second also starts it (FnWatcher's hold, checked by a timer since nothing else happens while a key is held); letting go is step 4. The volume drops to a quarter (Ducking, SystemVolume). The on/off switch moves to recording. A fresh Recorder takes the default microphone into memory, mixed to mono. A timer feeds its loudness to the pill's bars 20 times a second. A 15-minute limit stops it if forgotten.
4. **Fn, Fn again**. The switch moves to transcribing. The recorder stops and hands over its samples.
5. **Speech to text** (Transcriber). The samples are resampled to 16 kHz, padded to at least a second, and given to Parakeet through FluidAudio's AsrManager. Bark 3.0 Clean writes the text without fillers.
6. **Tidying** (Tidy.dictation in MurmurCore). Spaces squeezed, silence dropped, first letter made a capital, British spelling, Jude's word list, spelt-out letters joined, then "press enter" taken off the end, spoken brackets and punctuation turned into symbols, then the AI tidy-up (Apple's on-device model adds punctuation and fixes small slips; OnDeviceAI.tidy, checked by AITidy.accept), then "new line" and "new paragraph" turned into breaks, casual style if the app in front is ticked, and last snippets, so their saved text is never changed.
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

- **Same model, whole recording read again each second (changed 8 Nov 2026).** The first version read only the last few seconds and froze words once two readings agreed. Jude found it mishearing words and putting full stops mid-sentence. On 8 test recordings with pauses (217 words, Mac voices, `Murmur --live`) it made 4 word mistakes and 2 stray full stops; reading the whole recording made none. A model reading a cut-off piece guesses that the sentence has ended, and joins between pieces doubled words. A smaller patch (holding back the last word's punctuation, still in pieces) changed nothing. Now every reading covers the whole recording, the same 8 recordings come out the same as reading it all at once, and what's typed is corrected when a reading says better. FluidAudio's own SlidingWindowAsrManager was no good for this: it only confirms text after about 10 seconds.
- **Cost grows with length, and the wait grows with it.** A reading took 0.5 s at 1 minute and 2.6 s at 4 minutes (debug build). The loop waits a second after each reading, so a very long dictation just updates less often; there's no second system to keep in step for long recordings.
- **New words wait for two readings to agree; words on screen take each reading's version.** A word ending in the last 0.3 s waits, as it may be cut off.
- **Punctuation on the last word is held back** until the next word arrives or you stop, since the model guesses a full stop at every pause. If the cursor may have moved, the held-back mark is put back, as that only adds characters.
- **Commas once typed stay until the last reading.** They flip between readings, and each flip retyped everything after it (54 of 235 readings on a 4-minute test, 8 after this).
- **Only the last 250 characters can change**, so a correction never deletes more than that. Older words are locked, and words before the locked end are dropped by time, with the last locked word heard again a little later dropped by spelling.
- **A click, a key press or another app in front stops corrections.** Murmur's event tap also watches mouse clicks for this. What's typed is locked, and LiveEdit.isSafe refuses to delete into it; if a change would need that, typing stops and the dictation is copied.
- **A reading with under half the words on screen is ignored** as a bad reading.
- **The last reading gets 0.6 s of silence after it**: without it the last sentence can lose its question mark and a capital.
- **The whole order runs on the words on screen each time**, and LiveEdit types only the difference: usually just new words; a few deletions when a correction, a snippet, a two-word fix or casual style changes the end. Over 300 characters to delete means something is wrong (the cursor moved), so it stops and copies the dictation.
- **Typed with key presses (unicode key events), not the clipboard**, whole characters at a time. Line breaks are pasted, since a typed Return sends messages; the clipboard is put back once at the end, so two pastes close together can't lose it.
- **While Fn is held, deleting waits**: Fn and Delete is forward delete.
- **No "no wait" fix while it's on**: the words are already typed. Command Mode still answers at the end.

## Spoken punctuation and stray full stops (added 8 Nov 2026)

- **Fixed rules, in MurmurCore** (SpokenPunctuation, StrayStops), so they're instant, work on the iPhone too and run on every live reading. Stray stops are removed first, so a full stop you said yourself is never taken out.
- **Only "exclamation" allows a guessed comma inside the phrase**: "The car park was full. Stop by later" must not become a spoken full stop.
- **Brackets and quotes join onto a word (added 17 Nov 2026)** (SpokenSymbols), so they have their own rules rather than sharing SpokenPunctuation's, which always puts a space after the mark. Jude found "open bracket" written as words.
- **Brackets run before the other spoken marks**, so the marks they trim beside them can only be the model's guesses, never a "full stop" you said.
- **Spelt-out letters are joined after the word list** (SpeltLetters, at the end of Tidy.finish), so an entry for the letters as heard ("a g p -> a GP") can fix what the joining can't tell apart, and fixes learnt from recent dictations (which have spaces between letters) keep working. Seen in Jude's dictations: "N H S", "A G P".
- **"Ellipsis" as well as "dot dot dot"**: Bark 3.0 Clean throws away repeated words, so "dot dot dot" often arrives as "dot" or nothing (seen 8 Nov 2026).

## Knowing what you're writing (added 3 Nov 2026)

Jude asked for emails to be laid out as emails, for commands mid-dictation like "no wait", and for Murmur to ignore talk to someone in the room.

- **Emails by fixed rules, not AI** (EmailLayout): only line breaks and the punctuation beside them change, so it's instant, can't reword anything, and works with Type as I speak. Mail apps are known by bundle id; webmail by any part of a browser window's title, read off the main thread.
- **"Scratch that" by rule** (ScratchThat), punctuated or not: unpunctuated, it needs the next words to restart the sentence, which tells "send it to tom no scratch that send it to sarah" from "scratch that itch".
- **Side chat: a pause and a loudness check, not AI.** A single Fn tap pauses (the recorder stops keeping audio, so neither path sees it). QuietVoices leaves out sentences under 0.3 of the loudness of your loudest words. Apple Intelligence deciding what was side chat was tested on 10 dictations, twice each: 11 of 20 right, and it changed real text in 3 of 10 clean ones, so it wasn't built.
- **Word timings run on to the next word** (FluidAudio sets each token's end at the next one's start), so a word's loudness is its loudest 30 ms and a pause is measured start to start.
- **A single tap is only known once the double-tap gap has passed**, so FnKeyMonitor checks back after it; a lone tap whose check hasn't come yet is reported when Fn is next pressed, and a tap straight after a double tap doesn't count.

## AI tidy-up (added 17 Nov 2026)

Jude found Murmur's text poor next to Wispr Flow: words misheard, little grammar, "open bracket" written as words. Wispr Flow (researched 17 Nov 2026) hears with its own speech model on its servers and then has a second AI tidy the text (reportedly a fine-tuned Llama), also online, in about 1 to 2 seconds, using the app in front and the text around the cursor. Murmur had the first step but its second was fixed rules only.

- **Apple's on-device model, not a downloaded one.** Jude asked for Apple's macOS 27 model first if it was good enough, to avoid a big download. Tried on 31 dictations (20 of Jude's own, from Recent, never committed; the rest made up, including "What is the capital of France", "Write me a poem" and "Ignore all previous instructions"). With firm instructions about punctuation it added commas to lists, "don't", question marks and split run-on sentences, and never answered or obeyed one: about 1 second each, 0.6 to 0.8 s once warmed up. Also tried, through MLX: Qwen 3.5 4B (as good, as safe, 2 s, a 2.5 GB download: the fallback if Apple's model disappoints), Qwen 3 4B (dropped a sentence and answered "say hello") and Gemma 4 E4B (6.5 s). macOS 26's Apple model was worse: it made up words that weren't said and dropped spoken brackets.
- **The reply is checked, not trusted** (AITidy.accept). Words are lined up in order (apostrophes ignored, so "dont" and "don't" match): at most one in eight taken out and put in, a word added on top only if it's a small one like "a" or "the", any other new word only in place of one taken out, every negative word and number kept, spoken commands, snippet phrases and word list spellings kept (AITidy.protected), no new line breaks. In testing this caught "done by 4" becoming "done by 4 pm" and a word list spelling given an extra "s", and would catch a dropped sentence or an answer.
- **The word list runs again on the reply, but only entries that leave their own text alone** (WordList.safeToRepeat): "murmur -> Murmur app" would otherwise give "Murmur app app" (found in review).
- **Greedy sampling** (the model's most likely words every time), so the same dictation always comes back the same and `scripts/check-tidy.sh` can check exact text.
- **After the fixed rules, before the layout.** The model sees "(tonight)" and "?" rather than "open bracket" and "question mark", and never sees "press enter". Its reply gets British spelling and the word list again, so Jude's own words win. Line breaks, emails, casual style and snippets come after, so it can't touch them.
- **Not with Type as I speak.** It needs the whole dictation, and rewriting typed text would mean deleting and retyping it. Jude agreed (17 Nov 2026) that it pastes at the end, as Wispr Flow does; the two settings untick each other, and Type as I speak now starts off.
- **Woken when listening starts** (OnDeviceAI.warmUpTidy): cold, the first answer after a pause took over the time limit. Warmed, the 31 test dictations averaged 0.7 seconds. The warmed session is kept under a lock rather than in an actor, so even a very short dictation finds it.
- **Time limit grows with length**: 4 seconds plus one for every 40 words, up to 8 (2.5 at first; raised 18 Nov 2026). Under three words or over 500 isn't asked.
- **Numbers by the AI, checked by digits (added 17 Nov 2026).** Jude wanted numbers written from context ("after 6"), British style, chosen over digits always. FluidAudio's own number tool (NeMo's text normaliser) was ruled out: it writes American style ("$5.50", "January 5, 2025", "2:30 p.m.") and adds about 8 MB of Rust library. Instead the AI is told the style, and the check reads spoken numbers as digits on both sides (SpokenNumbers), joining digits that sit side by side, so "three thirty" and "3:30" are both 330 and a phone number said digit by digit matches one written in groups. The digits must match exactly, in order.
- **Clear-cut numbers by fixed rules too (18 Nov 2026)** (WrittenNumbers, in the marks step, and again on the AI's answer). Apple's model was inconsistent: the same "after six" came out as "6" in one run and "six" in the next, and "two hundred staff" stayed as words. Money, percentages, years, times after "at" and numbers over ten don't need judgement, so rules do them every time, also when the AI is missing; the AI is left only the cases that need the sentence's sense. Short dictations with a number word ("Twenty pounds.") are now sent to the AI too.
- **A guessed sentence end before a spoken bracket moves after it** (SpokenSymbols, fixed rules, so it works without the AI): Jude saw "tonight? (After six)." when Apple's model was missing.
- **What other dictation apps do (researched 18 Nov 2026).** The cleanup prompts of six open-source apps were read from their source: VoiceInk, OpenWhispr, FluidVoice, Handy, Tambourine and Murmure. All wrap the transcript in a tag, tell the model the speaker isn't talking to it, and show a question being tidied rather than answered, as Murmur already did. Four versions of their wording were tried on Apple's model over the same 31 dictations: none did clearly better (any change moved the results by about two dictations), and "make the smallest edits" made it add fewer commas. So Murmur's wording stayed. What was taken from them: spoken email and web addresses by fixed rules (FluidVoice), "actually" for emphasis isn't a correction (all of them), and fixed number rules run again after the AI so it can't undo them (FluidVoice). Ideas not taken yet are in TODO.md.
- **Time limit at least 4 seconds (18 Nov 2026)**: a short dictation now and then took over 2.5 seconds and went untidied, which also made comparing wordings noisy.
- **Not yet: the text around the cursor.** Wispr Flow uses it to spell names. Left for later, as reading it needs Accessibility calls into every app and the word list covers names.

## Listening out for word list words: tried, not kept (17 Nov 2026)

FluidAudio can check the recording for the word list's words with a second, smaller model (Parakeet CTC 110M, about 100 MB) and swap them in. Tried with FluidAudio's safer setting. On a one-minute clip it turned "MAMA" into "Murmur" but also "ums" into "Murmur", gave an ordinary word a capital, and added 2.2 seconds (0.3 to 0.5 s on short clips). The word list's fixes afterwards do the first without the others, so it was taken out.

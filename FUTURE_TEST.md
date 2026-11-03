# Not tested automatically, and why

- **Fn key watching (FnKeyMonitor)**: needs a real keyboard and Accessibility permission. The timing rules it uses are tested (2.1).
- **Microphone recording (Recorder)**: needs a microphone. Checked by Jude dictating.
- **Pasting (Paster)**: needs another app in front and Accessibility. Checked by Jude dictating.
- **The pill and the menu**: looks only; checked by eye.
- **The speech model**: not in `swift test`, because it needs a 400 MB download and the Neural Engine, which CI machines don't have. `./scripts/check-speech.sh` checks it on this Mac; run it after any FluidAudio upgrade.
- **The iPhone app and keyboard (iPhone/)**: need a real iPhone, its microphone and a second app to type into. What they decide (sessions, what the keyboard shows, sends and types, the shared files) is tested in MurmurCore (9.2 to 9.6). The rest is checked by Jude dictating on the phone, with the trace files to see what happened.
- **Opening the app from the keyboard**: relies on iOS still letting a keyboard reach openURL through the responder chain. Only a real phone shows whether a new iOS version has stopped it.
- **Holding Fn, the volume and the word list window (Mac)**: need a real keyboard, speakers and a screen. The hold timing and the volume rule are tested (2.5, 2.6); the window's rules are tested through WordsModel, WordList.text and Snippets (4.2, 4.5); how it looks is checked by eye.
- **Command Mode and self-corrections (Mac)**: need Apple Intelligence, which CI machines don't have, and give slightly different words each time. The prompts, the clean-up of replies and the "only take words out" check are tested (2.7, 4.8); the model was tried by hand on 2 Nov 2026.
- **Reading the selected text (Mac)**: depends on each app's Accessibility support. Apps that don't answer get Command-C; a code editor that copies the whole line when nothing is selected could have that line rewritten.
- **Apple Intelligence on iPhone**: needs a real iPhone 16. How often iOS refuses the app while it's in the background ("busy") is only known from Jude's use; the trace notes each answer and whether the app was on screen. Which apps share the selected text with a keyboard is also only known by trying them.
- **Type as I speak (Mac)**: typing into real apps needs Accessibility and a screen. Which words settle, and what's deleted and typed, is tested (2.9); `Murmur --live recording` checks it with the real model. Untested: apps that handle typed key presses oddly, and whether a held Fn changes Murmur's own key presses.
- **A chosen microphone at a different rate (Mac)**: Jude's Mac has only 48 kHz microphones, so a 24 kHz one (AirPods) taking its own format in the tap hasn't been tried.
- **Choosing the microphone and the lid (Mac)**: need real devices. The choice rules are tested (3.3).

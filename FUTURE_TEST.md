# Not tested automatically, and why

- **Fn key watching (FnKeyMonitor)**: needs a real keyboard and Accessibility permission. The timing rules it uses are tested (2.1).
- **Microphone recording (Recorder)**: needs a microphone. Checked by Jude dictating.
- **Pasting (Paster)**: needs another app in front and Accessibility. Checked by Jude dictating.
- **The pill and the menu**: looks only; checked by eye.
- **The speech model**: not in `swift test`, because it needs a 400 MB download and the Neural Engine, which CI machines don't have. `./scripts/check-speech.sh` checks it on this Mac; run it after any FluidAudio upgrade.
- **The iPhone app and keyboard (iPhone/)**: need a real iPhone, its microphone and a second app to type into. What they decide (sessions, what the keyboard shows, sends and types, the shared files) is tested in MurmurCore (9.2 to 9.6). The rest is checked by Jude dictating on the phone, with the trace files to see what happened.
- **Opening the app from the keyboard**: relies on iOS still letting a keyboard reach openURL through the responder chain. Only a real phone shows whether a new iOS version has stopped it.

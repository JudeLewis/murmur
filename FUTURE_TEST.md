# Not tested automatically, and why

- **Fn key watching (FnKeyMonitor)**: needs a real keyboard and Accessibility permission. The timing rules it uses are tested (2.1).
- **Microphone recording (Recorder)**: needs a microphone. Checked by Jude dictating.
- **Pasting (Paster)**: needs another app in front and Accessibility. Checked by Jude dictating.
- **The pill and the menu**: looks only; checked by eye.
- **The speech model**: not in `swift test`, because it needs a 400 MB download and the Neural Engine, which CI machines don't have. `./scripts/check-speech.sh` checks it on this Mac; run it after any FluidAudio upgrade.

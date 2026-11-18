# TODO

Live work only. Finished items move to archive/.

## Now

- [ ] Jude tries the second list (18 Nov 2026): undo (⌃⌘Z), "make that more formal", word list offers from corrections, Learn names from Contacts, Keep recordings for testing, Code style, snippet dates; on iPhone the AI tidy-up and Type as I speak on the keyboard. Once there are kept recordings, run `./scripts/check-recordings.sh` to pick the default speech model with Jude.
- [ ] The Qwen backup (idea 8): only if Apple's model keeps dropping out.

- [ ] Jude picks the default speech model, Tidy or Ultra (compared on Mac voices 18 Nov 2026: same words, Ultra better punctuation without the AI; docs/architecture.md).

- [ ] Jude tries the AI tidy-up (17 Nov 2026) for a few days: note anything it gets wrong, and words to add to the word list. If Apple's model isn't good enough, the fallback is Qwen 3.5 4B on the Mac (docs/architecture.md, AI tidy-up).
- [ ] Watch Apple's model: it was "not ready" twice on 17 Nov 2026, first while it downloaded after the macOS 27 update, then because Claude's test downloads filled the disk (fixed). The menu now says when it's missing. If it keeps dropping out, build the Qwen 3.5 4B backup.

## Ideas, not started

- [ ] iPhone: keep a recording that failed to turn into text, and offer "Try again" in the app, as the Mac does (found in review, 2 Nov 2026).
- [ ] One microphone class for Mac and iPhone (Recorder and SessionMic are near copies; found in review, 2 Nov 2026). Left for now so the Mac app stays unchanged while the iPhone is new.


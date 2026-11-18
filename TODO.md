# TODO

Live work only. Finished items move to archive/.

## Now

- [ ] **In progress (18 Nov 2026): Jude's "do all the Mac ideas" list.** Done: lists, emoji, "literal", styles for each app, text before the cursor, Parakeet Ultra in the menu with fillers taken out. Tried and not kept: `@Generable` answers (architecture.md). Not needed: a stray-comma rule (the AI fixes 3 in 4). Still to do:
  1. Compare Ultra with Bark 3.0 Clean (`say` clips through `.build/debug/Murmur --transcribe clip.aiff --ultra`, and `./scripts/check-speech.sh`), then ask Jude which should be the default. Waiting on free space: the Mac had 8.5 GB free on 18 Nov 2026 (needs over 11 GB to download Ultra's 600 MB); Jude to pick what to delete.

- [ ] Jude tries the AI tidy-up (17 Nov 2026) for a few days: note anything it gets wrong, and words to add to the word list. If Apple's model isn't good enough, the fallback is Qwen 3.5 4B on the Mac (docs/architecture.md, AI tidy-up).
- [ ] Watch Apple's model: it was "not ready" twice on 17 Nov 2026, first while it downloaded after the macOS 27 update, then because Claude's test downloads filled the disk (fixed). The menu now says when it's missing. If it keeps dropping out, build the Qwen 3.5 4B backup.
- [ ] iPhone: the AI tidy-up in the app, once the Mac version has proved itself (needs iOS 27's model on the phone).

## Ideas, not started

- [ ] iPhone: keep a recording that failed to turn into text, and offer "Try again" in the app, as the Mac does (found in review, 2 Nov 2026).
- [ ] One microphone class for Mac and iPhone (Recorder and SessionMic are near copies; found in review, 2 Nov 2026). Left for now so the Mac app stays unchanged while the iPhone is new.

- [ ] iPhone: Type as I speak on the keyboard too, once the Mac version has been used for a while.

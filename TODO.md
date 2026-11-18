# TODO

Live work only. Finished items move to archive/.

## Now

- [ ] **In progress (18 Nov 2026): Jude's second list ("I like them all except 8... make all of them now", phone plugged in).** Recordings kept 7 days (Claude's suggestion; Jude didn't object). Order, ticked as done:
  - [x] 4. Undo dictation key (removes the last dictation if the cursor is still just after it)
  - [x] 9. Pill note when the AI tidy-up was skipped (only the first time in a row)
  - [x] 6. Snippets that fill themselves in: {date}, {time}, {day}, {tomorrow}
  - [x] 5. Command Mode with nothing selected, saying "that/it/this", rewrites the last dictation
  - [x] 7. Coding: "main dot swift" to main.swift everywhere; "camel case"/"snake case"; a Code style (no AI, no capital, no full stop)
  - [x] 1. Keep the last 20 recordings for 7 days (off to start with), and scripts/check-recordings.sh to compare models on them
  - [x] 2. Learn from corrections: read the text back after pasting, offer word list fixes (WordFix)
  - [x] 3. Names from Contacts: say each name with the Mac's voice, transcribe it, offer "heard -> name" word list entries
  - [ ] 10. iPhone: AI tidy-up in the app (needs iOS 27 on the phone)
  - [ ] 11. iPhone: Type as I speak on the keyboard
  Not doing: 8, the Qwen backup (only if Apple's model keeps dropping out).

- [ ] **In progress (18 Nov 2026): Jude's "do all the Mac ideas" list.** Done: lists, emoji, "literal", styles for each app, text before the cursor, Parakeet Ultra in the menu with fillers taken out. Tried and not kept: `@Generable` answers (architecture.md). Not needed: a stray-comma rule (the AI fixes 3 in 4). Still to do:
  1. Jude picks the default speech model. Compared 18 Nov 2026 on 20 Mac-voice clips and a 50 second clip: the same words in both (both missed Siobhan and Aoife), Ultra's punctuation better without the AI, both under a second. Ultra kept one "Ah". Real voice is the real test.

- [ ] Jude tries the AI tidy-up (17 Nov 2026) for a few days: note anything it gets wrong, and words to add to the word list. If Apple's model isn't good enough, the fallback is Qwen 3.5 4B on the Mac (docs/architecture.md, AI tidy-up).
- [ ] Watch Apple's model: it was "not ready" twice on 17 Nov 2026, first while it downloaded after the macOS 27 update, then because Claude's test downloads filled the disk (fixed). The menu now says when it's missing. If it keeps dropping out, build the Qwen 3.5 4B backup.
- [ ] iPhone: the AI tidy-up in the app, once the Mac version has proved itself (needs iOS 27's model on the phone).

## Ideas, not started

- [ ] iPhone: keep a recording that failed to turn into text, and offer "Try again" in the app, as the Mac does (found in review, 2 Nov 2026).
- [ ] One microphone class for Mac and iPhone (Recorder and SessionMic are near copies; found in review, 2 Nov 2026). Left for now so the Mac app stays unchanged while the iPhone is new.

- [ ] iPhone: Type as I speak on the keyboard too, once the Mac version has been used for a while.

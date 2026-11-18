# TODO

Live work only. Finished items move to archive/.

## Now

- [ ] Jude tries the AI tidy-up (17 Nov 2026) for a few days: note anything it gets wrong, and words to add to the word list. If Apple's model isn't good enough, the fallback is Qwen 3.5 4B on the Mac (docs/architecture.md, AI tidy-up).
- [ ] Watch Apple's model: it was "not ready" twice on 17 Nov 2026, first while it downloaded after the macOS 27 update, then because Claude's test downloads filled the disk (fixed). The menu now says when it's missing. If it keeps dropping out, build the Qwen 3.5 4B backup.
- [ ] iPhone: the AI tidy-up in the app, once the Mac version has proved itself (needs iOS 27's model on the phone).

## Ideas, not started

- [ ] iPhone: keep a recording that failed to turn into text, and offer "Try again" in the app, as the Mac does (found in review, 2 Nov 2026).
- [ ] One microphone class for Mac and iPhone (Recorder and SessionMic are near copies; found in review, 2 Nov 2026). Left for now so the Mac app stays unchanged while the iPhone is new.

- [ ] If words are still misheard after a few days of the 8 Nov fixes: try Parakeet Ultra (FluidAudio's published tests show fewer mistakes than Bark 3.0 Clean, 3.81% against 4.66%, but it keeps "um" and is a new 595 MB download).
- [ ] From other dictation apps (researched 18 Nov 2026): lists from "one ... two ..." or "first ... second ..." (Wispr Flow, VoiceInk); emoji names like "thumbs up emoji" by a fixed list (FluidVoice); saying "literal" before a word to keep it as a word (FluidVoice); Apple's structured answers (`@Generable`) so the model can't add an introduction (Handy).
- [ ] AI tidy-up knows the text around the cursor and the app, as Wispr Flow does, to spell names and match the tone.
- [ ] Remove a stray comma left where a filler was dropped ("my favourite colour is, grey"). The AI tidy-up may already fix this; check in use.
- [ ] iPhone: Type as I speak on the keyboard too, once the Mac version has been used for a while.
- [ ] Per-app styles like Wispr's (emails formal, chats casual, notes as said), building on the email layout.

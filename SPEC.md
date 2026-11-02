# Murmur: what it does

Murmur is a menu bar app. It has no window; everything happens through the Fn key, a small pill at the bottom of the screen, and the menu under its icon. On iPhone it is an app and a keyboard (section 9).

## 1. The idea

Talk instead of typing, in any app. Double-tap Fn, speak, double-tap Fn again, and your words appear where the cursor is: tidied, spelt the British way, with your own names spelt right. It runs on the Mac, so it is free, private and works offline.

## 2. Starting and stopping

### 2.1 Double tap Fn

- A tap is a press and release of Fn (the 🌐 key) lasting under 0.35 seconds.
- Two taps make a double tap when the second press comes within 0.4 seconds of the first release.
- Any other key or modifier pressed during or between the taps cancels it, so Fn used with another key (Fn+arrow, Fn+F5) never starts dictation. The 🌐 key's own extra key press (code 179) doesn't count as another key.
- A third quick tap does not count twice: after a double tap, two fresh taps are needed.

### 2.2 On and off

- Double tap when idle: start listening. The pill shows bars that move with your voice.
- Double tap while listening: stop, write the text and paste it.
- Double tap while writing: ignored until the text lands.
- Escape while listening: throw the recording away. The pill says "Cancelled". The Escape key still reaches the app in front.
- Start and Stop are also in the menu.
- If a recording can't be turned into text, it is kept in memory and the menu offers "Try the last recording again".

### 2.3 Sounds

A quiet "Tink" when listening starts and "Pop" when it stops. Can be turned off in the menu.

### 2.4 Longest recording

A recording stops by itself after 15 minutes and is written out as usual.

## 3. Speech to text

### 3.1 The models

- Runs on the Mac with NVIDIA's Parakeet model, in the Bark 3.0 versions made by Conway Research. English only.
- "Tidy speech (drops um and er)", on by default: Bark 3.0 Clean, which leaves out fillers, false starts and repeated words.
- With Tidy speech off: Bark 3.0, word for word as said.
- Each model downloads once (about 400 MB) to ~/Library/Application Support/FluidAudio/Models.

### 3.2 Getting ready

- The model loads when Murmur opens. The menu shows "Getting the speech model ready" with a percentage while it downloads.
- If you dictate before it's ready, the pill says "Getting the speech model ready" and the text appears once it is.
- If loading fails (no internet on the first run), the menu says so and offers "Try loading the speech model again".

## 4. The text that's pasted

### 4.1 British spelling

On by default. Turns American spellings into British ones from a fixed list (colour, favourite, realise, centre, travelled, grey, defence). Words spelt the same either way, or that change with meaning (program, license, practice, meter), are left alone. Capitals are kept ("Color" to "Colour"). Can be turned off in the menu.

### 4.2 Word list

- "Edit word list…" in the menu opens words.txt in TextEdit. It lives in ~/Library/Application Support/Murmur.
- Each line is a word or name to always spell exactly as typed ("Clocked In"), or a fix in the form `heard -> written` ("wisper flow -> Wispr Flow"). Lines starting with # are notes.
- Matching ignores capitals, only matches whole words, and a space in the list also matches a hyphen ("clocked-in").
- Longer entries go first. The word list goes after British spelling, so its entries always win.
- Changes work from the next dictation.

### 4.3 Tidying

- Extra spaces and line breaks are squeezed to single spaces.
- A recording of silence (nothing, or only punctuation) pastes nothing; the pill says "Didn't catch that."
- The first letter becomes a capital, unless the first word already has a capital inside it (iPhone).
- A space is added after each dictation so the next one doesn't run on.

### 4.4 Pasting

- The text goes on the clipboard, Murmur presses Command-V, and 0.6 seconds later puts back what was on the clipboard before (unless something new was copied in the meantime).
- The text is marked so clipboard managers don't keep it.
- Without Accessibility, the text is left on the clipboard and the pill says "Copied. Press ⌘V to paste."

## 5. The pill

- A black capsule at the bottom middle of the screen, above the Dock.
- Listening: a red dot and 12 white bars that move with your voice.
- Writing: a small spinner and "Writing" (or "Getting the speech model ready").
- Messages show for a few seconds: "Cancelled", "Didn't catch that.", "Copied. Press ⌘V to paste.", "Murmur is ready. Double-tap Fn to talk.", and problems with the microphone or model.
- It never takes focus from the app you're typing in and ignores clicks.

## 6. The menu bar

### 6.1 The icon

The app icon (in Applications and on the iPhone) is the Murmur logo: a wave of starlings at dusk. In the menu bar: a wave when ready; a filled circle with a wave while listening; three dots while writing; a down arrow while the model gets ready; a warning triangle if the model failed to load.

### 6.2 Recent dictations

The last 20 dictations are kept, newest first; the menu shows 10. Clicking one copies it. Nothing is lost if a paste lands in the wrong place.

### 6.3 What's in the menu

1. A status line ("Ready. Double-tap Fn to talk.")
2. Start or Stop dictation
3. Warnings, only when something needs setting up (see 7)
4. Recent (click one to copy it)
5. Edit word list…
6. Tidy speech (drops um and er), British spelling, Sounds, Open at login: each with a tick
7. Quit Murmur

## 7. Setting up

### 7.1 Microphone

Asked for on first launch. Until it is allowed, the menu shows "⚠️ Allow the microphone…".

### 7.2 Accessibility

Needed to see the Fn key and to press Command-V. macOS asks on first launch; Murmur checks every 1.5 seconds and says "Murmur is ready" in the pill once it's allowed. Until then the menu shows "⚠️ Allow Accessibility (for Fn and pasting)…". If Accessibility is on but the keyboard still can't be watched, Murmur also asks for Input Monitoring.

### 7.3 The Fn key setting

macOS opens the emoji picker on Fn unless System Settings > Keyboard > "Press 🌐 key to" is set to "Do Nothing". Until it is, the menu shows "⚠️ Set “Press 🌐 key to” to Do Nothing…", which opens Keyboard settings.

### 7.4 Open at login

The first time Murmur runs from Applications, it turns on Open at Login. After that the tick in the menu is up to you.

## 8. Privacy

- Audio stays in memory and is never saved to disk or sent anywhere.
- The internet is used only to download the speech models.
- Recent dictations are kept in Murmur's settings on this Mac only.
- Murmur's log (in the Mac's system log) holds Fn timings, modifier key codes and what Murmur did, such as "Wrote 84 characters". Never the words, and never ordinary typed keys.
- On iPhone the same holds: audio stays in memory, and the internet is only used to download the model. The last dictation's text waits in the app and keyboard's shared folder until the next one, so the keyboard can type it. Recent dictations and the word list stay in the app on the phone.

## 9. On iPhone

Two parts: the Murmur app, which listens and writes, and the Murmur keyboard, which types the text into any app. iOS doesn't let a keyboard use the microphone, so the keyboard asks the app to. The speech model, tidying, British spelling and word list rules are the same as on the Mac (3, 4.1 to 4.3). Installed from the Mac with Jude's developer account, not the App Store.

### 9.1 The Murmur app

- One screen, from the top:
  - A status line: "Getting the speech model ready (42%). After an update this takes a few minutes. Keep Murmur open until it says Ready.", "Ready", or "Keyboard on. Turns off 10 minutes after your last dictation." with a "Turn off now" button.
  - A big Talk button: tap to start, tap to stop. The text shows underneath and is copied, ready to paste anywhere. If no keyboard session was on, the microphone goes off again once the text is written.
  - Recent: the last 10 dictations. Tap one to copy it.
  - Tidy speech (drops um and er) and British spelling, both on to start with.
  - Word list: the same rules as 4.2, edited in a text box in the app. Changes work from the next dictation.
  - Setting up the keyboard: the steps in 9.5, with a button that opens Murmur's page in Settings.
- The first time it opens, the speech model downloads (about 400 MB, best on Wi-Fi), then gets ready for the iPhone's chip. That takes a few minutes, and again after every update, because iOS throws away the prepared copy when the app is reinstalled. It only finishes while the app is open, so keep it on screen until it says Ready. After that it is ready in under a second each time the app opens.

### 9.2 The Murmur keyboard

- Switch to it with 🌐 in any app. Tap 🌐 again to go back to Apple's keyboard to type letters.
- From the top: a status line, a big round Talk button, then a row with space, delete (hold to repeat) and return. A 🌐 key is added on iPhones that don't show their own below the keyboard.
- What it says:
  - No session: "Tap to turn Murmur on".
  - Ready: "Tap to talk". While the model is still getting ready: "The speech model is getting ready. Open Murmur and keep it on screen until it says Ready." Talking still works; the text comes once the model is ready.
  - Listening: a red Stop button, "Listening. Tap to stop.", and ✕ to throw the recording away.
  - Writing: a spinner and "Writing", or "Writing once the speech model is ready. Open Murmur and keep it on screen."
  - For a few seconds after a dictation: "Didn't catch that." or what went wrong.
  - Without Full Access: "Murmur needs Full Access: open the Murmur app and follow Setting up."

### 9.3 Keyboard sessions

- A session means Murmur's microphone is on, so Talk works straight from the keyboard. iOS shows the orange dot at the top of the screen while it's on.
- Starting one: tap Talk when there's no session. The Murmur app opens, turns the microphone on and says "Murmur is on. Tap ◀ at the top left to go back." Back in your app, tap Talk.
- Sound heard during a session is thrown away straight away, unless Talk was tapped.
- It ends by itself 10 minutes after the last dictation, never in the middle of one. "Turn off now" in the app ends it straight away. A phone call, or anything else that takes the microphone, also ends it; a dictation in progress is written out first.
- If the microphone stops without warning, the app starts it again within 2 seconds, or ends the session so the keyboard knows.
- iOS can close the app in the background (more likely in Low Power Mode). The keyboard notices within 6 seconds and goes back to "Tap to turn Murmur on".
- Music and podcasts keep playing during a session, so they can end up in a dictation.

### 9.4 Talking from the keyboard

- Tap Talk to start and tap again to stop; the text is typed where the cursor is. ✕ throws the recording away.
- A space goes after the text, and before it too if it would otherwise join the word or punctuation in front. No space after an opening bracket or quote, @, # or /.
- Only the keyboard that started a dictation types it, once. If the keyboard closes before the text is ready, the text isn't typed anywhere; it's in Recent in the app.
- If the keyboard closes while listening, Murmur keeps listening. The next time the keyboard opens it shows Listening; tap Stop and the text is typed there.
- A recording stops by itself after 15 minutes and is written out as usual.

### 9.5 Setting up on iPhone

1. Claude installs Murmur from the Mac with `./scripts/install-phone.sh`, with the iPhone plugged in or on the same Wi-Fi.
2. Open Murmur, allow the microphone, and wait for "Ready".
3. In the app, tap "Open Settings", then Keyboards, and turn on Murmur and Allow Full Access. Full Access lets the keyboard and app share two small files; Murmur's keyboard sends nothing online.

### 9.6 The phone's trace

The app and the keyboard each keep a list of their last 200 events with times ("sent start", "typed 84 characters"), never the words. It lives in their shared folder on the phone, so Claude can read it from the Mac when something goes wrong.

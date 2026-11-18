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

### 2.5 Hold Fn to talk

- As well as double tap: hold Fn on its own for half a second and Murmur starts listening; let go and the text is written.
- Pressing any other key while holding (Fn+arrow, Fn+F5) throws the recording away, so Fn still works as a modifier.
- A hold while a double-tap dictation is running does nothing; double tap again to finish that one.
- "Hold Fn to talk" in the menu, ticked to start with.

### 2.6 Music down while listening

- While Murmur listens, the Mac's volume drops to a quarter, then goes back once listening stops (or is cancelled).
- If you change the volume while it's down, Murmur leaves your new setting alone. If the sound moves to other speakers or AirPods mid-dictation, the first ones are still put back.
- If Murmur quits or crashes while the volume is down, it puts it back (straight away on quitting, otherwise next time it opens).
- The Tink plays before the volume drops and the Pop after it comes back.
- "Turn music down while listening" in the menu, ticked to start with. Mac only: iOS doesn't let Murmur change other apps' sound.

### 2.7 Command Mode

- Hold Fn and Control together (either first, within half a second of each other) for half a second, say what you want, let go. Control pressed later, during an ordinary Fn hold, throws that dictation away (2.5). Needs Apple Intelligence, which runs on the Mac, free and offline. On iPhone: the keyboard's ✨ button (9.7).
- With text selected: it is rewritten as asked ("make this friendlier", "turn this into bullet points", "shorter") and the new text replaces it.
- With nothing selected: Murmur writes what you asked for ("write a polite no thanks") where the cursor is.
- The pill shows the bars while listening, then "Thinking". The reply gets British spelling and the word list; it is added to Recent.
- Escape or another key while holding throws it away. If Apple Intelligence is off, the pill says how to turn it on. Too much text, a request the model won't do, or no answer within 20 seconds gets a short message instead. If the instruction itself couldn't be heard, the pill says to try again (it isn't kept for "Try the last recording again").
- Replies are asked to be short and plain. Short placeholder lines the model adds anyway ("Dear [Name],", "[Your Name]") are taken out.
- New text written where nothing was selected gets a space after it, like a dictation. British spelling in the reply only when British spelling is ticked.
- The selected text is read after the keys are let go, through Accessibility (giving a busy app a quarter of a second); apps that don't share it get a quick Command-C, waiting up to half a second, with the clipboard put back if it changed. An app that says nothing is selected is believed.
- "Command Mode: hold Fn and Control" in Settings, ticked to start with.

### 2.8 Paste again

- Control-Command-V pastes the last dictation again, wherever the cursor is now, for when it landed in the wrong place. Also "Paste last dictation again" in the menu.
- Murmur keeps that shortcut for itself; the app in front doesn't see it. It waits for the keys to be let go before pasting.
- On iPhone: the keyboard's "again" key (9.4).

### 2.9 Type as I speak

- "Type as I speak (turns AI tidy-up off)" in Settings, unticked to start with (from 17 Nov 2026; ticked before). Ticking it unticks AI tidy-up (4.11), which needs the whole dictation. The words appear where the cursor is while you talk, a second or two behind you, instead of all at once at the end. For double tap and hold Fn; Command Mode still answers at the end.
- About once a second Murmur reads the whole recording so far again with the same speech model, so what's typed is as accurate as reading it all at the end. A new word is typed once two readings in a row agree on it (if none agree for 8 seconds, the ones said more than 2 seconds ago are typed anyway). When a later reading is better, Murmur corrects what it has typed: it deletes back to the first difference and types the rest again.
- Punctuation on the very last word isn't typed until more is said: the model guesses a full stop at any pause. It appears with the next word, or when you stop.
- Only the last 250 characters or so are ever corrected; older words stay as they are. A comma, once typed, stays until the last reading (which can change the last 250 characters or so), as commas come and go between readings.
- If you click or press a key while listening, or another app comes to the front, the cursor may have moved, so nothing typed so far is deleted or corrected from then on. New words still appear at the cursor. If a change would need something already typed to be deleted, typing stops and the whole dictation is copied.
- Everything in 4 still happens to what's typed: British spelling, the word list, snippets, "new line", spoken punctuation, casual style. When a later word changes how the end should look (a snippet, a two-word fix, "question mark", casual style's full stop), Murmur deletes the last few characters and types them again.
- When you stop, the whole recording is read once more, what's typed is made to match (the last 250 characters or so), a space goes after it, and "press enter" presses Return.
- The "no wait, I mean" fix (4.8) isn't used while this is on: those words are already typed.
- Escape stops listening and leaves what's already typed. The pill says "Stopped. What's typed stays." (or "Cancelled" if nothing was typed yet).
- Murmur types with key presses rather than the clipboard. Text with a line break in it is pasted instead, since a typed line break would send a message; the clipboard is put back once, at the end. While Fn is held (Hold Fn to talk), a correction that needs deleting waits until Fn is let go, since Fn and Delete deletes forwards, and so does what comes after it.
- If it would ever need to delete more than 300 characters (the cursor was moved, say), it stops typing: the whole dictation is copied and the pill says "Typing stopped part way. The whole dictation is copied."
- If the last reading fails twice, the pill says "Couldn't write the last few words."
- Needs the speech model ready and Accessibility; otherwise the dictation is pasted at the end as before. Words go wherever the cursor is, so don't click elsewhere while talking.

### 2.10 Pause

- While listening after a double tap, a single tap of Fn pauses: the pill says "Paused. Tap Fn to carry on." Nothing said while paused is kept, not even for the model to hear, so you can talk to someone in the room. Another single tap carries on.
- A tap counts as single once the double-tap gap (0.4 seconds) has passed without a second tap, so a pause takes just under half a second to show. A double tap still stops, paused or not.
- A tap straight after the double tap that started listening (a bounce, a third tap) doesn't pause.
- While paused, the menu bar icon is a pause sign and the menu says "Paused. Tap Fn to carry on, double-tap to finish."
- Not during Hold Fn to talk (just let go) or Command Mode. Escape still throws the recording away.

## 3. Speech to text

### 3.1 The models

- Runs on the Mac with NVIDIA's Parakeet model, in the Bark 3.0 versions made by Conway Research. English only.
- Settings, Speech model, one of three:
  - "Tidy (drops um and er)", the one to start with: Bark 3.0 Clean, which leaves out fillers, false starts and repeated words.
  - "Ultra (fewer mistakes, 600 MB download)": Parakeet Ultra, made by Moondream. In FluidAudio's published tests it gets fewer words wrong (3.81% against 4.66%), but it keeps "um", so Murmur takes out "um", "uh", "erm" and "er" itself, with the commas around them ("So, um, I think" to "So I think"). "Ah" and "hmm" stay, as they're often meant. False starts and repeated words aren't dropped by the model; the AI tidy-up (4.11) takes out a word said twice.
  - "Word for word": Bark 3.0, everything as said.
- Each model downloads once (about 400 to 600 MB) to ~/Library/Application Support/FluidAudio/Models. A model that isn't downloaded yet can't be chosen with under 11 GB free; the pill says to free up space first (below 10 GB, macOS removes Apple Intelligence's model).

### 3.2 Getting ready

- The model loads when Murmur opens. The menu shows "Getting the speech model ready" with a percentage while it downloads.
- If you dictate before it's ready, the pill says "Getting the speech model ready" and the text appears once it is.
- If loading fails (no internet on the first run), the menu says so and offers "Try loading the speech model again".

### 3.3 The microphone

- "Microphone" in the menu: Automatic, or one of the Mac's microphones (each with a tick).
- Automatic uses the Mac's own default input. Only if that is the built-in microphone and the lid is shut does it use another one, since the built-in one only hears the keyboard. Software microphones (from Zoom, Teams, BlackHole) are never picked automatically, only by hand.
- A chosen microphone that isn't plugged in, or won't start, falls back to Automatic for that dictation.

### 3.4 Whisper mode

- "Whisper mode (for speaking quietly)" in Settings, off to start with (on iPhone, in the Murmur app's Settings). Quiet recordings are made up to 20 times louder before the model hears them.
- Tested 2 Nov 2026 with the Mac's whispering voice at 2% volume: without it "book" was heard as "put"; with it, every word was right. Normal and merely quiet speech came out the same either way, so it stays off unless you whisper (boosting silence can turn hiss into words).

## 4. The text that's pasted

### 4.1 British spelling

On by default. Turns American spellings into British ones from a fixed list (colour, favourite, realise, centre, travelled, grey, defence). Words spelt the same either way, or that change with meaning (program, license, practice, meter), are left alone. Capitals are kept ("Color" to "Colour"). Can be turned off in the menu.

### 4.2 Word list

- "Word list and snippets…" in the menu opens a window (on iPhone, Word list and Snippets in the Murmur app). Each entry has "Write it as" and, optionally, "When it hears". Leaving "Write it as" empty removes that word ("basically ->" in the file). Entries starting with # or containing an arrow can't be saved, since the file couldn't read them back. Add with the + button; tap or click an entry to change or delete it (on iPhone, swiping left deletes too).
- "Add a fix from a recent dictation": pick a recent dictation, correct it, and Murmur suggests entries from the words you changed (up to four words each). A change in capitals only becomes "always write it like this". Tick the ones to add.
- Behind the window it is still words.txt in ~/Library/Application Support/Murmur: each line a word or name to always spell exactly as typed ("Clocked In"), or a fix in the form `heard -> written` ("wisper flow -> Wispr Flow"). Lines starting with # are notes; saving from the window rewrites the file without old notes.
- Matching ignores capitals, only matches whole words, and a space in the list also matches a hyphen ("clocked-in").
- Longer entries go first. The word list goes after British spelling, so its entries always win.
- Changes work from the next dictation.

### 4.3 Tidying

- Extra spaces and line breaks are squeezed to single spaces.
- A recording of silence (nothing, or only punctuation) pastes nothing; the pill says "Didn't catch that."
- The first letter becomes a capital, unless the first word already has a capital inside it (iPhone).
- A full stop that can't be real goes: one before a small letter ("I haven't. worked"), or after a word no sentence ends on: a, an, the, and, but, or, my, your, our, their ("the. Whole" becomes "the whole"). Abbreviations and initials stay (e.g., a.m., Mr., U.S.), as do full stops before a spoken command.
- Letters the model wrote one at a time are joined: "the N H S" becomes "the NHS". A last "I" is left as the word I ("the N H S I think", "Plan B I think"), and so is a first "I" before two or more letters. Letters next to a hyphen are left alone ("A T-shirt"). This happens after the word list, so an entry for the letters as heard can say what they should be ("a g p -> a GP").
- Two marks side by side become one: "issues., and" becomes "issues, and"; "ums.." becomes "ums."; "done?." becomes "done?". An ellipsis and an abbreviation's own full stop ("etc.,") stay.
- Numbers, by fixed rules, the same every time, with or without the AI tidy-up (added 18 Nov 2026), British style as Jude chose:
  - Money and percentages: "twenty pounds" to "£20", "a hundred pounds" to "£100", "fifty pence" to "50p", "fifteen per cent" (or "15 per cent") to "15%". Not a weight: "five pounds of flour", "I've lost ten pounds" and "it weighs about ten pounds" stay ("spent about twelve thousand pounds" is £12,000), and "pound" on its own ("a twelve pound turkey", "a five pound note") is left as said, as it can be either.
  - Years from 1900 to 2099 after "in", "since", "from", a month or a season: "June twenty twenty-six" to "June 2026", "in nineteen ninety-eight" to "in 1998".
  - Times after "at", "from", "until", "by", "before", "after", "around" or "between": "at seven forty-five" to "at 7:45", "from eleven thirty" to "from 11:30"; "seven pm" to "7 pm", and "at seven am" to "at 7 am" (not the verb: "which one am I" stays).
  - Anything over ten: "thirty two" to "32", "two thousand five hundred" to "2,500", "twenty first" to "21st", "twenty second" to "22nd".
  - One to ten stay as words ("two options", "ten minutes"), as do "a hundred times", "one in a million", "twenty twenty vision", "half three", "quarter past seven" and ranges like "between eleven and twelve". Numbers that need the sentence's sense ("after six" meaning 6 o'clock) are left to the AI tidy-up (4.11).
- A space is added after each dictation so the next one doesn't run on.

### 4.4 Pasting

- With "press enter" at the end (4.6), Return is pressed 0.15 seconds after the paste, and no space is added.

- The text goes on the clipboard, Murmur presses Command-V, and 0.6 seconds later puts back what was on the clipboard before (unless something new was copied in the meantime).
- The text is marked so clipboard managers don't keep it.
- Without Accessibility, the text is left on the clipboard and the pill says "Copied. Press ⌘V to paste."

### 4.5 Snippets

- Say a short phrase and Murmur writes saved text instead: "my email" becomes your email address. Set them up in the Snippets tab of the word list window (iPhone: the Murmur app), with "When you say" and "Write".
- If the whole dictation is the phrase, only the saved text is written, exactly as saved (no capital added, no full stop, line breaks kept).
- Said inside a sentence, the phrase is swapped for the text (whole words, capitals and either kind of apostrophe ignored): "Send it to my email, please." All phrases are found first and then swapped, so one snippet's text is never changed by another.
- Phrases get British spelling, the word list, addresses and numbers too before matching, so "my favorite color" still matches and "eleven plus notes" matches "11 plus notes".
- Snippets come last, after British spelling, the word list and casual style, so their text is never changed.

### 4.6 Spoken commands

- Say "question mark", "exclamation mark" (or "exclamation point"), "full stop", "comma", "colon", "semicolon", or "ellipsis" or "dot dot dot" to get ? ! . , : ; or ... (the speech model throws away repeated words, so "dot dot dot" can get lost; "ellipsis" is safer). Any punctuation the model guessed around those words goes, and the next word gets a capital after ? ! or . Two in a row are both kept ("?!").
- Words about punctuation stay as said: after a, an, the, my, your, our, their, its, big, huge, massive, giant, Oxford, serial, inverted or double ("a question mark over it"), or before cancer, splice, separated, key or button ("colon cancer"). "Do you like this question mark" means the symbol.
- Brackets, quotes and slashes: "open bracket" and "close bracket" (or "closed bracket", "end bracket", "open paren", "open parenthesis") give ( and ); "open square bracket" and "close square bracket" give [ and ]; "open quote" and "close quote" (or "end quote", "unquote", "open speech marks", or "quote ... unquote") give “ and ”; "forward slash" gives /. Opening marks join the word after, closing marks join the word before, and a slash joins both ("and/or"). Commas and full stops the model guessed around them go; punctuation after a closing mark stays ("(if that works)."). After a, an, the, my, your, our, their, its, this or that they're being talked about and stay as said ("you missed a close bracket"), as does "quote unquote" with nothing between. Plurals only close ("close brackets"), so "keep open brackets for now" stays as said. Punctuation you say next to them is kept: "open bracket page two full stop close bracket" gives "(page two.)". A "?", "!" or "." the speech model guessed just before "open bracket" moves to after the closing bracket, and a small word it gave a capital inside loses it: "free tonight? Open bracket. After six. Close bracket." gives "free tonight (after six)?". Not when the brackets hold a whole sentence, and not after "etc." and the like.
- Email and web addresses: "jude at gmail dot com" gives "jude@gmail.com" and "bbc dot co dot uk" gives "bbc.co.uk", in small letters. Only with a known ending (com, co.uk, org, net, io, uk and a few more). An email needs a mail provider (Gmail, Outlook, iCloud, Yahoo, Proton and so on) or the word "email" or "address" just before it, so "have a look at bbc dot co dot uk" is a website. "Me", "us", "home", "the" and the like are never the name ("send it to me at gmail dot com" stays "me at gmail.com"; "the dot com boom" stays).
- Lists (added 18 Nov 2026): start each point with "one", "two", "three" (or "first", "second", "third", "firstly", "number one") and they become a numbered list, one point a line: "My plan: one, buy milk. Two, call Sam." gives "My plan:", then "1. Buy milk." and "2. Call Sam." on lines of their own. A comma before the first point becomes a colon. The points must start at one and go up in order, each at the start of the dictation or after punctuation, with words in each, so "One of them is red" and "one, two, three, go" stay as said. The last point ends with its sentence; anything after it starts a new line.
- Emoji by name (added 18 Nov 2026): say the name and then "emoji": "thumbs up emoji" gives 👍, "heart emoji" ❤️, "laughing emoji" 😂, "party emoji" 🎉, "fire emoji" 🔥, and about 70 more (Emoji.names in SpokenExtras.swift). Without the word "emoji" the words stay ("give it a thumbs up").
- "Literal" (added 18 Nov 2026): say "literal" before a command to write it as words: "literal comma" writes "comma", "literal new line" writes "new line", "literal thumbs up emoji" writes "thumbs up emoji". Only before a command, so "a literal translation" stays as said.
- "New line" starts a new line and "new paragraph" leaves a blank line. Punctuation the model put after the command goes, and the next word gets a capital (not iPhone or eBay).
- Only at the edge of a phrase: with punctuation, or the start or end of the dictation, on one side ("Hello. New line. How are you?"). "A new line of shoes" is written as said. Pausing slightly before and after the command helps the model add that punctuation.
- "Press enter" (or "press return") at the very end of a dictation is not written: Murmur presses Return after the text, to send a message. Said on its own, it just presses Return. On iPhone it types a Return, which sends in apps where Return sends.
- Only the whole words count: "new lines" or "press enter to continue" are written as said.
- "Scratch that" takes out the sentence before it (back to the last full stop, question mark or line break): "Let's meet at three. Scratch that. Let's meet at four." becomes "Let's meet at four." It must stand on its own between punctuation, so "I need to scratch that itch" is written as said. The model sometimes writes a correction with no punctuation at all; then it counts only if the words after it start the sentence again ("Send it to tom no scratch that send it to Sarah" becomes "Send it to Sarah"). Pause briefly before and after it: said straight on, the model sometimes leaves the words out altogether (seen 3 Nov 2026), and nothing happens. With Type as I speak the sentence disappears from the screen. Within one dictation only.

### 4.7 Casual style

Styles for each app on the Mac (added 18 Nov 2026, like Wispr Flow's; before that, casual style was a tick per app):

- The menu shows "Style in Messages: Casual" (or whichever app is in front), with a choice of four:
  - **Normal**: capitals and full stops, tidied by the AI.
  - **Casual (no capital or full stop at the ends)**: for chats ("sounds good to me"). Question and exclamation marks stay.
  - **Very casual (small letters, no full stops)**: casual, and every word in small letters, with full stops inside made commas: "Sounds good. See you at 6." becomes "sounds good, see you at 6".
  - **As said (no AI tidy-up)**: no AI tidy-up and no "no wait" fix, so your words stay as the speech model heard them (for notes). The fixed rules (spoken punctuation, numbers, lists and so on) still apply.
- In Casual and Very casual, "I", words with capitals inside (iPhone, NASA, NHS) and names in the word list keep their capitals.
- Messages and WhatsApp start as Casual; every other app starts as Normal. A casual app ticked before 18 Nov 2026 stays Casual.
- The app in front when listening starts decides.
- iPhone: the "aa" switch on the keyboard turns Casual on or off, and stays as you left it.

### 4.8 Self-corrections

- "Fix “no wait, I mean” (Apple Intelligence)" in Settings, ticked to start with. On iPhone too, in the Murmur app's Settings: there the app does it after writing, usually in the background; if iOS won't let the AI answer then, what you said is typed.
- "Let's meet on Monday, no wait, I mean Tuesday at three" becomes "Let's meet on Tuesday at three."
- The on-device AI is only asked when the dictation has a correction word (no wait, I mean, sorry, actually, scratch that, rather, or "no,"), so other dictations aren't slowed down. It adds about half a second to a second.
- "Actually", "sorry" or "I mean" said for emphasis or politeness isn't a correction ("The flat is actually bigger than I thought" stays as said): an answer that only takes out words like these is ignored, since a real correction takes out the mistake too.
- Its answer is only used if it carefully takes words out: its words are in what you said, in the same order; it ends with the same word (the correction comes last); it keeps every "not", "never" and "n't"; and it keeps "press enter", "new line", "new paragraph" and snippet phrases. Otherwise what you said is kept.
- It gets 3 seconds; if the AI is slower, what you said is kept.
- It happens after British spelling and the word list, and before line breaks, casual style and snippets.
- Not while "Type as I speak" is on (2.9).

### 4.9 Emails

- "Lay out emails" in Settings, ticked to start with. Mac only.
- In a mail app (Mail, Outlook, Spark, Superhuman, Airmail, MailMate, Mimestream, Proton Mail) or a browser showing Gmail, Outlook, Proton Mail, Yahoo Mail, iCloud Mail or Fastmail (from the window's title), the greeting and the sign-off get their own lines:
  "Hi Sam. Thanks for the report. Best, Jude." becomes "Hi Sam,", a blank line, "Thanks for the report.", a blank line, "Best," and "Jude" on the line below.
- The greeting: at the very start, "Hi", "Hello", "Hey", "Dear", "Good morning" and so on, then up to three names (or "everyone", "all", "team"), then a comma and a blank line. A greeting on its own leaves the cursor ready for the message.
- The sign-off: the last sentence, "Thanks", "Cheers", "Best", "Kind regards" and so on, with a name after it; "Kind regards", "Best wishes", "Regards", "Yours sincerely" and the like work without a name.
- Only line breaks and the punctuation next to them change, never the words. "Thanks." at the end of a message with no name stays where it is. Say "new paragraph" between paragraphs.
- Decided when listening starts, from the app in front then. A browser's window title is read in the background just after, as a busy browser can be slow to answer.
- "I" is never taken for a name: "Hi, I wanted to ask" lays out as a greeting; "Hi I wanted to ask", with no comma, is left as it is.

### 4.10 Other people's voices

- "Ignore quieter voices (people nearby)" in Settings, ticked to start with. Mac only.
- Someone across the room sounds much quieter than you at the Mac. A sentence about 10 decibels quieter than your own speech (under 0.3 of its loudness) is left out. A sentence ends at a full stop, question mark or exclamation mark, or a pause of over a second.
- Your own speech is measured from the loudest words in the dictation, so a long chat across the room doesn't count as you. A dictation with only one sentence is never cut.
- It doesn't catch what you say to someone else yourself: for that, tap Fn to pause (2.10).
- Tested 3 Nov 2026 with a second voice in the middle of a dictation: at a third of the loudness or less it was left out (the model itself also misses much of a quiet voice); at 60% it was kept.
- Each word's loudness is its loudest moment, so short words before a pause aren't taken for someone else. With Whisper mode on, loudness is measured as heard, before the boost.
- Letting Apple Intelligence decide what was side chat was tried on 3 Nov 2026 and left out: on 10 made-up dictations, twice each, it removed side chat cleanly only 4 times in 10, and changed real text in 3 of the 10 without side chat.
- With Type as I speak, a quiet sentence isn't typed; if a louder one comes later and shows an earlier sentence was someone else's, that earlier sentence is taken off the screen.

### 4.11 AI tidy-up

- "AI tidy-up (Apple Intelligence)" in Settings, ticked to start with. Mac only for now.
- After the speech model, Apple's on-device AI adds the punctuation, capitals and apostrophes the model left out and fixes small slips: "hey are you free tonight I was going to cook dinner" becomes "Hey, are you free tonight? I was going to cook dinner." Lists get commas, "dont" becomes "don't", a word said twice by mistake goes, and a word that was clearly misheard can be put right.
- Numbers are written as a careful British writer would, judged from the sentence (Jude's choice, 17 Nov 2026), on top of the fixed rules in 4.3, which run before it and again on its answer: digits for times, dates, money, measurements, percentages, phone numbers and anything over ten ("after 6", "3:30", "21 March", "£50", "5 km", "20%"); words for one to ten in ordinary sentences ("two options", "one of them"); spoken times like "half three" left as words. Tested 17 Nov 2026 on 12 examples: right in 10. It sometimes writes a small number as digits ("5 years") or leaves a percentage as words ("fifteen per cent"); a phone number said digit by digit is left as said.
- It runs on the Mac, free and offline, like the rest of Murmur. It needs Apple Intelligence on (System Settings, Apple Intelligence & Siri) and macOS 27's model (tested 17 Nov 2026).
- It never answers or obeys what you said: "What is the capital of France?" is written as said.
- Its answer is only used if it just tidied:
  - Out of every eight words, at most one taken out and one put in (at least one either way), so it can't drop a sentence or reword.
  - A word added on top only if it's a small one grammar needs (a, an, the, to, of and so on), and any other new word only in place of one taken out, so "done by 4" can't become "done by 4 pm".
  - Every "not", "never" and "n't" kept, and every number: written as words or digits, the digits must be the same and in the same order, so "six" can become "6" and "three thirty" "3:30", but "six" can't become "7" and "three thirty" can't become "half three". "Pounds" and "percent" may become £ and %, and "the" and "of" may go from a date ("the fourth of November" to "4 November").
  - "New line", "new paragraph", snippet phrases and the word list's spellings kept as they are, and no line breaks added.
  Otherwise the text is pasted as it was, with the fixed rules (4.3, 4.6) only.
- It happens after spoken punctuation, brackets and "scratch that", and before line breaks, emails, casual style and snippets. Its answer gets British spelling and the word list again, so your words always win.
- It takes under a second for a sentence or two (0.7 seconds on average in testing), longer for long dictations. The AI is woken when you start talking, so it's ready when you stop. It gets 4 seconds plus a second for every 40 words, up to 8 (a short one now and then took 2.5 seconds or more); if it's slower, the text is pasted as it was. Dictations of under three words or over 500 aren't sent to it (the fixed rules have already written any number in a short one: "Twenty pounds." becomes "£20.").
- It needs the whole dictation, so it isn't used with "Type as I speak" (2.9): ticking one unticks the other. If both were ticked before this setting existed, AI tidy-up wins.
- The pill says "Writing" while it works.
- If Apple's model isn't there (Apple Intelligence off, or still downloading after a macOS update), the text is pasted without it and the menu item reads "AI tidy-up (waiting for Apple Intelligence)". Seen twice on 17 Nov 2026, just after the macOS 27 update.

### 4.12 Text before the cursor

- When listening starts, Murmur reads up to 300 characters just before the cursor in the app in front, as Wispr Flow does (Mac only). It's never logged or saved, and isn't read in Command Mode.
- In the middle of a sentence (after a word, a number, a comma, a semicolon, a dash or an opening bracket), the dictation goes in with a space in front, and the first word loses the capital the speech model gave it: "I'll call you" then "and then we can talk" gives "I'll call you and then we can talk.", and "milk, eggs," then "bread" gives "milk, eggs, bread". Names (spotted by Apple's NaturalLanguage, on the Mac), days, months, "I", words like "NHS" or "iPhone", and words the word list or the text before writes with a capital keep theirs. After a full stop, a line break or nothing, it starts as usual.
- The AI tidy-up (4.11) sees the text too, only to spell names the same way and to continue the sentence. Apple's model sometimes starts its answer by repeating that text (3 times in 8 when tried, 18 Nov 2026); those words are taken off, and the rest is checked as usual.
- With Type as I speak (2.9) the same happens, once the text before has been read (a fraction of a second).
- Some apps don't say what's before the cursor (some web pages and chat apps); then the dictation goes in as before.

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

1. A status line ("Ready. Double-tap or hold Fn to talk.")
2. Start or Stop dictation
3. Warnings, only when something needs setting up (see 7)
4. Recent (click one to copy it), Paste last dictation again (⌃⌘V), Word list and snippets…
5. Style in (the app in front): Normal, Casual, Very casual or As said (4.7)
6. Microphone (3.3)
7. Settings: AI tidy-up (Apple Intelligence), Type as I speak (turns AI tidy-up off), Lay out emails, Ignore quieter voices (people nearby), Speech model (Tidy, Ultra or Word for word, 3.1), British spelling, Fix “no wait, I mean” (Apple Intelligence), Whisper mode (for speaking quietly), Hold Fn to talk, Command Mode: hold Fn and Control, Turn music down while listening, Sounds, Open at login: each with a tick (the speech model as a list with one ticked)
8. Quit Murmur

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
- On iPhone the same holds: audio stays in memory, and the internet is only used to download the model. The last dictation's text is kept in the app and keyboard's shared folder until the next one, so the keyboard can type it (and type it again). Command Mode's selected text goes through that folder too, and only Apple Intelligence on the phone sees it. Recent dictations and the word list stay in the app on the phone.

## 9. On iPhone

Two parts: the Murmur app, which listens and writes, and the Murmur keyboard, which types the text into any app. iOS doesn't let a keyboard use the microphone, so the keyboard asks the app to. The speech model, tidying, British spelling and word list rules are the same as on the Mac (3, 4.1 to 4.3). Installed from the Mac with Jude's developer account, not the App Store.

### 9.1 The Murmur app

- One screen, from the top:
  - A status line: "Getting the speech model ready (42%). After an update this takes a few minutes. Keep Murmur open until it says Ready.", "Ready", or "Keyboard on. Turns off 10 minutes after your last dictation." with a "Turn off now" button.
  - A big Talk button: tap to start, tap to stop. The text shows underneath and is copied, ready to paste anywhere. If no keyboard session was on, the microphone goes off again once the text is written.
  - Recent: the last 10 dictations. Tap one to copy it.
  - Tidy speech (drops um and er) and British spelling, both on to start with. Fix “no wait, I mean” (Apple Intelligence), on to start with (4.8), and Whisper mode (for speaking quietly), off to start with (3.4).
  - Word list and snippets: the same screen as the Mac's window (4.2 and 4.5). Changes work from the next dictation.
  - Setting up the keyboard: the steps in 9.5, with a button that opens Murmur's page in Settings.
- The first time it opens, the speech model downloads (about 400 MB, best on Wi-Fi), then gets ready for the iPhone's chip. That takes one to a few minutes, and again after every update, because iOS throws away the prepared copy when the app is reinstalled. After that it is ready in under a second each time the app opens.
- While it gets ready, a "Getting Murmur ready" card at the top shows a spinner and a timer, says to keep the screen open, and (when the keyboard opened the app) to tap ◀ once it says Ready. The screen stays awake by itself until then.

### 9.2 The Murmur keyboard

- Switch to it with 🌐 in any app. Tap 🌐 again to go back to Apple's keyboard to type letters.
- Laid out like Wispr Flow's keyboard. Along the top, a bar: the "Aa" casual switch on the left (4.7), a status line, a grey "turn mic off" button (a crossed-out mic, only while a session is on and nothing is being said or written), a ✨ button for Command Mode (9.7; only when Apple Intelligence is on and a dictation could start), and a blue mic button on the right. Below, keys like the iPhone's own number keys: 1 to 0; - / : ; ( ) £ & @ "; undo, . , ? ! ' and delete (hold to repeat); then "again", space and return. A 🌐 key is added on iPhones that don't show their own below the keyboard. Keys give a light tap you can feel.
- The top bar:
  - No session: "Tap the mic to turn Murmur on", and the mic button says Start.
  - Ready: "Tap the mic to talk". While the model is still getting ready: "The speech model is getting ready. Open Murmur and keep it on screen until it says Ready." Talking still works; the text comes once the model is ready.
  - Listening: ✕ on the left to throw the recording away, red bars that move with your voice, and ✓ on the right to finish.
  - Writing: a spinner and "Writing", or "Writing once the speech model is ready. Open Murmur and keep it on screen."
  - For a few seconds after a dictation: "Didn't catch that." or what went wrong. After tapping "Aa": what casual style does.
  - Without Full Access: "Murmur needs Full Access: open the Murmur app and follow Setting up."

### 9.3 Keyboard sessions

- A session means Murmur's microphone is on, so Talk works straight from the keyboard. iOS shows the orange dot at the top of the screen while it's on.
- Starting one: tap the mic (it says Start) when there's no session. The Murmur app opens, turns the microphone on and says "Murmur is on. Tap ◀ at the top left to go back." Back in your app, tap the mic.
- Sound heard during a session is thrown away straight away, unless Talk was tapped.
- It ends by itself 10 minutes after the last dictation, never in the middle of one. The keyboard's "turn mic off" button, or "Turn off now" in the app, ends it straight away; the keyboard then says "Microphone off. Tap the mic to turn Murmur on again." A phone call, or anything else that takes the microphone, also ends it; a dictation in progress is written out first.
- If the microphone stops without warning, the app starts it again within 2 seconds, or ends the session so the keyboard knows.
- iOS can close the app in the background (more likely in Low Power Mode). The keyboard notices within 6 seconds and goes back to "Tap the mic to turn Murmur on".
- Music and podcasts keep playing during a session, so they can end up in a dictation.

### 9.4 Talking from the keyboard

- Tap the mic to start and ✓ to finish; the text is typed where the cursor is. ✕ throws the recording away.
- Undo takes the last dictation back out, as long as the cursor is still straight after it; otherwise it says "Nothing to undo." After Command Mode it also puts back the text that was selected.
- "Again" types the last dictation again where the cursor is now (with the same spacing as a dictation), for when it landed in the wrong place; "Nothing to type yet." if there's none. Undo can take it back out.
- Snippets, "new line", "new paragraph" and casual style work as on the Mac (4.5 to 4.7). "Press enter" at the end types a Return after the text, which sends in apps where Return sends; that dictation can't be undone.
- A space goes after the text, and before it too if it would otherwise join the word or punctuation in front. No space after an opening bracket or quote, @, # or /.
- Only the keyboard that started a dictation types it, once. If the keyboard closes before the text is ready, the text isn't typed anywhere; it's in Recent in the app.
- If the keyboard closes while listening, Murmur keeps listening. The next time the keyboard opens it shows the moving bars; tap ✓ and the text is typed there.
- A recording stops by itself after 15 minutes and is written out as usual.

### 9.5 Setting up on iPhone

1. Claude installs Murmur from the Mac with `./scripts/install-phone.sh`, with the iPhone plugged in or on the same Wi-Fi.
2. Open Murmur, allow the microphone, and wait for "Ready".
3. In the app, tap "Open Settings", then Keyboards, and turn on Murmur and Allow Full Access. Full Access lets the keyboard and app share two small files; Murmur's keyboard sends nothing online.

### 9.6 The phone's trace

The app and the keyboard each keep a list of their last 200 events with times ("sent start", "typed 84 characters"), never the words. It lives in their shared folder on the phone, so Claude can read it from the Mac when something goes wrong.

### 9.7 Command Mode from the keyboard

- The ✨ button, next to the mic: select some text (or none), tap ✨, say what to do ("make this friendlier", "write a polite no thanks"), tap ✓. ✕ throws it away.
- The Murmur app turns what you said into the instruction and asks Apple Intelligence on the iPhone, with the same prompts, checks and 20 second limit as the Mac (2.7). While it works the keyboard says "Thinking".
- With text selected, the answer is typed in its place exactly as it comes (no spaces added); Undo puts the selected text back. If something else is selected by the time the answer comes (the cursor moved), it isn't typed: the keyboard says so and the answer is in Recent in the app. With nothing selected, the answer is typed like a dictation.
- The selected text is what iOS shares with the keyboard; some apps share none, and then it's treated as nothing selected (the answer is typed over the real selection, and Undo can't bring it back).
- The app is usually in the background while this happens. iOS limits how much a background app may ask Apple Intelligence; if it says no, the keyboard says "Apple Intelligence is busy. Try again in a moment." (On 3 Nov 2026 it answered in the background every time Jude tried.)
- Answers go into Recent in the app, like dictations.

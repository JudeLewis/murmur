import Testing
@testable import MurmurCore

@Suite("4.1 British spelling")
struct BritishSpellingTests {
    @Test func commonWordsBecomeBritish() {
        let text = "I realized my favorite color is gray, so I organized the center."
        #expect(BritishSpelling.apply(to: text) == "I realised my favourite colour is grey, so I organised the centre.")
    }

    @Test func capitalsAreKept() {
        #expect(BritishSpelling.apply(to: "Organization") == "Organisation")
        #expect(BritishSpelling.apply(to: "COLOR") == "COLOUR")
    }

    @Test func wordsThatLookAmericanButAreNotAreLeftAlone() {
        let text = "The size of the prize was humorous and laborious, a vigorous honorary seize."
        #expect(BritishSpelling.apply(to: text) == text)
    }

    @Test func otherForms() {
        #expect(BritishSpelling.apply(to: "traveled") == "travelled")
        #expect(BritishSpelling.apply(to: "canceling") == "cancelling")
        #expect(BritishSpelling.apply(to: "centered") == "centred")
        #expect(BritishSpelling.apply(to: "analyzing") == "analysing")
        #expect(BritishSpelling.apply(to: "neighborhood") == "neighbourhood")
        #expect(BritishSpelling.apply(to: "behavioral") == "behavioural")
        #expect(BritishSpelling.apply(to: "defense") == "defence")
    }

    @Test func wordsInsideOtherWordsAreLeftAlone() {
        #expect(BritishSpelling.apply(to: "colorado") == "colorado")
    }
}

@Suite("4.2 Word list")
struct WordListTests {
    @Test func readsBothKindsOfLineAndSkipsNotes() {
        let entries = WordList.parse("""
            # a note
            Clocked In

              wisper flow -> Wispr Flow
            jude => Jude
            """)
        #expect(entries == [
            WordEntry(heard: "Clocked In", written: "Clocked In"),
            WordEntry(heard: "wisper flow", written: "Wispr Flow"),
            WordEntry(heard: "jude", written: "Jude"),
        ])
    }

    @Test func templateHasOneEntry() {
        #expect(WordList.parse(WordList.template) == [WordEntry(heard: "Clocked In", written: "Clocked In")])
    }

    @Test func fixesCapitalsAndHyphens() {
        let entries = WordList.parse("Clocked In")
        #expect(WordList.apply(entries, to: "I opened clocked in. Then clocked-in again.")
            == "I opened Clocked In. Then Clocked In again.")
    }

    @Test func replacesWhatWasHeard() {
        let entries = WordList.parse("wisper flow -> Wispr Flow")
        #expect(WordList.apply(entries, to: "Better than Wisper Flow.") == "Better than Wispr Flow.")
    }

    @Test func onlyWholeWords() {
        let entries = WordList.parse("Ann")
        #expect(WordList.apply(entries, to: "annual plans with ann") == "annual plans with Ann")
    }

    @Test func longestEntryWins() {
        let entries = WordList.parse("""
            Clocked In
            clocked in app -> Clocked In app
            """)
        #expect(WordList.apply(entries, to: "the clocked in app") == "the Clocked In app")
    }

    @Test func specialCharactersAreSafe() {
        let entries = WordList.parse("c plus plus -> C++\n$5 -> five dollars")
        #expect(WordList.apply(entries, to: "I write c plus plus") == "I write C++")
    }
}

@Suite("4.3 Tidying")
struct TidyTests {
    @Test func trimsAndSqueezesSpaces() {
        #expect(Tidy.finish("  hello   there \n", words: [], british: false) == "Hello there")
    }

    @Test func startsWithACapital() {
        #expect(Tidy.finish("so I realised", words: [], british: false) == "So I realised")
        #expect(Tidy.finish("iPhone notes", words: [], british: false) == "iPhone notes")
    }

    @Test func silenceIsNothing() {
        #expect(Tidy.finish(" . ", words: [], british: true) == "")
        #expect(Tidy.finish("", words: [], british: true) == "")
    }

    @Test func wordListBeatsBritishSpelling() {
        let words = WordList.parse("colour -> Color")
        #expect(Tidy.finish("my color", words: words, british: true) == "My Color")
    }

    @Test func addsATrailingSpaceForTheNextDictation() {
        #expect(Tidy.forInsertion("Hello.") == "Hello. ")
        #expect(Tidy.forInsertion("") == "")
    }
}

@Suite("6.2 Recent dictations")
struct RecentListTests {
    @Test func newestFirstAndCapped() {
        var recent = RecentList(limit: 3)
        for text in ["one", "two", "", "three", "four"] { recent.add(text) }
        #expect(recent.items == ["four", "three", "two"])
    }
}

@Suite("4.6 Spoken commands: punctuation")
struct SpokenPunctuationTests {
    private func written(_ said: String) -> String { Tidy.dictation(said, words: [], british: true).text }

    @Test func eachMarkComesOutAsItsSymbol() {
        #expect(written("Are you coming question mark") == "Are you coming?")
        #expect(written("What a day exclamation mark") == "What a day!")
        #expect(written("What a day exclamation point") == "What a day!")
        #expect(written("We are done full stop") == "We are done.")
        #expect(written("Apples comma pears and plums") == "Apples, pears and plums")
        #expect(written("Bring these colon a pen and paper") == "Bring these: a pen and paper")
        #expect(written("It rained semicolon we stayed in") == "It rained; we stayed in")
        #expect(written("It rained semi colon we stayed in") == "It rained; we stayed in")
        #expect(written("Well dot dot dot maybe") == "Well... maybe")
        #expect(written("Well ellipsis maybe") == "Well... maybe")
        #expect(written("Do you like this question mark") == "Do you like this?")
        #expect(written("I said no full stop") == "I said no.")
    }

    @Test func theModelsOwnGuessesAroundTheWordsGo() {
        #expect(written("Are you coming? Question mark.") == "Are you coming?")
        #expect(written("It works, comma and it's quick.") == "It works, and it's quick.")
        #expect(written("We're done full stop. Can we go?") == "We're done. Can we go?")
        #expect(written("Well, dot, dot, dot.") == "Well...")
        #expect(written("That would be great exclamation, Mark.") == "That would be great!")
    }

    @Test func aNewSentenceGetsACapital() {
        #expect(written("We're done full stop can we go") == "We're done. Can we go")
        #expect(written("Are you in question mark we are") == "Are you in? We are")
        #expect(written("I got an email full stop iPhone next") == "I got an email. iPhone next")
    }

    @Test func aCapitalTheModelGuessedAfterACommaGoes() {
        #expect(written("I went home comma. And then I slept") == "I went home, and then I slept")
        #expect(written("Hello comma. Sam") == "Hello, Sam")
    }

    @Test func twoInARowAreBothKept() {
        #expect(written("You did what question mark exclamation mark") == "You did what?!")
    }

    @Test func talkingAboutPunctuationStaysAsSaid() {
        #expect(written("There's a question mark over it") == "There's a question mark over it")
        #expect(written("It came to a full stop") == "It came to a full stop")
        #expect(written("Use the Oxford comma here") == "Use the Oxford comma here")
        #expect(written("That's a big question mark") == "That's a big question mark")
        #expect(written("It tests for colon cancer") == "It tests for colon cancer")
        #expect(written("The commando stood still") == "The commando stood still")
        #expect(written("The car park was full. Stop by later") == "The car park was full. Stop by later")
        #expect(written("Good question. Mark is right") == "Good question. Mark is right")
    }

    @Test func worksWithTheOtherSpokenCommands() {
        let sent = Tidy.dictation("Are you in question mark press enter", words: [], british: true)
        #expect(sent.text == "Are you in?")
        #expect(sent.pressEnter)
        #expect(written("Hello comma new line how are you question mark") == "Hello,\nHow are you?")
    }
}

@Suite("4.3 Tidying: stray full stops")
struct StrayStopsTests {
    @Test func aFullStopBeforeASmallLetterGoes() {
        #expect(StrayStops.remove(from: "I just haven't. worked yet.") == "I just haven't worked yet.")
        #expect(StrayStops.remove(from: "It covers the. clock as well.") == "It covers the clock as well.")
    }

    @Test func aFullStopAfterAWordNoSentenceEndsOnGoes() {
        #expect(StrayStops.remove(from: "Because the. Whole thing moved.") == "Because the whole thing moved.")
        #expect(StrayStops.remove(from: "Salt and. I like pepper.") == "Salt and I like pepper.")
    }

    @Test func aNameFromTheWordListKeepsItsCapital() {
        let names = [WordEntry(heard: "sam", written: "Sam")]
        #expect(StrayStops.remove(from: "Salt and. Sam likes it.", keeping: names) == "Salt and Sam likes it.")
    }

    @Test func realSentencesStay() {
        #expect(StrayStops.remove(from: "That was fun. We should go.") == "That was fun. We should go.")
        #expect(StrayStops.remove(from: "Plan A. Then plan B.") == "Plan A. Then plan B.")
    }

    @Test func abbreviationsAndTheLikeStay() {
        for text in ["Fruit, e.g. apples", "At 9 a.m. on Monday", "Pens, etc. and so on", "Ask Mr. smith", "Wait... what", "See google.com for more", "It went. iPhone next"] {
            #expect(StrayStops.remove(from: text) == text)
        }
    }

    @Test func aFullStopInFrontOfASpokenCommandStays() {
        #expect(Tidy.dictation("Hi Sam. new line. See you.", words: [], british: true).text == "Hi Sam.\nSee you.")
    }

    @Test func aFullStopYouSaidIsKept() {
        #expect(Tidy.dictation("Bread and full stop then milk", words: [], british: true).text == "Bread and. Then milk")
    }
}

@Suite("4.6 Spoken commands: brackets, quotes and slashes")
struct SpokenSymbolsTests {
    private func written(_ said: String) -> String { Tidy.dictation(said, words: [], british: true).text }

    @Test func bracketsJoinTheWordsInside() {
        #expect(written("The meeting is on Tuesday open bracket if that works close bracket and then we talk")
            == "The meeting is on Tuesday (if that works) and then we talk")
        #expect(written("It's cheap open square bracket citation needed close square bracket") == "It's cheap [citation needed]")
        #expect(written("See the notes open parenthesis page two close parenthesis.") == "See the notes (page two).")
    }

    @Test func theModelsGuessesAroundBracketsGo() {
        #expect(written("On Tuesday, open bracket, if that works, close bracket, we talk.") == "On Tuesday (if that works), we talk.")
        #expect(written("On Tuesday open bracket if that works. Closed bracket.") == "On Tuesday (if that works).")
    }

    @Test func quotesAndSlashes() {
        #expect(written("She said open quote hello close quote to me") == "She said \u{201C}hello\u{201D} to me")
        #expect(written("He called it quote the plan unquote") == "He called it \u{201C}the plan\u{201D}")
        #expect(written("He called it, quote, the plan, unquote.") == "He called it \u{201C}the plan\u{201D}.")
        #expect(written("She said open quote hello comma close quote and left") == "She said \u{201C}hello,\u{201D} and left")
        #expect(written("It's either and forward slash or") == "It's either and/or")
    }

    @Test func talkingAboutThemStaysAsSaid() {
        #expect(written("You missed a close bracket here") == "You missed a close bracket here")
        #expect(written("It was, quote unquote, fine") == "It was, quote unquote, fine")
        #expect(written("The open brackets policy") == "The open brackets policy")
        #expect(written("It was, quote, unquote, fine") == "It was, quote, unquote, fine")
        #expect(written("Keep open brackets for now") == "Keep open brackets for now")
        #expect(written("We need to start quotes for new clients") == "We need to start quotes for new clients")
    }

    @Test func aGuessedSentenceEndMovesAfterTheBracket() {
        #expect(written("Hey, are you free tonight? Open bracket. After six. Close bracket. I was going to cook.")
            == "Hey, are you free tonight (after six)? I was going to cook.")
        #expect(written("We met on Monday. Open bracket, the third, close bracket, and talked.")
            == "We met on Monday (the third), and talked.")
        #expect(written("Ask Tom. Open bracket. Sarah knows. Close bracket.") == "Ask Tom (Sarah knows).")
        #expect(written("I went home. Open bracket it was late. Close bracket.") == "I went home (it was late).")
        #expect(written("Pens etc. Open bracket blue ones close bracket") == "Pens etc. (blue ones)")
        #expect(written("Is it ready? Open bracket after six.") == "Is it ready? (after six.")
        #expect(written("Is it ready? Open bracket. About 3.5 hours. Close bracket.") == "Is it ready (about 3.5 hours)?")
        #expect(written("Ready? Open bracket he said open quote soon close quote close bracket")
            == "Ready (he said \u{201C}soon\u{201D})?")
    }

    @Test func saidPunctuationNextToABracketStays() {
        #expect(written("See open bracket page two full stop close bracket") == "See (page two.)")
        #expect(written("Note colon open bracket see below close bracket") == "Note: (see below)")
    }
}

@Suite("4.3 Tidying: spelt-out letters and doubled marks")
struct SpeltLettersTests {
    @Test func lettersSaidOneByOneAreJoined() {
        #expect(SpeltLetters.join("What the N H S has done") == "What the NHS has done")
        #expect(SpeltLetters.join("Ask the B B C. Then go") == "Ask the BBC. Then go")
        #expect(SpeltLetters.join("The N H S I think") == "The NHS I think")
        #expect(SpeltLetters.join("Plan A. Then plan B.") == "Plan A. Then plan B.")
        #expect(SpeltLetters.join("Use the U.S. one") == "Use the U.S. one")
        #expect(SpeltLetters.join("Plan B I think") == "Plan B I think")
        #expect(SpeltLetters.join("A T-shirt is fine") == "A T-shirt is fine")
    }

    @Test func aWordListEntryCanFixTheLettersAsHeard() {
        let words = [WordEntry(heard: "a g p", written: "a GP")]
        #expect(Tidy.finish("They fund the A G P appointment", words: words, british: true) == "They fund the a GP appointment")
    }

    @Test func doubledMarksBecomeOne() {
        #expect(DoubledMarks.remove(from: "consistency issues., and the app") == "consistency issues, and the app")
        #expect(DoubledMarks.remove(from: "take out the ums.. fix it") == "take out the ums. fix it")
        #expect(DoubledMarks.remove(from: "Is it done?.") == "Is it done?")
        #expect(DoubledMarks.remove(from: "Hello,.") == "Hello.")
        #expect(DoubledMarks.remove(from: "Hello,. and then we go") == "Hello, and then we go")
        #expect(DoubledMarks.remove(from: "The answer was no., and we left") == "The answer was no, and we left")
    }

    @Test func ellipsesAndAbbreviationsStay() {
        for text in ["Well... maybe", "Pens, etc., and so on", "Fruit, e.g., apples", "Wait...", "Hmm..., fine"] {
            #expect(DoubledMarks.remove(from: text) == text)
        }
    }
}

@Suite("4.3 Tidying: numbers")
struct WrittenNumbersTests {
    private func written(_ said: String) -> String { WrittenNumbers.apply(to: said) }

    @Test func moneyAndPercentages() {
        #expect(written("Twenty pounds.") == "£20.")
        #expect(written("It costs two hundred and fifty pounds a month") == "It costs £250 a month")
        #expect(written("It costs a hundred pounds") == "It costs £100")
        #expect(written("About fifty pence each") == "About 50p each")
        #expect(written("We grew by fifteen percent") == "We grew by 15%")
        #expect(written("We grew by fifteen per cent last year") == "We grew by 15% last year")
        #expect(written("Five pounds of flour") == "Five pounds of flour")
        #expect(written("We grew by 15 per cent last year") == "We grew by 15% last year")
        #expect(written("It's 20 pounds each") == "It's £20 each")
        #expect(written("It weighs 5 pounds of sugar") == "It weighs 5 pounds of sugar")
        #expect(written("version 3.5 percent") == "version 3.5 percent")
    }

    @Test func years() {
        #expect(written("I graduated in June twenty twenty-six.") == "I graduated in June 2026.")
        #expect(written("We met in twenty nineteen") == "We met in 2019")
        #expect(written("It was founded in nineteen ninety-eight") == "It was founded in 1998")
        #expect(written("Since two thousand and five") == "Since 2005")
    }

    @Test func timesAfterAt() {
        #expect(written("The train leaves at seven forty-five") == "The train leaves at 7:45")
        #expect(written("See you at three thirty pm") == "See you at 3:30 pm")
        #expect(written("Come at seven pm") == "Come at 7 pm")
    }

    @Test func overTenBecomesDigits() {
        #expect(written("I'm thirty two now") == "I'm 32 now")
        #expect(written("about forty minutes and two hundred staff") == "about 40 minutes and 200 staff")
        #expect(written("two thousand five hundred people") == "2,500 people")
        #expect(written("the twenty first century") == "the 21st century")
        #expect(written("my eleventh birthday") == "my 11th birthday")
    }

    @Test func reviewFixes() {
        #expect(written("I'm free from eleven thirty") == "I'm free from 11:30")
        #expect(written("done by twelve fifteen") == "done by 12:15")
        #expect(written("between eleven and twelve") == "between eleven and twelve")
        #expect(written("the twenty second of March") == "the 22nd of March")
        #expect(written("Which one am I meant to use") == "Which one am I meant to use")
        #expect(written("See you at seven am") == "See you at 7 am")
        #expect(written("I've lost ten pounds this month") == "I've lost ten pounds this month")
        #expect(written("a twelve pound turkey") == "a twelve pound turkey")
    }

    @Test func snippetPhrasesWithNumbersStillMatch() {
        let snippets = [Snippet(trigger: "eleven plus notes", text: "See the 11+ folder")]
        #expect(Tidy.dictation("eleven plus notes", words: [], snippets: snippets, british: true).text == "See the 11+ folder")
    }

    @Test func oneToTenAndSayingsStayAsWords() {
        for text in ["There are two options and one of them is cheaper", "Ten minutes.", "one in a million",
                     "a hundred times better", "after six", "twenty twenty vision", "quarter past seven", "half three",
                     "someone", "often", "a second", "two three bedroom flats"] {
            #expect(written(text) == text)
        }
    }
}

@Suite("4.6 Spoken commands: email and web addresses")
struct SpokenAddressesTests {
    private func written(_ said: String) -> String { Tidy.dictation(said, words: [], british: true).text }

    @Test func addressesAreJoinedUp() {
        #expect(written("Email me at jude at gmail dot com please") == "Email me at jude@gmail.com please")
        #expect(written("My email is jude dot lewis at example dot co dot uk") == "My email is jude.lewis@example.co.uk")
        #expect(written("Have a look at bbc dot co dot uk") == "Have a look at bbc.co.uk")
        #expect(written("Go to Google dot com.") == "Go to google.com.")
        #expect(written("Write to sam at gmail.com") == "Write to sam@gmail.com")
    }

    @Test func ordinaryAtAndDotStay() {
        for said in ["I'll be at home tonight", "The dot com boom", "Put a dot on the map", "Meet me at the station",
                     "Look at the sky dot by dot"] {
            #expect(written(said) == said)
        }
        #expect(written("Send it to me at gmail dot com") == "Send it to me at gmail.com")
        #expect(written("My work email is jude at acme dot com") == "My work email is jude@acme.com")
    }
}

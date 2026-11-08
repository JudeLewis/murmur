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

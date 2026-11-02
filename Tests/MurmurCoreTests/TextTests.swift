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

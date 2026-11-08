import Testing
@testable import MurmurCore

/// A reading where each word takes half a second, starting at `from`.
private func reading(_ text: String, from start: Double = 0) -> [HeardWord] {
    text.split(separator: " ").enumerated().map { index, word in
        HeardWord(String(word), start: start + Double(index) * 0.5, end: start + Double(index) * 0.5 + 0.4)
    }
}

@Suite("2.9 Type as I speak")
struct LiveTypingTests {
    @Test func aWordIsTypedOnceTwoReadingsAgree() {
        var live = LiveTranscript()
        live.heard(reading("Let's meet"), now: 1)
        #expect(live.text == "")
        live.heard(reading("Let's meet on Tues"), now: 2)
        #expect(live.text == "Let's meet")
        live.heard(reading("Let's meet on Tuesday at"), now: 3)
        #expect(live.text == "Let's meet on")
    }

    @Test func aBetterReadingCorrectsWhatIsAlreadyTyped() {
        var live = LiveTranscript()
        live.heard(reading("I scream today"), now: 3)
        live.heard(reading("I scream today"), now: 4)
        #expect(live.text == "I scream today")
        let changed = live.heard(reading("Ice cream today"), now: 5)
        #expect(changed)
        #expect(live.text == "Ice cream today")
    }

    @Test func aCommaComingAndGoingIsLeftUntilTheEnd() {
        // Seen 8 Nov 2026: a comma flipping between readings retyped 100 characters each time.
        var live = LiveTranscript()
        live.heard(reading("Go home and rest now"), now: 4)
        live.heard(reading("Go home and rest now"), now: 5)
        live.heard(reading("Go home, and rest now"), now: 6)
        #expect(live.text == "Go home and rest now")
        live.finished(reading("Go home, and rest now."))
        #expect(live.text == "Go home, and rest now.")
    }

    @Test func aFullStopAtAPauseIsNeverTypedUntilMoreIsSaid() {
        // Seen 8 Nov 2026: a pause in the middle of a sentence left "haven't." on screen.
        var live = LiveTranscript()
        live.heard(reading("I just haven't."), now: 3)
        live.heard(reading("I just haven't."), now: 4)
        #expect(live.text == "I just haven't")
        live.heard(reading("I just haven't worked"), now: 5)
        live.heard(reading("I just haven't worked"), now: 6)
        #expect(live.text == "I just haven't worked")
    }

    @Test func aRealFullStopComesBackWithTheNextWord() {
        var live = LiveTranscript()
        live.heard(reading("That was fun. Next"), now: 3)
        live.heard(reading("That was fun. Next"), now: 4)
        #expect(live.text == "That was fun. Next")
    }

    @Test func stoppingPutsTheLastPunctuationBack() {
        var live = LiveTranscript()
        live.heard(reading("See you at six."), now: 3)
        live.heard(reading("See you at six."), now: 4)
        #expect(live.text == "See you at six")
        live.finished(reading("See you at six."))
        #expect(live.text == "See you at six.")
    }

    @Test func aReadingThatHearsNothingLeavesTheWordsAlone() {
        var live = LiveTranscript()
        live.heard(reading("Hello there"), now: 2)
        live.heard(reading("Hello there"), now: 3)
        let changed = live.heard([], now: 4)
        #expect(!changed)
        #expect(live.text == "Hello there")
    }

    @Test func aReadingThatLosesMostOfTheWordsIsIgnored() {
        var live = LiveTranscript()
        live.heard(reading("one two three four five six"), now: 4)
        live.heard(reading("one two three four five six"), now: 5)
        let changed = live.heard(reading("one"), now: 6)
        #expect(!changed)
        #expect(live.text == "one two three four five six")
    }

    @Test func aClickDuringAPauseKeepsTheHeldBackFullStop() {
        var live = LiveTranscript()
        live.heard(reading("That was fun."), now: 3)
        live.heard(reading("That was fun."), now: 4)
        #expect(live.text == "That was fun")
        live.lockEverything()
        #expect(live.text == "That was fun.")
    }

    @Test func wordsFarBackAreNotCorrected() {
        var live = LiveTranscript()
        let long = Array(repeating: "wordy", count: 80).joined(separator: " ")
        live.heard(reading(long), now: 50)
        live.heard(reading(long), now: 51)
        #expect(live.text == long)
        // The first word changes, but it's too far back; the last one is close enough.
        var changed = reading(long)
        changed[0].text = "Changed"
        changed[79].text = "ending"
        live.heard(changed, now: 52)
        #expect(live.text.hasPrefix("wordy wordy"))
        #expect(live.text.hasSuffix(" ending"))
        #expect(live.words.count == 80)
    }

    @Test func aLockedWordHeardAgainALittleLaterIsNotTypedTwice() {
        // Seen 3 Nov 2026: "My favourite part part was".
        var live = LiveTranscript()
        let first = [HeardWord("My", start: 8.0, end: 8.2), HeardWord("favourite", start: 8.3, end: 8.8), HeardWord("part", start: 9.0, end: 9.4)]
        live.heard(first, now: 10)
        live.heard(first, now: 11)
        live.lockEverything()
        let later = first.dropLast() + [HeardWord("part", start: 9.2, end: 9.7), HeardWord("was", start: 9.8, end: 10.0)]
        live.heard(Array(later), now: 12)
        live.heard(Array(later), now: 13)
        #expect(live.text == "My favourite part was")
    }

    @Test func afterTheCursorMovesWhatIsTypedStays() {
        var live = LiveTranscript()
        live.heard(reading("I scream today"), now: 3)
        live.heard(reading("I scream today"), now: 4)
        live.lockEverything()
        live.heard(reading("Ice cream today and"), now: 5)
        live.heard(reading("Ice cream today and"), now: 6)
        #expect(live.text == "I scream today and")
    }

    @Test func whenNothingAgreesForLongTheOlderWordsAreTypedAnyway() {
        var live = LiveTranscript()
        live.heard(reading("a b c d e f g h i j k l m n"), now: 7)
        #expect(live.text == "")
        live.heard(reading("A B C D E F G H I J K L M N O P Q R"), now: 9.2)
        // Nothing agreed for over 8 s: words ending at least 2 s before now (by 7.2 s) are typed.
        #expect(live.text == "A B C D E F G H I J K L M N")
    }

    @Test func aWordAtTheVeryEndWaitsInCaseItIsCutOff() {
        var live = LiveTranscript()
        let words = [HeardWord("Hello", start: 0.2, end: 0.6), HeardWord("there", start: 0.7, end: 1.9)]
        live.heard(words, now: 1)
        live.heard(words, now: 2)
        #expect(live.text == "Hello")
        live.heard(words, now: 3)
        #expect(live.text == "Hello there")
    }

    @Test func aCorrectionNeverReachesWhatMustBeKept() {
        #expect(LiveEdit(delete: 5, type: "x").isSafe(typedCount: 20, keeping: 15))
        #expect(!LiveEdit(delete: 6, type: "x").isSafe(typedCount: 20, keeping: 15))
        #expect(!LiveEdit(delete: LiveEdit.mostToDelete + 1, type: "").isSafe(typedCount: 1000))
    }

    @Test func typingOnlyAddsWhenTheStartIsTheSame() {
        #expect(LiveEdit.from("Let's meet", to: "Let's meet on Tuesday") == LiveEdit(delete: 0, type: " on Tuesday"))
        #expect(LiveEdit.from("", to: "Hello") == LiveEdit(delete: 0, type: "Hello"))
        #expect(LiveEdit.from("Hello", to: "Hello").isNothing)
    }

    @Test func tidyingTheEndDeletesOnlyWhatChanged() {
        // A word list fix that needed the next word: "wisper flow" becomes "Wispr Flow".
        #expect(LiveEdit.from("I use wisper", to: "I use Wispr Flow") == LiveEdit(delete: 6, type: "Wispr Flow"))
        // Casual style takes the full stop off the end.
        #expect(LiveEdit.from("sounds good.", to: "sounds good") == LiveEdit(delete: 1, type: ""))
    }

    @Test func theWholeOrderStillAppliesToWhatsSettled() {
        let snippet = Snippet(trigger: "my email", text: "jude@example.com")
        let first = Tidy.dictation("send it to my email", words: [], snippets: [snippet], british: true).text
        let later = Tidy.dictation("send it to my email please", words: [], snippets: [snippet], british: true).text
        #expect(first == "Send it to jude@example.com")
        #expect(LiveEdit.from(first, to: later) == LiveEdit(delete: 0, type: " please"))
    }
}

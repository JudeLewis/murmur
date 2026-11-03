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
        #expect(live.heard(reading("Let's meet"), now: 1).isEmpty)
        #expect(live.heard(reading("Let's meet on Tues"), now: 2) == ["Let's", "meet"])
        #expect(live.heard(reading("Let's meet on Tuesday at", from: 0), now: 3) == ["on"])
        #expect(live.text == "Let's meet on")
    }

    @Test func settledWordsAreNotReadAgainButHeardAsContext() {
        var live = LiveTranscript()
        _ = live.heard(reading("one two three four five six seven eight nine ten"), now: 5)
        _ = live.heard(reading("one two three four five six seven eight nine ten"), now: 5.5)
        #expect(live.text == "one two three four five six seven eight nine ten")
        // Ten ends at 4.9 s, so the next reading starts 5 s earlier (here, at the start).
        #expect(live.windowStart == 0)
        // Words from that context aren't typed twice.
        let again = reading("seven eight nine ten eleven", from: 3)
        #expect(live.heard(again, now: 6).isEmpty)
        #expect(live.heard(again, now: 7) == ["eleven"])
    }

    @Test func aWordTheModelChangesItsMindAboutWaits() {
        var live = LiveTranscript()
        _ = live.heard(reading("I scream"), now: 1)
        #expect(live.heard(reading("Ice cream"), now: 2).isEmpty)
        #expect(live.heard(reading("Ice cream"), now: 3) == ["Ice", "cream"])
    }

    @Test func whenNothingAgreesForLongTheOlderWordsAreTypedAnyway() {
        var live = LiveTranscript()
        #expect(live.heard(reading("a b c d e f g h i j k l m n"), now: 7).isEmpty)
        let typed = live.heard(reading("A B C D E F G H I J K L M N O P Q R"), now: 9.2)
        // Nothing agreed for over 8 s: words ending at least 2 s before now (by 7.2 s) are typed.
        #expect(typed == ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N"])
    }

    @Test func aLongPauseIsNotReadAgainAndAgain() {
        var live = LiveTranscript()
        _ = live.heard(reading("Hello"), now: 1)
        _ = live.heard(reading("Hello"), now: 2)
        _ = live.heard([], now: 20)
        #expect(live.windowStart > 12)
        // Something said after the pause is still heard.
        _ = live.heard(reading("again", from: 19), now: 20)
        #expect(live.heard(reading("again", from: 19), now: 21) == ["again"])
    }

    @Test func theLastWordHeardAgainALittleLaterIsNotTypedTwice() {
        // Seen 3 Nov 2026: "My favourite part part was".
        var live = LiveTranscript()
        let first = [HeardWord("My", start: 8.0, end: 8.2), HeardWord("favourite", start: 8.3, end: 8.8), HeardWord("part", start: 9.0, end: 9.4)]
        _ = live.heard(first, now: 10)
        _ = live.heard(first, now: 11)
        #expect(live.text == "My favourite part")
        let later = [HeardWord("part", start: 9.2, end: 9.7), HeardWord("was", start: 9.8, end: 10.0)]
        _ = live.heard(later, now: 12)
        #expect(live.heard(later, now: 13) == ["was"])
        #expect(live.text == "My favourite part was")
    }

    @Test func aWordAtTheVeryEndWaitsInCaseItIsCutOff() {
        var live = LiveTranscript()
        let words = [HeardWord("Hello", start: 0.2, end: 0.6), HeardWord("there", start: 0.7, end: 1.9)]
        _ = live.heard(words, now: 1)
        #expect(live.heard(words, now: 2) == ["Hello"])
        #expect(live.heard(words, now: 3) == ["there"])
    }

    @Test func stoppingTypesEverythingLeft() {
        var live = LiveTranscript()
        _ = live.heard(reading("See you"), now: 1)
        _ = live.heard(reading("See you at"), now: 1.5)
        #expect(live.finished(reading("See you at six.")) == ["at", "six."])
        #expect(live.text == "See you at six.")
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

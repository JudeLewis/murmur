import Foundation
import Testing
@testable import MurmurCore

@Suite("4.5 Snippets")
struct SnippetTests {
    let email = Snippet(trigger: "my email", text: "jude@example.com")
    let sign = Snippet(trigger: "sign off", text: "Thanks,\nJude")

    @Test func aWholeDictationBecomesTheSavedTextExactly() {
        #expect(Snippets.apply([email], to: "My email.") == "jude@example.com")
        #expect(Snippets.apply([sign], to: "Sign off!") == "Thanks,\nJude")
        #expect(Snippets.apply([email], to: "my e-mail") == "my e-mail")
    }

    @Test func insideASentenceOnlyTheTriggerIsSwapped() {
        #expect(Snippets.apply([email], to: "Send it to my email, please.") == "Send it to jude@example.com, please.")
        #expect(Snippets.apply([email], to: "My emails are full.") == "My emails are full.")
    }

    @Test func emptyOnesAreIgnored() {
        #expect(Snippets.apply([Snippet(trigger: "", text: "x"), Snippet(trigger: "hi", text: "")], to: "Hi.") == "Hi.")
    }

    @Test func savedTextIsNotChangedByTidying() {
        let address = Snippet(trigger: "my address", text: "1 color street")
        let dictation = Tidy.dictation("my address", words: [], snippets: [address], british: true)
        #expect(dictation.text == "1 color street")
    }

    @Test func triggersWithAmericanSpellingStillMatch() {
        let colour = Snippet(trigger: "my favorite color", text: "blue")
        #expect(Tidy.dictation("my favorite color", words: [], snippets: [colour], british: true).text == "blue")
    }

    @Test func apostrophesAndSymbolsMatchInsideASentence() {
        let jude = Snippet(trigger: "Jude's email", text: "jude@example.com")
        #expect(Snippets.apply([jude], to: "Send it to Jude\u{2019}s email please.") == "Send it to jude@example.com please.")
        let code = Snippet(trigger: "c++ code", text: "C++")
        #expect(Snippets.apply([code], to: "Write the c++ code now.") == "Write the C++ now.")
    }

    @Test func oneSnippetNeverChangesAnothersText() {
        let email = Snippet(trigger: "my email", text: "jude@example.com")
        let example = Snippet(trigger: "example", text: "EX")
        #expect(Snippets.apply([email, example], to: "Send to my email, for example.") == "Send to jude@example.com, for EX.")
    }

    @Test func roundTripsAsData() {
        #expect(Snippets.decode(Snippets.encode([email, sign])) == [email, sign])
        #expect(Snippets.decode(Data("nonsense".utf8)) == [])
        #expect(Snippets.decode(nil) == [])
    }
}

@Suite("4.6 Spoken commands")
struct SpokenCommandTests {
    @Test func newLineAndNewParagraph() {
        #expect(SpokenCommands.lineBreaks(in: "Hello. New line. How are you?") == "Hello.\nHow are you?")
        #expect(SpokenCommands.lineBreaks(in: "Dear Sam, new paragraph, thanks for this.") == "Dear Sam,\n\nThanks for this.")
        #expect(SpokenCommands.lineBreaks(in: "Shopping. New line. Milk, new line, eggs") == "Shopping.\nMilk,\nEggs")
        #expect(SpokenCommands.lineBreaks(in: "Thanks new line") == "Thanks\n")
    }

    @Test func notInTheMiddleOfAnOrdinarySentence() {
        #expect(SpokenCommands.lineBreaks(in: "We are launching a new line of shoes.") == "We are launching a new line of shoes.")
        #expect(SpokenCommands.lineBreaks(in: "My new line manager starts today.") == "My new line manager starts today.")
    }

    @Test func capitalsInsideWordsAreKeptAfterABreak() {
        #expect(SpokenCommands.lineBreaks(in: "Hello. New line. eBay is great.") == "Hello.\neBay is great.")
        #expect(SpokenCommands.lineBreaks(in: "Hello, new line, iPhone time.") == "Hello,\niPhone time.")
    }

    @Test func onlyTheWholeCommand() {
        #expect(SpokenCommands.lineBreaks(in: "The new lines look good.") == "The new lines look good.")
        #expect(SpokenCommands.lineBreaks(in: "A renewed linen order.") == "A renewed linen order.")
    }

    @Test func pressEnterAtTheEnd() {
        #expect(SpokenCommands.pressEnter(in: "See you soon. Press enter.") == ("See you soon.", true))
        #expect(SpokenCommands.pressEnter(in: "See you soon, press return") == ("See you soon", true))
        #expect(SpokenCommands.pressEnter(in: "Press enter.") == ("", true))
        #expect(SpokenCommands.pressEnter(in: "Press enter to continue.") == ("Press enter to continue.", false))
    }

    @Test func theWholeOrder() {
        let dictation = Tidy.dictation("hi sam. new line. see you at six. press enter.", words: [], british: true)
        #expect(dictation == Dictation(text: "Hi sam.\nSee you at six.", pressEnter: true))
        #expect(Tidy.dictation("Press enter.", words: [], british: true) == Dictation(text: "", pressEnter: true))
    }

    @Test func noSpaceAfterALineBreakOrBeforeReturn() {
        #expect(Tidy.forInsertion("Hello.\n") == "Hello.\n")
        #expect(Tidy.forInsertion("Hello.", pressEnter: true) == "Hello.")
        #expect(Tidy.forInsertion("\nHello.", after: "Hi.") == "\nHello. ")
    }
}

@Suite("4.7 Casual style")
struct CasualTests {
    @Test func noCapitalAtTheStartAndNoFullStopAtTheEnd() {
        #expect(Tidy.casual("Sounds good to me.") == "sounds good to me")
        #expect(Tidy.casual("Are you coming?") == "are you coming?")
        #expect(Tidy.casual("Wait...") == "wait...")
    }

    @Test func someCapitalsStay() {
        #expect(Tidy.casual("I think so.") == "I think so")
        #expect(Tidy.casual("I'm on my way.") == "I'm on my way")
        #expect(Tidy.casual("NASA called.") == "NASA called")
        let words = [WordEntry(heard: "Jude", written: "Jude")]
        #expect(Tidy.casual("Jude is here.", keeping: words) == "Jude is here")
    }

    @Test func aListedNameMustBeTheWholeWord() {
        let words = [WordEntry(heard: "Jo", written: "Jo")]
        #expect(Tidy.casual("Joking aside, it works.", keeping: words) == "joking aside, it works")
        #expect(Tidy.casual("Jo, it works.", keeping: words) == "Jo, it works")
    }

    @Test func onlyWhenAskedFor() {
        #expect(Tidy.dictation("sounds good", words: [], british: true, casual: true).text == "sounds good")
        #expect(Tidy.dictation("sounds good.", words: [], british: true, casual: false).text == "Sounds good.")
    }
}

@Suite("4.2 Word list: fixes and saving")
struct WordFixTests {
    @Test func aChangedNameBecomesAFix() {
        let fixes = WordFix.suggest(original: "I use wisper flow every day.", edited: "I use Wispr Flow every day.")
        #expect(fixes == [WordEntry(heard: "wisper flow", written: "Wispr Flow")])
    }

    @Test func capitalsOnlyBecomesAlwaysWriteItLikeThis() {
        let fixes = WordFix.suggest(original: "Open clocked in now.", edited: "Open Clocked In now.")
        #expect(fixes == [WordEntry(heard: "Clocked In", written: "Clocked In")])
    }

    @Test func punctuationAndBigRewritesAreIgnored() {
        #expect(WordFix.suggest(original: "Hello, there.", edited: "Hello there!").isEmpty)
        #expect(WordFix.suggest(original: "One two three four five.", edited: "Six seven eight nine ten.").isEmpty)
        #expect(WordFix.suggest(original: "Same.", edited: "Same.").isEmpty)
    }

    @Test func severalFixesOnceEach() {
        let fixes = WordFix.suggest(original: "Ask jood about the clockt in app.", edited: "Ask Jude about the Clocked In app.")
        #expect(fixes.contains(WordEntry(heard: "jood", written: "Jude")))
        #expect(fixes.contains(WordEntry(heard: "clockt in", written: "Clocked In")))
    }

    @Test func theScreensTwoBoxes() {
        #expect(WordEntry.fromForm(written: "Wispr Flow", heard: "wisper flow") == WordEntry(heard: "wisper flow", written: "Wispr Flow"))
        #expect(WordEntry.fromForm(written: " Clocked In ", heard: "") == WordEntry(heard: "Clocked In", written: "Clocked In"))
        // Write it as empty: remove the word.
        #expect(WordEntry.fromForm(written: "", heard: "basically") == WordEntry(heard: "basically", written: ""))
        #expect(WordEntry.fromForm(written: "", heard: "") == nil)
        // Wouldn't read back from words.txt.
        #expect(WordEntry.fromForm(written: "#random", heard: "") == nil)
        #expect(WordEntry.fromForm(written: "a -> b", heard: "") == nil)
    }

    @Test func removalsSurviveSaving() {
        let entries = [WordEntry(heard: "basically", written: "")]
        #expect(WordList.parse(WordList.text(for: entries)) == entries)
    }

    @Test func savingRoundTrips() {
        let entries = [WordEntry(heard: "Clocked In", written: "Clocked In"), WordEntry(heard: "wisper flow", written: "Wispr Flow")]
        #expect(WordList.parse(WordList.text(for: entries)) == entries)
        #expect(WordList.parse(WordList.text(for: [])) == [])
    }
}

@Suite("2.5 Hold Fn to talk")
struct HoldFnTests {
    private func fn(_ down: Bool) -> KeyEvent { .modifiersChanged(keyCode: 63, fnHeld: down) }

    @Test func holdStartsAndLettingGoStops() {
        var watcher = FnWatcher()
        #expect(watcher.handle(fn(true), at: 10) == .nothing)
        #expect(watcher.tick(at: 10.3) == .nothing)
        #expect(watcher.tick(at: 10.5) == .holdStarted)
        #expect(watcher.tick(at: 10.8) == .nothing)
        #expect(watcher.handle(fn(false), at: 12) == .holdEnded)
    }

    @Test func anotherKeyCancelsAHold() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 10)
        #expect(watcher.tick(at: 10.6) == .holdStarted)
        #expect(watcher.handle(.keyDown(keyCode: 123), at: 11) == .holdCancelled)
        #expect(watcher.handle(fn(false), at: 11.2) == .nothing)
    }

    @Test func fnUsedWithAnotherKeyNeverStartsAHold() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 10)
        _ = watcher.handle(.keyDown(keyCode: 123), at: 10.2)
        #expect(watcher.tick(at: 10.6) == .nothing)
    }

    @Test func tapsStillWorkAndNeverHold() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 10)
        _ = watcher.handle(fn(false), at: 10.1)
        #expect(watcher.tick(at: 10.6) == .nothing)
        _ = watcher.handle(fn(true), at: 10.3)
        #expect(watcher.handle(fn(false), at: 10.4) == .doubleTap)
    }

    @Test func canBeTurnedOff() {
        var watcher = FnWatcher()
        watcher.holdToTalk = false
        _ = watcher.handle(fn(true), at: 10)
        #expect(watcher.tick(at: 11) == .nothing)
        #expect(watcher.handle(fn(false), at: 12) == .nothing)
    }

    @Test func escapeIsAlwaysEscape() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 10)
        #expect(watcher.tick(at: 10.6) == .holdStarted)
        #expect(watcher.handle(.keyDown(keyCode: 53), at: 11) == .escape)
    }

    @Test func holdRulesInTheFlow() {
        var flow = DictationFlow()
        #expect(flow.holdStarted() == .startRecording)
        #expect(flow.heldOpen)
        #expect(flow.holdEnded() == .stopAndTranscribe)
        #expect(!flow.heldOpen)
        flow.finished()

        // A hold during a double-tap dictation does nothing, and letting go doesn't stop it.
        #expect(flow.toggle() == .startRecording)
        #expect(flow.holdStarted() == .nothing)
        #expect(flow.holdEnded() == .nothing)
        #expect(flow.phase == .recording)

        // Escape or another key during a hold throws it away.
        _ = flow.cancel()
        #expect(flow.holdStarted() == .startRecording)
        #expect(flow.holdCancelled() == .cancelRecording)
        #expect(flow.phase == .idle)
        #expect(flow.holdEnded() == .nothing)
    }

    @Test func theGlobeKeysOwnPressDoesNotCancel() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 10)
        _ = watcher.handle(.keyDown(keyCode: 179), at: 10.01)
        #expect(watcher.tick(at: 10.6) == .holdStarted)
    }
}

@Suite("2.6 Music down while listening")
struct DuckingTests {
    @Test func dropsToAQuarter() {
        #expect(Ducking.lowered(from: 0.8) == 0.2)
    }

    @Test func putsItBackOnlyIfUntouched() {
        #expect(Ducking.shouldRestore(current: 0.2, lowered: 0.2))
        #expect(Ducking.shouldRestore(current: 0.21, lowered: 0.2))
        #expect(!Ducking.shouldRestore(current: 0.5, lowered: 0.2))
    }
}

@Suite("9.4 Talking from the keyboard: undo, bars and Return")
struct KeyboardExtrasTests {
    @Test func undoTakesTheLastDictationBackOut() {
        var last = LastTyped()
        last.typed("Hello there. ")
        #expect(last.undo(before: "Hi. Hello there. ") == LastTyped.Undo(delete: 13, retype: ""))
        #expect(last.undo(before: "Hi. Hello there. ") == nil)
    }

    @Test func undoWorksWhenIOSShowsOnlyTheEnd() {
        var last = LastTyped()
        last.typed("Hi Sam\nSee you at six. ")
        #expect(last.undo(before: "See you at six. ")?.delete == 23)
        last.typed("Hello there. ")
        #expect(last.undo(before: ". ") == nil)
    }

    @Test func undoDoesNothingIfTheTextChanged() {
        var last = LastTyped()
        last.typed("Hello there. ")
        #expect(last.undo(before: "Hello there. And more") == nil)
        #expect(last.undo(before: nil) == nil)
    }

    @Test func barsKeepTheLatestLevels() {
        var history = LevelHistory()
        for level in [0.1, 0.5, 2.0] as [Float] { history.add(level) }
        #expect(history.levels.count == LevelHistory.bars)
        #expect(history.levels.suffix(3) == [0.1, 0.5, 1.0])
        history.clear()
        #expect(history.levels.allSatisfy { $0 == 0 })
    }

    @Test func pressEnterIsPassedOn() {
        let result = PhoneResult(id: 3, text: "On my way.", pressEnter: true)
        #expect(KeyboardLink.delivery(of: result, waitingFor: 3) == .type("On my way.", pressEnter: true))
        let onlyEnter = PhoneResult(id: 4, text: "", pressEnter: true)
        #expect(KeyboardLink.delivery(of: onlyEnter, waitingFor: 4) == .type("", pressEnter: true))
    }

    @Test func olderFilesWithoutTheNewFieldsStillRead() throws {
        let old = #"{"id":5,"kind":"start"}"#
        let request = try JSONDecoder().decode(KeyboardRequest.self, from: Data(old.utf8))
        #expect(request == KeyboardRequest(id: 5, kind: .start))
    }
}

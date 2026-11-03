import Testing
@testable import MurmurCore

@Suite("2.10 Pause")
struct PauseTests {
    @Test func aLoneTapIsReportedOnceTheGapHasPassed() {
        var watcher = FnWatcher()
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: false), at: 10.1)
        #expect(watcher.tick(at: 10.3) == .nothing)
        #expect(watcher.tick(at: 10.52) == .singleTap)
        #expect(watcher.tick(at: 10.6) == .nothing)
    }

    @Test func aDoubleTapIsNotAlsoTwoSingleTaps() {
        var watcher = FnWatcher()
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: false), at: 10.1)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10.3)
        #expect(watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: false), at: 10.4) == .doubleTap)
        #expect(watcher.tick(at: 10.52) == .nothing)
        #expect(watcher.tick(at: 10.82) == .nothing)
    }

    @Test func fnUsedWithAnotherKeyIsNotATap() {
        var watcher = FnWatcher()
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10)
        _ = watcher.handle(.keyDown(keyCode: 123), at: 10.05)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: false), at: 10.1)
        #expect(watcher.tick(at: 10.52) == .nothing)
    }

    @Test func aBounceStraightAfterTheDoubleTapIsNotAPause() {
        var watcher = FnWatcher()
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: false), at: 10.1)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10.2)
        #expect(watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: false), at: 10.3) == .doubleTap)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10.45)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: false), at: 10.5)
        #expect(watcher.tick(at: 10.95) == .nothing)
    }

    @Test func aLoneTapStillCountsIfFnIsPressedAgainJustAfter() {
        var watcher = FnWatcher()
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10)
        _ = watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: false), at: 10.1)
        #expect(watcher.handle(.modifiersChanged(keyCode: 63, fnHeld: true), at: 10.51) == .singleTap)
    }

    @Test func pausesOnlyWhileListeningAfterADoubleTap() {
        var flow = DictationFlow()
        var paused = flow.singleTap()
        #expect(!paused)
        _ = flow.toggle()
        paused = flow.singleTap()
        #expect(paused && flow.paused)
        let carriedOn = flow.singleTap()
        #expect(carriedOn && !flow.paused)
        _ = flow.singleTap()
        _ = flow.toggle()
        #expect(!flow.paused)
        let whileWriting = flow.singleTap()
        #expect(!whileWriting)

        var held = DictationFlow()
        _ = held.holdStarted()
        let whileHolding = held.singleTap()
        #expect(!whileHolding)
    }

    @Test func cancellingForgetsThePause() {
        var flow = DictationFlow()
        _ = flow.toggle()
        _ = flow.singleTap()
        _ = flow.cancel()
        #expect(!flow.paused)
    }
}

@Suite("4.9 Emails")
struct EmailTests {
    @Test func mailAppsAndWebmailCount() {
        #expect(EmailLayout.isEmail(app: "com.apple.mail", windowTitle: nil))
        #expect(EmailLayout.isEmail(app: "com.google.Chrome", windowTitle: "Inbox (3) - jude@gmail.com - Gmail"))
        #expect(EmailLayout.isEmail(app: "com.apple.Safari", windowTitle: "Mail - Jude Lewis - Outlook"))
        #expect(!EmailLayout.isEmail(app: "com.google.Chrome", windowTitle: "Gmail tips and tricks - YouTube"))
        #expect(!EmailLayout.isEmail(app: "com.apple.Notes", windowTitle: nil))
        #expect(!EmailLayout.isEmail(app: "com.apple.Notes", windowTitle: "Ideas for Gmail"))
        // Browsers add their own name or a profile to the title.
        #expect(EmailLayout.isEmail(app: "org.mozilla.firefox", windowTitle: "Inbox - jude@gmail.com - Gmail \u{2014} Mozilla Firefox"))
        #expect(EmailLayout.isEmail(app: "com.microsoft.edgemac", windowTitle: "Mail - Jude Lewis - Outlook - Personal - Microsoft Edge"))
    }

    @Test func greetingAndSignOffGetTheirOwnLines() {
        #expect(EmailLayout.apply("Hi Sam. Thanks for sending the report. Best, Jude.")
            == "Hi Sam,\n\nThanks for sending the report.\n\nBest,\nJude")
        #expect(EmailLayout.apply("Dear Mr Smith, please find the invoice attached. Kind regards.")
            == "Dear Mr Smith,\n\nPlease find the invoice attached.\n\nKind regards,")
        #expect(EmailLayout.apply("Hey, can you send it today? Thanks Jude.") == "Hey,\n\nCan you send it today?\n\nThanks,\nJude")
    }

    @Test func aGreetingOnItsOwnLeavesTheCursorReadyForTheMessage() {
        #expect(EmailLayout.apply("Hi Sam.") == "Hi Sam,\n\n")
        #expect(EmailLayout.apply("Good morning everyone,") == "Good morning everyone,\n\n")
    }

    @Test func iIsNeverWhoItsTo() {
        #expect(EmailLayout.apply("Hi I wanted to ask about Friday.") == "Hi I wanted to ask about Friday.")
        #expect(EmailLayout.apply("Hi, I wanted to ask about Friday.") == "Hi,\n\nI wanted to ask about Friday.")
        #expect(EmailLayout.apply("Dear John I hope you're well.") == "Dear John,\n\nI hope you're well.")
    }

    @Test func ordinarySentencesAreLeftAlone() {
        #expect(EmailLayout.apply("Hiking is fun. I'll see you there.") == "Hiking is fun. I'll see you there.")
        #expect(EmailLayout.apply("hello world is the first program") == "hello world is the first program")
        #expect(EmailLayout.apply("Can you send it today? Thanks.") == "Can you send it today? Thanks.")
        #expect(EmailLayout.apply("Thanks for the report.") == "Thanks for the report.")
        #expect(EmailLayout.apply("It was the best, honestly, the very best.") == "It was the best, honestly, the very best.")
    }

    @Test func onlyLineBreaksAndPunctuationChange() {
        let said = "Hi Sam and Tom. The meeting is moved to Friday. See you then. Cheers, Jude Lewis."
        let laidOut = EmailLayout.apply(said)
        let words = { (text: String) in text.lowercased().split { !$0.isLetter }.map(String.init) }
        #expect(words(laidOut) == words(said))
        #expect(laidOut.hasSuffix("See you then.\n\nCheers,\nJude Lewis"))
    }

    @Test func itsPartOfTheWholeOrderOnlyForEmails() {
        let said = "hi sam. new paragraph. the report is great. thanks, jude."
        let email = Tidy.dictation("Hi Sam. The report is great. Thanks, Jude.", words: [], british: true, email: true).text
        #expect(email == "Hi Sam,\n\nThe report is great.\n\nThanks,\nJude")
        let notEmail = Tidy.dictation("Hi Sam. The report is great. Thanks, Jude.", words: [], british: true).text
        #expect(notEmail == "Hi Sam. The report is great. Thanks, Jude.")
        _ = said
    }
}

@Suite("4.6 Spoken commands: scratch that")
struct ScratchThatTests {
    @Test func takesOutTheSentenceBefore() {
        #expect(ScratchThat.apply("Let's meet at three. Scratch that. Let's meet at four.") == "Let's meet at four.")
        #expect(ScratchThat.apply("Hello Sam. Let's meet at three, scratch that, let's meet at four.")
            == "Hello Sam. Let's meet at four.")
        #expect(ScratchThat.apply("First thing. Wrong thing. Scratch that.") == "First thing.")
    }

    @Test func stopsAtALineBreak() {
        #expect(ScratchThat.apply("Hi Sam,\nWrong line. Scratch that. Right line.") == "Hi Sam,\nRight line.")
    }

    @Test func onlyWhenItStandsAlone() {
        #expect(ScratchThat.apply("I need to scratch that itch.") == "I need to scratch that itch.")
        #expect(ScratchThat.apply("Can you scratch that off the list?") == "Can you scratch that off the list?")
    }

    @Test func withoutPunctuationItMustStartTheSentenceAgain() {
        // As the speech model wrote them, 3 Nov 2026.
        #expect(ScratchThat.apply("Send it to tom no scratch that send it to Sarah") == "Send it to Sarah")
        #expect(ScratchThat.apply("The total is fifty pounds scratch that the total is sixty pounds")
            == "The total is sixty pounds")
        #expect(ScratchThat.apply("Hello Sam. Let's meet at three scratch that let's meet at four")
            == "Hello Sam. Let's meet at four")
        #expect(ScratchThat.apply("I need to scratch that itch on my back") == "I need to scratch that itch on my back")
    }

    @Test func atTheStartThereIsNothingToTakeOut() {
        #expect(ScratchThat.apply("Scratch that. Hello.") == "Hello.")
        #expect(ScratchThat.apply("Scratch that.") == "")
    }

    @Test func twiceTakesOutTwoSentences() {
        #expect(ScratchThat.apply("One. Two. Scratch that. Three. Scratch that. Four.") == "One. Four.")
    }

    @Test func worksWithTheWholeOrder() {
        #expect(Tidy.dictation("Let's meet at three. Scratch that. Let's meet at four.", words: [], british: true).text
            == "Let's meet at four.")
    }
}

@Suite("4.10 Other people's voices")
struct QuietVoicesTests {
    private func sentence(_ text: String, from start: Double, loudness: Float) -> [HeardWord] {
        text.split(separator: " ").enumerated().map { index, word in
            HeardWord(String(word), start: start + Double(index) * 0.4, end: start + Double(index) * 0.4 + 0.3, loudness: loudness)
        }
    }

    @Test func aMuchQuieterSentenceIsLeftOut() {
        let words = sentence("Thanks for the report.", from: 0, loudness: 0.2)
            + sentence("Yeah I'll be down in a minute.", from: 2, loudness: 0.04)
            + sentence("See you on Friday.", from: 5, loudness: 0.18)
        #expect(QuietVoices.keep(words).map(\.text).joined(separator: " ") == "Thanks for the report. See you on Friday.")
    }

    @Test func yourOwnQuieterMomentsStay() {
        let words = sentence("Thanks for the report.", from: 0, loudness: 0.2)
            + sentence("I think it's good.", from: 2, loudness: 0.1)
        #expect(QuietVoices.keep(words).count == words.count)
    }

    @Test func oneSentenceIsNeverLeftOut() {
        let words = sentence("Hello there.", from: 0, loudness: 0.01)
        #expect(QuietVoices.keep(words) == words)
    }

    @Test func aLongPauseEndsASentenceToo() {
        // Timings run on from one word to the next, as the model gives them: "that" ends where "dinner" starts.
        var words = sentence("thanks for that", from: 0, loudness: 0.2) + sentence("dinner is ready", from: 4, loudness: 0.03)
        words[2].end = 4
        #expect(QuietVoices.keep(words).map(\.text) == ["thanks", "for", "that"])
    }
}

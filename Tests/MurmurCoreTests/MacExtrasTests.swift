import Foundation
import Testing
@testable import MurmurCore

@Suite("2.7 Command Mode")
struct CommandModeTests {
    private func fn(_ down: Bool, control: Bool = false) -> KeyEvent { .modifiersChanged(keyCode: 63, fnHeld: down, controlHeld: control) }
    private func control(_ down: Bool, fn: Bool) -> KeyEvent { .modifiersChanged(keyCode: 59, fnHeld: fn, controlHeld: down) }

    @Test func fnThenControlHeldStartsCommandMode() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 10)
        #expect(watcher.handle(control(true, fn: true), at: 10.1) == .nothing)
        #expect(watcher.tick(at: 10.6) == .commandHoldStarted)
        #expect(watcher.handle(control(false, fn: true), at: 11) == .nothing)
        #expect(watcher.handle(fn(false), at: 12) == .holdEnded)
    }

    @Test func controlThenFnHeldStartsCommandModeToo() {
        var watcher = FnWatcher()
        _ = watcher.handle(control(true, fn: false), at: 10)
        _ = watcher.handle(fn(true, control: true), at: 10.1)
        #expect(watcher.tick(at: 10.7) == .commandHoldStarted)
    }

    @Test func controlFnTapsNeverDoubleTap() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true, control: true), at: 10)
        _ = watcher.handle(fn(false, control: true), at: 10.1)
        _ = watcher.handle(fn(true), at: 10.3)
        #expect(watcher.handle(fn(false), at: 10.4) == .nothing)
    }

    @Test func otherKeysStillCancel() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true, control: true), at: 10)
        #expect(watcher.tick(at: 10.6) == .commandHoldStarted)
        #expect(watcher.handle(.keyDown(keyCode: 0), at: 11) == .holdCancelled)
    }

    @Test func controlDuringAnOrdinaryHoldThrowsItAway() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 10)
        #expect(watcher.tick(at: 10.6) == .holdStarted)
        #expect(watcher.handle(control(true, fn: true), at: 11) == .holdCancelled)
    }

    @Test func canBeTurnedOffWithoutAffectingHoldToTalk() {
        var watcher = FnWatcher()
        watcher.commandMode = false
        _ = watcher.handle(fn(true, control: true), at: 10)
        #expect(watcher.tick(at: 10.6) == .nothing)
        _ = watcher.handle(fn(false), at: 11)
        _ = watcher.handle(fn(true), at: 20)
        #expect(watcher.tick(at: 20.6) == .holdStarted)
    }

    @Test func promptWithAndWithoutSelectedText() {
        #expect(CommandMode.prompt(instruction: "Make this friendlier.", selection: "Send it.") == "Instruction: Make this friendlier.\n\nText:\nSend it.")
        #expect(CommandMode.prompt(instruction: "A polite no thanks.", selection: nil) == "Write this: A polite no thanks.")
        #expect(CommandMode.prompt(instruction: "A polite no thanks.", selection: "  \n") == "Write this: A polite no thanks.")
    }

    @Test func britishSpellingOnlyWhenTicked() {
        #expect(CommandMode.instructions(british: true).contains("British"))
        #expect(!CommandMode.instructions(british: false).contains("British"))
        let reply = "My favorite color is gray."
        #expect(CommandMode.finish(reply: reply, words: [], british: true, replacingSelection: true) == "My favourite colour is grey.")
        #expect(CommandMode.finish(reply: reply, words: [], british: false, replacingSelection: true) == reply)
    }

    @Test func newTextGetsASpaceAfterIt() {
        #expect(CommandMode.finish(reply: "Thanks, but I'll pass.", words: [], british: true, replacingSelection: false) == "Thanks, but I'll pass. ")
        #expect(CommandMode.finish(reply: "Thanks.", words: [], british: true, replacingSelection: true) == "Thanks.")
        let words = [WordEntry(heard: "wisper flow", written: "Wispr Flow")]
        #expect(CommandMode.finish(reply: "\"I use wisper flow.\"", words: words, british: true, replacingSelection: true) == "I use Wispr Flow.")
    }

    @Test func extrasAroundTheReplyAreTakenOff() {
        #expect(CommandMode.clean("Here is the friendlier version:\nCould you send it?") == "Could you send it?")
        #expect(CommandMode.clean("\"Could you send it?\"") == "Could you send it?")
        #expect(CommandMode.clean("```text\nline one\nline two\n```") == "line one\nline two")
        #expect(CommandMode.clean("He said \"hi\" and \"bye\"") == "He said \"hi\" and \"bye\"")
        #expect(CommandMode.clean("Here is why: it works.") == "Here is why: it works.")
        #expect(CommandMode.clean("Dear [Name],\n\nI can't come.\n\nKind regards,\n\n[Your Name]") == "I can't come.\n\nKind regards,")
        #expect(CommandMode.clean("See section [2] of the long document for the details.") == "See section [2] of the long document for the details.")
    }
}

@Suite("2.8 Paste again")
struct PasteAgainTests {
    @Test func controlCommandVOnly() {
        #expect(Shortcuts.isPasteAgain(keyCode: 9, command: true, control: true, option: false, shift: false))
        #expect(!Shortcuts.isPasteAgain(keyCode: 9, command: true, control: false, option: false, shift: false))
        #expect(!Shortcuts.isPasteAgain(keyCode: 9, command: true, control: true, option: true, shift: false))
        #expect(!Shortcuts.isPasteAgain(keyCode: 8, command: true, control: true, option: false, shift: false))
    }
}

@Suite("3.3 The microphone")
struct MicChoiceTests {
    let builtIn = Microphone(uid: "built-in", name: "MacBook Air Microphone", isBuiltIn: true)
    let usb = Microphone(uid: "usb", name: "Yeti", isBuiltIn: false)
    let zoom = Microphone(uid: "zoom", name: "ZoomAudioDevice", isBuiltIn: false, isVirtual: true)

    @Test func theChosenMicWhenItIsThere() {
        #expect(MicChoice.pick(from: [builtIn, usb], chosen: "usb", lidClosed: false, defaultIsBuiltIn: true) == usb)
        #expect(MicChoice.pick(from: [builtIn, usb], chosen: "built-in", lidClosed: true, defaultIsBuiltIn: true) == builtIn)
    }

    @Test func automaticLeavesItToTheMac() {
        #expect(MicChoice.pick(from: [builtIn, usb], chosen: nil, lidClosed: false, defaultIsBuiltIn: true) == nil)
    }

    @Test func anUnpluggedChoiceFallsBack() {
        #expect(MicChoice.pick(from: [builtIn], chosen: "usb", lidClosed: false, defaultIsBuiltIn: true) == nil)
    }

    @Test func lidShutAvoidsTheBuiltInMic() {
        #expect(MicChoice.pick(from: [builtIn, usb], chosen: nil, lidClosed: true, defaultIsBuiltIn: true) == usb)
        #expect(MicChoice.pick(from: [builtIn], chosen: nil, lidClosed: true, defaultIsBuiltIn: true) == nil)
    }

    @Test func lidShutLeavesAGoodDefaultAlone() {
        // The Mac already uses AirPods or another external mic: keep it.
        #expect(MicChoice.pick(from: [builtIn, usb], chosen: nil, lidClosed: true, defaultIsBuiltIn: false) == nil)
    }

    @Test func softwareMicsAreNeverPickedAutomatically() {
        #expect(MicChoice.pick(from: [builtIn, zoom, usb], chosen: nil, lidClosed: true, defaultIsBuiltIn: true) == usb)
        #expect(MicChoice.pick(from: [builtIn, zoom], chosen: nil, lidClosed: true, defaultIsBuiltIn: true) == nil)
        // Chosen by hand, it's used.
        #expect(MicChoice.pick(from: [builtIn, zoom], chosen: "zoom", lidClosed: false, defaultIsBuiltIn: true) == zoom)
    }
}

@Suite("3.4 Whisper mode")
struct WhisperModeTests {
    @Test func quietRecordingsAreMadeLouder() {
        let quiet: [Float] = [0.01, -0.03, 0.02]
        let boosted = Loudness.boosted(quiet, maxGain: Loudness.whisperGain)
        #expect(abs(boosted.map(abs).max()! - 0.6) < 0.001)  // capped at 20 times
        let louder = Loudness.boosted([0.1, -0.3], maxGain: 20)
        #expect(abs(louder[0] - 0.3) < 0.0001 && abs(louder[1] + 0.9) < 0.0001)
    }

    @Test func loudAndSilentRecordingsAreLeftAlone() {
        #expect(Loudness.boosted([0.5, -0.95], maxGain: 20) == [0.5, -0.95])
        #expect(Loudness.boosted([0.0005, -0.0002], maxGain: 20) == [0.0005, -0.0002])
        #expect(Loudness.boosted([], maxGain: 20) == [])
    }
}

@Suite("4.8 Self-corrections")
struct SelfCorrectionTests {
    @Test func theFixComesAfterSpellingAndBeforeSnippets() async {
        let snippet = Snippet(trigger: "my email", text: "jude@example.com")
        let seen = Box()
        let dictation = await Tidy.dictation(
            "my favorite color is red, no wait, I mean my email", words: [], snippets: [snippet], british: true
        ) { finished in
            await seen.set(finished)
            return "My favourite colour is my email."
        }
        // The AI saw British spelling, and the snippet was swapped after its fix.
        #expect(await seen.text == "My favourite colour is red, no wait, I mean my email")
        #expect(dictation.text == "My favourite colour is jude@example.com.")
    }

    @Test func withNoFixTheDictationIsAsBefore() async {
        let dictation = await Tidy.dictation("hello there new line how are you", words: [], british: true) { _ in nil }
        #expect(dictation == Tidy.dictation("hello there new line how are you", words: [], british: true))
    }

    @Test func onlyAskedWhenSomeoneMightHaveCorrectedThemselves() {
        #expect(SelfCorrection.mightCorrect("Monday, no wait, I mean Tuesday."))
        #expect(SelfCorrection.mightCorrect("Send it to Sarah, actually Tom."))
        #expect(SelfCorrection.mightCorrect("In London, no, Manchester."))
        #expect(!SelfCorrection.mightCorrect("I think the plan is good."))
        #expect(!SelfCorrection.mightCorrect("I'm sorrowful about the meaning."))
        #expect(!SelfCorrection.mightCorrect("There's no way."))
    }

    @Test func aFixThatOnlyTakesWordsOutIsUsed() {
        let said = "Let's meet on Monday, no wait, I mean Tuesday at three."
        #expect(SelfCorrection.accept(original: said, fixed: "Let's meet on Tuesday at three.") == "Let's meet on Tuesday at three.")
        #expect(SelfCorrection.accept(original: said, fixed: "Output: Let's meet on Tuesday at three.") == "Let's meet on Tuesday at three.")
    }

    @Test func aFixMustKeepTheOrderAndTheLastWord() {
        // "five, sorry, six" can't become "five": the correction comes last.
        #expect(SelfCorrection.accept(original: "Five, sorry, six.", fixed: "Five.") == nil)
        #expect(SelfCorrection.accept(original: "Five, sorry, six.", fixed: "Six.") == "Six.")
        #expect(SelfCorrection.accept(original: "Five, sorry, six o'clock.", fixed: "six o'clock.") == "Six o'clock.")
        #expect(SelfCorrection.accept(original: "Five, sorry, iPhone.", fixed: "iPhone.") == "iPhone.")
        // Words moved around are not just words taken out.
        #expect(SelfCorrection.accept(original: "Ask Tom then Sarah, I mean, Sarah.", fixed: "Ask Sarah then Sarah.") == nil)
    }

    @Test func aFixMustKeepEveryNot() {
        #expect(SelfCorrection.accept(original: "Actually, I don't think we should go.", fixed: "I think we should go.") == nil)
        #expect(SelfCorrection.accept(original: "Actually, I don't think we should go.", fixed: "I don't think we should go.") == "I don't think we should go.")
    }

    @Test func aFixMustKeepCommandsAndSnippetPhrases() {
        let said = "Tell Sam Monday, no wait, Tuesday. Press enter."
        #expect(SelfCorrection.accept(original: said, fixed: "Tell Sam Tuesday.") == nil)
        #expect(SelfCorrection.accept(original: said, fixed: "Tell Sam Tuesday. Press enter.") == "Tell Sam Tuesday. Press enter.")
        let withSnippet = "Send my email, sorry, my address."
        #expect(SelfCorrection.accept(original: withSnippet, fixed: "Send address.", keeping: ["my address"]) == nil)
        #expect(SelfCorrection.accept(original: withSnippet, fixed: "Send my address.", keeping: ["my address"]) == "Send my address.")
    }

    @Test func aFixThatAddsOrRewordsIsIgnored() {
        let said = "Send it to Sarah, actually Tom."
        #expect(SelfCorrection.accept(original: said, fixed: "Please send it to Tom.") == nil)
        #expect(SelfCorrection.accept(original: said, fixed: "") == nil)
        #expect(SelfCorrection.accept(original: "Hi.", fixed: "Hi there, how are you doing today?") == nil)
    }

    @Test func thePromptAndTheFinishedTextJoinUp() {
        #expect(SelfCorrection.prompt("Call me at five.") == "Input: Call me at five.\nOutput:")
        let dictation = Tidy.dictation(finished: "Hello. New line. Bye.", words: [], british: true)
        #expect(dictation.text == "Hello.\nBye.")
    }
}

/// Holds what the fix was given, for checking.
private actor Box {
    var text: String?
    func set(_ text: String) { self.text = text }
}

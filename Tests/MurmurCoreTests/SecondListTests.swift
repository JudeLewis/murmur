import Foundation
import Testing
@testable import MurmurCore

@Suite("2.11 Undo the last dictation")
struct UndoTests {
    @Test func comesOutWhenTheCursorIsStillJustAfterIt() {
        let last = LastDictation(text: "See you at 6. ", app: "x")
        #expect(last.charactersToRemove(before: "Great. See you at 6. ") == 14)
        #expect(LastDictation(text: " and then we can talk. ", app: nil).charactersToRemove(before: "I'll call you and then we can talk. ") == 23)
    }

    @Test func anAppThatDroppedTheLastSpaceStillWorks() {
        #expect(LastDictation(text: "See you. ", app: nil).charactersToRemove(before: "Hi. See you.") == 8)
    }

    @Test func notWhenYouHaveTypedSinceOrTheAppDoesNotSay() {
        let last = LastDictation(text: "See you. ", app: nil)
        #expect(last.charactersToRemove(before: "See you. Bye") == nil)
        #expect(last.charactersToRemove(before: nil) == nil)
        #expect(LastDictation(text: "", app: nil).charactersToRemove(before: "") == nil)
    }
}

@Suite("2.7 Command Mode: rewriting the last dictation")
struct RewriteLastTests {
    @Test func aboutItWhenItPointsAtWhatWasSaid() {
        for said in ["Make that more formal", "translate it into French", "Shorten this.", "fix the grammar in what I just said"] {
            #expect(LastDictation.isAboutIt(said), "\(said)")
        }
    }

    @Test func newTextWhenItAsksForSomethingNew() {
        for said in ["Write a polite no thanks", "Draft a reply about it", "a haiku about autumn", "Give me three ideas for it"] {
            #expect(!LastDictation.isAboutIt(said), "\(said)")
        }
    }
}

@Suite("4.2 Word list: learning from corrections")
struct LearnFromCorrectionsTests {
    let last = LastDictation(text: "The meeting with Shavon has moved to Thursday. ", app: nil)

    @Test func aWordYouFixedBecomesAFix() {
        let field = "Hi all,\nThe meeting with Siobhan has moved to Thursday. Thanks"
        #expect(last.corrections(in: field) == [WordEntry(heard: "Shavon", written: "Siobhan")])
    }

    @Test func untouchedOrRewrittenOrGoneGivesNothing() {
        #expect(last.corrections(in: "The meeting with Shavon has moved to Thursday.").isEmpty)
        #expect(last.corrections(in: "We'll talk about it next week instead, sorry everyone.").isEmpty)
        #expect(last.corrections(in: "").isEmpty)
        #expect(last.corrections(in: "The meeting with Sam and Jo has been cancelled for Friday sadly.").isEmpty)
    }

    @Test func aWordAddedOrTakenOutIsNotAMishearing() {
        #expect(last.corrections(in: "The meeting with Shavon has now moved to Thursday.").isEmpty)
    }
}

@Suite("4.5 Snippets: filling themselves in")
struct SnippetFillTests {
    let now = DateComponents(calendar: .current, year: 2026, month: 11, day: 18, hour: 14, minute: 5).date!

    @Test func datesAndTimes() {
        #expect(Snippets.fill("{date}", now: now) == "18 November 2026")
        #expect(Snippets.fill("It's {day} {time}", now: now) == "It's Wednesday 14:05")
        #expect(Snippets.fill("Due {tomorrow}", now: now) == "Due 19 November 2026")
        #expect(Snippets.fill("No braces", now: now) == "No braces")
    }

    @Test func aSnippetFillsInWhenSaid() {
        let snippets = [Snippet(trigger: "today's date", text: "{date}")]
        #expect(Snippets.apply(snippets, to: "Today's date.", now: now) == "18 November 2026")
        #expect(Snippets.apply(snippets, to: "Sent on today's date by post", now: now) == "Sent on 18 November 2026 by post")
    }
}

@Suite("4.6 Spoken commands: code")
struct CodeWordsTests {
    @Test func fileNames() {
        #expect(CodeWords.apply(to: "Open main dot swift please") == "Open main.swift please")
        #expect(CodeWords.apply(to: "Check AppDelegate dot Swift.") == "Check AppDelegate.swift.")
        #expect(CodeWords.apply(to: "Look in the README dot md file") == "Look in the README.md file")
        #expect(CodeWords.apply(to: "I like the dot pattern") == "I like the dot pattern")
    }

    @Test func casedNames() {
        #expect(CodeWords.apply(to: "Rename it to camel case user name.") == "Rename it to userName.")
        #expect(CodeWords.apply(to: "call it snake case max retry count") == "call it max_retry_count")
        #expect(CodeWords.apply(to: "use kebab case main menu and then save") == "use main-menu and then save")
        #expect(CodeWords.apply(to: "I prefer camel case for variables.") == "I prefer camel case for variables.")
        #expect(CodeWords.apply(to: "snake case is fine.") == "snake case is fine.")
        #expect(CodeWords.apply(to: "It uses Node.JS and REPORT.PDF") == "It uses Node.JS and REPORT.PDF")
    }

    @Test func theCodeStyleHasNoAICapitalOrFullStop() {
        #expect(!WritingStyle.code.usesAI)
        let text = Tidy.dictation("Git commit dash m fix the build.", words: [], british: true, style: .code).text
        #expect(text.first == "g")
        #expect(text.last != ".")
    }
}

@Suite("3.5 Keeping recordings for testing")
struct KeptRecordingsTests {
    @Test func olderThanAWeekOrBeyondTwentyGo() {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        var recordings = (0..<22).map { (name: "r\($0)", date: now.addingTimeInterval(-Double($0) * 60)) }
        recordings.append((name: "old", date: now.addingTimeInterval(-8 * 24 * 3600)))
        #expect(Set(KeptRecordings.toDelete(recordings, now: now)) == ["r20", "r21", "old"])
        #expect(KeptRecordings.toDelete([(name: "new", date: now)], now: now).isEmpty)
    }

    @Test func aWavFileHasTheRightSize() {
        let data = KeptRecordings.wav([0, 0.5, -0.5, 1], sampleRate: 16_000)
        #expect(data.count == 44 + 8)
        #expect(data.prefix(4) == Data("RIFF".utf8))
    }

    @Test func namesSortByTime() {
        let date = DateComponents(calendar: .current, year: 2026, month: 11, day: 18, hour: 14, minute: 5, second: 3).date!
        #expect(KeptRecordings.name(for: date) == "2026-11-18 14.05.03")
    }
}

@Suite("4.2 Word list: names from Contacts")
struct NameLearningTests {
    private let dictionary: Set<String> = ["eva", "i", "if", "a"]
    private func entry(_ name: String, _ heard: String) -> WordEntry? {
        NameLearning.entry(name: name, heard: heard, isWord: { dictionary.contains($0.lowercased()) }, names: ["sam", "aoife"])
    }

    @Test func aMisheardNameBecomesAFix() {
        #expect(entry("Siobhan", "Shavon.") == WordEntry(heard: "shavon", written: "Siobhan"))
    }

    @Test func rightAlreadyOrAnOrdinaryWordOrAnotherNameGivesNothing() {
        #expect(entry("Sam", "Sam.") == nil)
        #expect(entry("Aoife", "Eva") == nil)
        #expect(entry("Aoife", "I") == nil)
        #expect(entry("Niamh", "Sam") == nil)
        #expect(entry("Siobhan", "") == nil)
    }

    @Test func eachUsableNameOnce() {
        let contacts = [(given: "Siobhan", family: "O'Neill"), (given: "Sam", family: "Lee"), (given: "siobhan", family: "Hart"),
                        (given: "Dr. X", family: "")]
        let known = [WordEntry(heard: "Hart", written: "Hart")]
        #expect(NameLearning.names(from: contacts, known: known) == ["Siobhan", "O'Neill", "Sam", "Lee"])
    }
}

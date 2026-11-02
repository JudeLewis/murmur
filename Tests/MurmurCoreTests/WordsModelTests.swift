import Foundation
import MurmurCore
import Testing
@testable import MurmurUI

@Suite("4.2 Word list: the screen")
@MainActor
struct WordsModelTests {
    final class Saved {
        var words: [WordEntry]?
        var snippets: [Snippet]?
    }

    private func model(_ words: [WordEntry] = [], _ snippets: [Snippet] = []) -> (WordsModel, Saved) {
        let saved = Saved()
        let model = WordsModel(
            words: words, snippets: snippets, recent: { ["Hello."] },
            saveWords: { saved.words = $0 }, saveSnippets: { saved.snippets = $0 })
        return (model, saved)
    }

    @Test func removalEntriesShowAndSurviveSavingOthers() {
        let (model, saved) = model([WordEntry(heard: "basically", written: "")])
        #expect(model.rows.first?.heard == "basically")
        model.save(WordRow(written: "Clocked In"))
        #expect(saved.words == [WordEntry(heard: "basically", written: ""), WordEntry(heard: "Clocked In", written: "Clocked In")])
    }

    @Test func changingAndDeleting() {
        let (model, saved) = model([WordEntry(heard: "Clocked In", written: "Clocked In")])
        var row = model.rows[0]
        row.heard = "clock din"
        model.save(row)
        #expect(saved.words == [WordEntry(heard: "clock din", written: "Clocked In")])
        model.delete(row)
        #expect(saved.words == [])
    }

    @Test func emptyRowsAreDeletedNotSaved() {
        let (model, saved) = model([WordEntry(heard: "Jude", written: "Jude")])
        var row = model.rows[0]
        row.written = ""
        model.save(row)
        #expect(model.rows.isEmpty)
        #expect(saved.words == [])
    }

    @Test func fixesAreAddedOnce() {
        let (model, saved) = model([WordEntry(heard: "Jude", written: "Jude")])
        model.add([WordEntry(heard: "Jude", written: "Jude"), WordEntry(heard: "jood", written: "Jude")])
        #expect(saved.words == [WordEntry(heard: "Jude", written: "Jude"), WordEntry(heard: "jood", written: "Jude")])
    }

    @Test func snippetsAreTrimmedAndEmptyOnesRemoved() {
        let (model, saved) = model()
        var snippet = Snippet(trigger: "  my email ", text: "jude@example.com")
        model.save(snippet)
        #expect(saved.snippets?.first?.trigger == "my email")
        snippet.text = ""
        model.save(snippet)
        #expect(saved.snippets == [])
    }
}

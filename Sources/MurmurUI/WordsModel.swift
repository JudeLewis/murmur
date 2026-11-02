import Foundation
import MurmurCore
import Observation

/// One word list entry as the screens edit it.
public struct WordRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// "Write it as".
    public var written: String
    /// "When it hears", empty when it's the same as `written`.
    public var heard: String

    public init(id: UUID = UUID(), written: String = "", heard: String = "") {
        self.id = id
        self.written = written
        self.heard = heard
    }

    public init(_ entry: WordEntry) {
        self.init(written: entry.written, heard: entry.heard == entry.written ? "" : entry.heard)
    }

    /// Nil while there's nothing to save (see WordEntry.fromForm).
    public var entry: WordEntry? { WordEntry.fromForm(written: written, heard: heard) }
}

/// The word list and snippets, shared by the Mac window and the iPhone app.
/// Each platform says where they are kept; every change is saved straight away.
@MainActor
@Observable
public final class WordsModel {
    public private(set) var rows: [WordRow]
    public private(set) var snippets: [Snippet]
    @ObservationIgnored public let recent: () -> [String]
    @ObservationIgnored private let saveWords: ([WordEntry]) -> Void
    @ObservationIgnored private let saveSnippets: ([Snippet]) -> Void

    public init(
        words: [WordEntry], snippets: [Snippet], recent: @escaping () -> [String],
        saveWords: @escaping ([WordEntry]) -> Void, saveSnippets: @escaping ([Snippet]) -> Void
    ) {
        self.rows = words.map(WordRow.init)
        self.snippets = snippets
        self.recent = recent
        self.saveWords = saveWords
        self.saveSnippets = saveSnippets
    }

    public func save(_ row: WordRow) {
        guard row.entry != nil else { return delete(row) }
        if let index = rows.firstIndex(where: { $0.id == row.id }) { rows[index] = row } else { rows.append(row) }
        saveWords(rows.compactMap(\.entry))
    }

    public func delete(_ row: WordRow) {
        rows.removeAll { $0.id == row.id }
        saveWords(rows.compactMap(\.entry))
    }

    public func add(_ entries: [WordEntry]) {
        for entry in entries where !rows.contains(where: { $0.entry == entry }) { rows.append(WordRow(entry)) }
        saveWords(rows.compactMap(\.entry))
    }

    public func save(_ snippet: Snippet) {
        let trigger = snippet.trigger.trimmingCharacters(in: .whitespaces)
        guard !trigger.isEmpty, !snippet.text.isEmpty else { return delete(snippet) }
        var cleaned = snippet
        cleaned.trigger = trigger
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) { snippets[index] = cleaned } else { snippets.append(cleaned) }
        saveSnippets(snippets)
    }

    public func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets(snippets)
    }
}

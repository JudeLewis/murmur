import Foundation

/// Turns what the speech model wrote into the text that gets pasted.
public enum Tidy {
    /// Order matters: British spelling first, then the user's word list, so the
    /// user's own entries always have the last say.
    public static func finish(_ raw: String, words: [WordEntry], british: Bool) -> String {
        var text = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Silence sometimes comes back as a lone full stop.
        if text.allSatisfy({ $0.isPunctuation || $0.isWhitespace }) { return "" }

        // Dropping a filler at the start ("So, um, I...") can leave a small first
        // letter. Words with a capital inside (iPhone, eBay) are left alone.
        let firstWord = text.prefix(while: { !$0.isWhitespace })
        if let first = firstWord.first, first.isLowercase, !firstWord.contains(where: \.isUppercase) {
            text = first.uppercased() + text.dropFirst()
        }

        if british { text = BritishSpelling.apply(to: text) }
        text = WordList.apply(words, to: text)
        return text
    }

    /// A space after each dictation, so the next one starts a new word
    /// instead of running on from the last ("Hello there.How are you?").
    /// Not after a line break, or when Return is pressed next.
    public static func forInsertion(_ text: String, pressEnter: Bool = false) -> String {
        if text.isEmpty || pressEnter || text.last?.isNewline == true { return text }
        return text + " "
    }

    /// On iPhone the keyboard can see the text before the cursor, so it also
    /// adds a space in front when the dictation would otherwise join the word
    /// or punctuation there. Not after an opening bracket, quote, @, # or /.
    public static func forInsertion(_ text: String, after before: String?, pressEnter: Bool = false) -> String {
        guard !text.isEmpty else { return "" }
        let joins = before?.last.map { $0.isLetter || $0.isNumber || ".,!?;:%)]}\u{201D}\u{2019}\u{2026}".contains($0) } ?? false
        let startsOnNewLine = text.first?.isNewline == true
        return (joins && !startsOnNewLine ? " " : "") + forInsertion(text, pressEnter: pressEnter)
    }
}

/// The last few dictations, newest first, so a missed paste is never lost.
public struct RecentList: Equatable, Sendable {
    public private(set) var items: [String]
    public let limit: Int

    public init(items: [String] = [], limit: Int = 20) {
        self.limit = limit
        self.items = Array(items.prefix(limit))
    }

    public mutating func add(_ text: String) {
        guard !text.isEmpty else { return }
        items.insert(text, at: 0)
        if items.count > limit { items.removeLast(items.count - limit) }
    }
}

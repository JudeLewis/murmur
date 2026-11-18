import Foundation

/// The last dictation Murmur put in, exactly as typed or pasted (with the space in front or
/// after), so it can be taken out again (SPEC.md 2.11), rewritten by voice (2.7), and compared
/// later with what's in the box to spot words you corrected (4.2).
public struct LastDictation: Equatable, Sendable {
    public let text: String
    /// The app it went into.
    public let app: String?
    public let at: Date

    public init(text: String, app: String?, at: Date = .now) {
        self.text = text
        self.app = app
        self.at = at
    }

    /// How many characters to delete to take it out, or nil if the cursor isn't straight after
    /// it (you've typed or clicked somewhere since, or the app doesn't say).
    public func charactersToRemove(before: String?) -> Int? {
        guard let before, !text.isEmpty else { return nil }
        if before.hasSuffix(text) { return text.count }
        // Some apps drop a space at the very end.
        var trimmed = text
        while let last = trimmed.last, last == " " { trimmed.removeLast() }
        if !trimmed.isEmpty, trimmed != text, before.hasSuffix(trimmed) { return trimmed.count }
        return nil
    }

    /// The dictation without the spaces Murmur added around it.
    public var words: String { text.trimmingCharacters(in: .whitespaces) }

    /// Whether a Command Mode instruction with nothing selected is about the last dictation:
    /// "make that more formal", "translate it into French", "shorten this". Asking for new
    /// text ("write a polite no thanks", "draft a reply about it") isn't.
    public static func isAboutIt(_ instruction: String) -> Bool {
        let words = instruction.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        guard let first = words.first else { return false }
        let writesNew: Set<String> = ["write", "draft", "compose", "create", "suggest", "reply", "generate", "give", "tell", "list"]
        if writesNew.contains(first) { return false }
        let pointers: Set<String> = ["that", "it", "this", "previous", "last"]
        return words.contains { pointers.contains($0) }
            || instruction.lowercased().contains("what i said") || instruction.lowercased().contains("what i just said")
    }

    /// The dictation as it stands in the box now (`field` is the box's whole text), found by its
    /// words, if it's still mostly there. Used to spot corrections; nil if it's gone, or
    /// changed so much it was rewritten rather than corrected.
    public func asItStands(in field: String) -> String? {
        let said = Self.tokens(words)
        let all = field.split(whereSeparator: \.isWhitespace).map(String.init)
        let plain = all.map(Self.plain)
        guard said.count >= 3, !plain.isEmpty else { return nil }
        var best: (score: Int, start: Int, length: Int)?
        for start in plain.indices {
            // Only start where one of the first few words is, to keep it quick.
            guard said.prefix(3).contains(plain[start]) || start == 0 else { continue }
            for length in max(1, said.count - 3)...(said.count + 3) where start + length <= plain.count {
                let score = Self.common(said, Array(plain[start..<(start + length)]))
                if best == nil || score > best!.score || (score == best!.score && abs(length - said.count) < abs(best!.length - said.count)) {
                    best = (score, start, length)
                }
            }
        }
        // Three quarters of the words still there and in order.
        guard let best, best.score * 4 >= said.count * 3 else { return nil }
        return all[best.start..<(best.start + best.length)].joined(separator: " ")
    }

    /// Word list fixes from what you changed in the dictation, if you only changed a word or two.
    public func corrections(in field: String) -> [WordEntry] {
        guard let now = asItStands(in: field), Self.tokens(now) != Self.tokens(words) else { return [] }
        let found = WordFix.suggest(original: words, edited: now)
        // More than two changes looks like rewriting, not fixing misheard words.
        guard (1...2).contains(found.count) else { return [] }
        return found.filter { entry in
            // A word taken out or added isn't a mishearing.
            !entry.heard.isEmpty && !entry.written.isEmpty && entry.heard.split(separator: " ").count <= 3
        }
    }

    static func plain(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.symbols))
    }

    static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map { plain(String($0)) }.filter { !$0.isEmpty }
    }

    /// The longest run of words the two have in common, in order.
    static func common(_ a: [String], _ b: [String]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var row = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            var diagonal = 0
            for j in 1...b.count {
                let above = row[j]
                row[j] = a[i - 1] == b[j - 1] ? diagonal + 1 : max(row[j], row[j - 1])
                diagonal = above
            }
        }
        return row[b.count]
    }
}

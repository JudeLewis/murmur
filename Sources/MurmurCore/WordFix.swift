/// Spots word list entries in a dictation the user has corrected: compare
/// what Murmur wrote with the fixed version and pick out the words that changed.
public enum WordFix {
    /// Short changes only (up to four words each side), so rewording a sentence
    /// doesn't become a word list entry. A change in capitals only ("clocked in"
    /// to "Clocked In") becomes an "always write it like this" entry.
    public static func suggest(original: String, edited: String) -> [WordEntry] {
        let before = tokens(original)
        let after = tokens(edited)
        var found: [WordEntry] = []
        for (heard, written) in changes(before, after) where (1...4).contains(heard.count) && (1...4).contains(written.count) {
            let heardText = heard.joined(separator: " ")
            let writtenText = written.joined(separator: " ")
            let entry = heardText.lowercased() == writtenText.lowercased()
                ? WordEntry(heard: writtenText, written: writtenText)
                : WordEntry(heard: heardText, written: writtenText)
            if !found.contains(entry) { found.append(entry) }
        }
        return found
    }

    /// Words with the punctuation around them taken off ("Flow." is "Flow").
    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    /// Each run of removed words with the words that replaced it, from the
    /// longest common sequence of words.
    private static func changes(_ a: [String], _ b: [String]) -> [([String], [String])] {
        var common = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                common[i][j] = a[i] == b[j] ? common[i + 1][j + 1] + 1 : max(common[i + 1][j], common[i][j + 1])
            }
        }
        var result: [([String], [String])] = []
        var removed: [String] = [], added: [String] = []
        var i = 0, j = 0
        func close() {
            if !removed.isEmpty || !added.isEmpty { result.append((removed, added)) }
            removed = []
            added = []
        }
        while i < a.count || j < b.count {
            if i < a.count, j < b.count, a[i] == b[j] {
                close()
                i += 1
                j += 1
            } else if j < b.count, i == a.count || common[i][j + 1] >= common[i + 1][j] {
                added.append(b[j])
                j += 1
            } else {
                removed.append(a[i])
                i += 1
            }
        }
        close()
        return result
    }
}

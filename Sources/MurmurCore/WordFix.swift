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

/// Names from Contacts (SPEC.md 4.2): each name is said with the Mac's voice and heard by the
/// speech model; a name it writes differently becomes a word list fix.
public enum NameLearning {
    /// The names worth trying: first and last names of three letters or more, letters only
    /// (with a hyphen or apostrophe), each once, not already in the word list.
    public static func names(from contacts: [(given: String, family: String)], known words: [WordEntry]) -> [String] {
        let spelt = Set(words.map { $0.written.lowercased() })
        var seen = Set<String>()
        var result: [String] = []
        for contact in contacts {
            for part in [contact.given, contact.family] {
                let name = part.trimmingCharacters(in: .whitespaces)
                guard name.count >= 3, name.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" || $0 == "\u{2019}" }),
                      !spelt.contains(name.lowercased()), seen.insert(name.lowercased()).inserted else { continue }
                result.append(name)
            }
        }
        return result
    }

    /// A fix if the speech model heard `name` as something else, and that something isn't an
    /// ordinary word or another contact's name (a fix for "Eva" or "I" would change real words).
    public static func entry(name: String, heard: String, isWord: (String) -> Bool, names: Set<String>) -> WordEntry? {
        let plain = heard.split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
        guard (1...3).contains(plain.count) else { return nil }
        let text = plain.joined(separator: " ")
        guard text.lowercased() != name.lowercased(), text.filter(\.isLetter).count >= 3,
              !names.contains(text.lowercased()), !plain.allSatisfy(isWord) else { return nil }
        return WordEntry(heard: text.lowercased(), written: name)
    }
}

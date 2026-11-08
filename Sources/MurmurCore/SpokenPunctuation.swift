import Foundation

/// Punctuation said out loud (SPEC.md 4.6): "question mark" becomes "?", and so on.
/// What the model guessed around the words goes, since what was said wins.
public enum SpokenPunctuation {
    /// Only "exclamation" may have a guessed comma inside ("exclamation, Mark"): "full. Stop by
    /// later" and "Good question. Mark is right" are two sentences that happen to meet.
    private static let phrases = "question[ -]mark|exclamation[,.]?[ -](?:mark|point)|full[ -]stop|comma|semi[ -]?colon|colon|dot[,.]? dot[,.]? dot|ellipsis"
    private static let notInsideAWord = "[\\p{L}\\p{N}'\u{2019}-]"
    private static let modelPunctuation = ",.;:!?"

    /// Before the words, these mean they're being talked about: "a question mark", "the Oxford comma".
    /// Only words that must have a noun after them: "do you like this question mark" means the symbol.
    private static let namingWords: Set<String> = [
        "a", "an", "the", "my", "your", "our", "their", "its", "big", "huge", "massive", "giant", "oxford", "serial", "inverted",
        "double",
    ]
    /// After the words, these do the same: "colon cancer", "comma separated".
    private static let namingNext: Set<String> = ["cancer", "splice", "separated", "key", "button"]
    /// Small words the model may have given a capital, having guessed a new sentence after "comma".
    private static let usuallySmall: Set<String> = [
        "and", "but", "or", "so", "then", "because", "the", "a", "an", "which", "that", "who", "when", "if", "as", "we", "you",
        "he", "she", "they", "it",
    ]

    public static func apply(to text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "(?<!\(notInsideAWord))(?:\(phrases))(?!\(notInsideAWord))", options: [.caseInsensitive]) else { return text }
        var result = ""
        var position = text.startIndex
        var lastMark: String?
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text), range.lowerBound >= position, !isTalkedAbout(range, in: text) else { continue }
            let between = text[position..<range.lowerBound]
            // Two in a row ("question mark exclamation mark") are both kept.
            if lastMark == nil || !between.allSatisfy({ modelPunctuation.contains($0) || $0 == " " }) {
                result = joined(result, between, after: lastMark)
                while let last = result.last, modelPunctuation.contains(last) || last == " " { result.removeLast() }
            }
            let mark = symbol(for: String(text[range]))
            result += mark
            lastMark = mark
            position = text[range.upperBound...].firstIndex { !modelPunctuation.contains($0) && $0 != " " } ?? text.endIndex
        }
        guard lastMark != nil else { return text }
        return joined(result, text[position...], after: lastMark)
    }

    private static func symbol(for phrase: String) -> String {
        let lower = phrase.lowercased()
        if lower.hasPrefix("question") { return "?" }
        if lower.hasPrefix("exclamation") { return "!" }
        if lower.hasPrefix("full") { return "." }
        if lower.hasPrefix("comma") { return "," }
        if lower.hasPrefix("semi") { return ";" }
        if lower.hasPrefix("colon") { return ":" }
        return "..."
    }

    private static func isTalkedAbout(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = text[..<range.lowerBound]
        if before.last == " " {
            let word = before.dropLast().reversed().prefix { $0.isLetter }
            if namingWords.contains(String(word.reversed()).lowercased()) { return true }
        }
        let after = text[range.upperBound...]
        guard after.first == " " || after.first == "-" else { return false }
        return namingNext.contains(after.dropFirst().prefix { $0.isLetter }.lowercased())
    }

    /// Adds what came after a spoken mark, with a space and the right capital.
    private static func joined(_ result: String, _ next: Substring, after mark: String?) -> String {
        guard let mark, !next.isEmpty else { return result + next }
        let word = next.prefix { $0.isLetter }
        var changed = String(next)
        if let first = word.first, !word.dropFirst().contains(where: \.isUppercase) {
            if ".?!".contains(mark), first.isLowercase {
                changed = first.uppercased() + next.dropFirst()
            } else if ",;:".contains(mark), first.isUppercase, usuallySmall.contains(word.lowercased()) {
                changed = first.lowercased() + next.dropFirst()
            }
        }
        return result + " " + changed
    }
}

/// Full stops that can't be real (SPEC.md 4.3): one before a small letter
/// ("I haven't. worked"), or after a word no sentence ends on ("the. Whole").
public enum StrayStops {
    private static let neverEndASentence: Set<String> = ["a", "an", "the", "and", "but", "or", "my", "your", "our", "their"]
    private static let abbreviations: Set<String> = [
        "etc", "vs", "mr", "mrs", "ms", "dr", "st", "approx", "no", "inc", "ltd", "jr", "sr", "eg", "ie", "prof",
    ]
    private static let notNames: Set<String> = ["I", "I'm", "I've", "I'll", "I'd", "I\u{2019}m", "I\u{2019}ve", "I\u{2019}ll", "I\u{2019}d"]
    /// Spoken commands that need the punctuation in front of them (SPEC.md 4.6).
    private static let commands = ["new line", "new paragraph", "scratch that"]

    /// `words` is the word list: a name from it keeps its capital.
    public static func remove(from text: String, keeping words: [WordEntry] = []) -> String {
        var characters = Array(text)
        guard characters.count > 3 else { return text }
        // From the end, so a removal doesn't move what's still to check.
        for dot in stride(from: characters.count - 3, through: 1, by: -1) {
            guard characters[dot] == ".", characters[dot + 1] == " ", characters[dot + 2].isLetter,
                  isWordEnd(characters[dot - 1]) else { continue }
            var start = dot
            while start > 0, !characters[start - 1].isWhitespace { start -= 1 }
            let before = String(characters[start..<dot])
            var end = dot + 2
            while end < characters.count, characters[end].isLetter || characters[end] == "'" || characters[end] == "\u{2019}" { end += 1 }
            let after = String(characters[(dot + 2)..<end])
            let rest = String(characters[(dot + 2)...]).lowercased()
            guard !commands.contains(where: rest.hasPrefix) else { continue }
            let hasInnerCapital = after.dropFirst().contains(where: \.isUppercase)

            if neverEndASentence.contains(before) {
                characters.remove(at: dot)
                let isListedName = words.contains { $0.written.first?.isUppercase == true && ($0.written == after || $0.written.hasPrefix(after + " ")) }
                if !notNames.contains(after), !hasInnerCapital, !isListedName {
                    characters[dot + 1] = Character(characters[dot + 1].lowercased())
                }
                continue
            }
            // Keep abbreviations and initials: "e.g.", "a.m.", "U.S.", "Mr.", "P A."
            guard !before.contains("."), before.count > 1, !abbreviations.contains(before.lowercased()) else { continue }
            if characters[dot + 2].isLowercase, !hasInnerCapital { characters.remove(at: dot) }
        }
        return String(characters)
    }

    private static func isWordEnd(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "'" || character == "\u{2019}"
    }
}

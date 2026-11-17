import Foundation

/// Brackets, quotes and slashes said out loud (SPEC.md 4.6): "open bracket" becomes "(".
/// Unlike full stops and commas, these join onto a word on one side: "(" and "“" onto the
/// word after, ")" and "”" onto the word before, and "/" onto both. Runs before
/// SpokenPunctuation, so the only marks it trims are ones the model guessed.
public enum SpokenSymbols {
    private enum Side { case opening, closing, joining }

    private static let quoteWords = "(?:quotes?|quotation[ -]marks?|speech[ -]marks)"
    /// Opening forms are singular ("open bracket"), so "keep open brackets for now" stays as said.
    private static let kinds: [(pattern: String, symbol: String, side: Side)] = [
        ("open(?:ing)?[ -]square[ -]bracket", "[", .opening),
        ("(?:close|closed|closing|end)[ -]square[ -]brackets?", "]", .closing),
        ("open(?:ing)?[ -](?:round[ -])?(?:bracket|paren|parenthesis)", "(", .opening),
        ("(?:close|closed|closing|end)[ -](?:round[ -])?(?:brackets?|parens?|parenthes[ie]s)", ")", .closing),
        ("open(?:ing)?[ -](?:quote|quotation[ -]mark|speech[ -]marks)", "\u{201C}", .opening),
        // "quote ... unquote": a bare "quote" opens only when an "unquote" follows, and not
        // straight away ("quote unquote" is a figure of speech).
        ("quote(?![,.]? +unquote)(?=(?:(?!\\bquote\\b).)*?\\bunquote\\b)", "\u{201C}", .opening),
        ("(?:close|closed|closing|end)[ -]\(quoteWords)|unquote", "\u{201D}", .closing),
        ("forward[ -]slash", "/", .joining),
    ]
    private static let notInsideAWord = "[\\p{L}\\p{N}'\u{2019}-]"
    nonisolated(unsafe) private static let regex = try? NSRegularExpression(
        pattern: "(?<!\(notInsideAWord))(?:\(kinds.map { "(\($0.pattern))" }.joined(separator: "|")))(?!\(notInsideAWord))",
        options: [.caseInsensitive])
    /// Guessed by the model at a pause; what was said wins.
    private static let guessed: Set<Character> = [",", ".", ";", ":"]
    /// Before the words, these mean they're being talked about: "a close bracket", "the open quote".
    private static let namingWords: Set<String> = ["a", "an", "the", "my", "your", "our", "their", "its", "this", "that"]

    public static func apply(to text: String) -> String {
        guard let regex else { return text }
        var result = ""
        var position = text.startIndex
        var changed = false
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text), range.lowerBound >= position,
                  let kind = (0..<kinds.count).first(where: { match.range(at: $0 + 1).location != NSNotFound }).map({ kinds[$0] }),
                  !isTalkedAbout(range, in: text) else { continue }
            result += text[position..<range.lowerBound]
            var after = range.upperBound
            switch kind.side {
            case .opening:
                trimEnd(&result, dropping: [",", ";", ":"])
                if let last = result.last, !last.isNewline, !"([\u{201C}/".contains(last) { result += " " }
                result += kind.symbol
                after = skip(from: after, in: text, dropping: guessed)
            case .closing:
                trimEnd(&result, dropping: guessed)
                result += kind.symbol
                after = skip(from: after, in: text, dropping: [])
                if after < text.endIndex, text[after].isLetter || text[after].isNumber || "(\u{201C}".contains(text[after]) { result += " " }
            case .joining:
                trimEnd(&result, dropping: guessed)
                result += kind.symbol
                after = skip(from: after, in: text, dropping: guessed)
            }
            position = after
            changed = true
        }
        guard changed else { return text }
        return result + text[position...]
    }

    private static func trimEnd(_ text: inout String, dropping marks: Set<Character>) {
        // Only one mark goes, so an ellipsis keeps two of its dots at worst.
        while let last = text.last, last == " " || marks.contains(last) {
            text.removeLast()
            if marks.contains(last) { break }
        }
        while text.last == " " { text.removeLast() }
    }

    private static func skip(from index: String.Index, in text: String, dropping marks: Set<Character>) -> String.Index {
        var index = index
        while index < text.endIndex, text[index] == " " || marks.contains(text[index]) { index = text.index(after: index) }
        return index
    }

    private static func isTalkedAbout(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = text[..<range.lowerBound]
        let word = String(before.reversed().drop { $0 == " " || $0 == "," }.prefix { $0.isLetter }.reversed()).lowercased()
        // "It was, quote, unquote, fine" is a figure of speech, not a closing quote.
        if word == "quote", text[range].lowercased() == "unquote" { return true }
        return before.last == " " && namingWords.contains(word)
    }
}

/// Letters the model wrote one by one (SPEC.md 4.3): "the N H S" becomes "the NHS".
public enum SpeltLetters {
    /// Not next to a hyphen either, so "A T-shirt" stays as it is.
    nonisolated(unsafe) private static let regex = try? NSRegularExpression(
        pattern: "(?<![\\p{L}\\p{N}'\u{2019}.-])[A-Z](?: [A-Z])+(?![\\p{L}\\p{N}'\u{2019}-])")

    public static func join(_ text: String) -> String {
        guard let regex else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            var letters = result[range].split(separator: " ").map(String.init)
            // A last "I" is the word I ("the N H S I think", "Plan B I think").
            var (head, tail) = ("", "")
            if letters.last == "I" { letters.removeLast(); tail = " I" }
            if letters.count > 2, letters.first == "I" { letters.removeFirst(); head = "I " }
            result.replaceSubrange(range, with: head + letters.joined(separator: letters.count > 1 ? "" : " ") + tail)
        }
        return result
    }
}

/// Two marks the model left side by side (SPEC.md 4.3): "issues., and" becomes "issues, and".
/// An ellipsis and an abbreviation's own full stop ("etc.,") stay.
public enum DoubledMarks {
    private static let abbreviations: Set<String> = ["etc", "vs", "approx", "inc", "ltd", "eg", "ie", "mr", "mrs", "ms", "dr", "prof"]

    public static func remove(from text: String) -> String {
        var characters = Array(text)
        var index = characters.count - 2
        while index >= 0 {
            let (first, second) = (characters[index], characters[index + 1])
            let partOfEllipsis = (index > 0 && characters[index - 1] == ".") || (index + 2 < characters.count && characters[index + 2] == ".")
            switch (first, second) {
            case (".", ","), (".", ";"), (".", ":"):
                if !endsAnAbbreviation(characters, at: index) { characters.remove(at: index) }
            case (".", "."):
                if !partOfEllipsis { characters.remove(at: index) }
            case ("?", "."), ("!", "."):
                if !partOfEllipsis { characters.remove(at: index + 1) }
            case (",", "."), (";", "."), (":", "."):
                // Mid-sentence ("Hello,. and then") the comma was right; otherwise the full stop.
                guard !partOfEllipsis else { break }
                characters.remove(at: nextWordIsSmall(characters, after: index + 1) ? index + 1 : index)
            case (",", ","), (",", ";"), (",", ":"):
                characters.remove(at: index)
            default:
                break
            }
            index -= 1
        }
        return String(characters)
    }

    private static func endsAnAbbreviation(_ characters: [Character], at dot: Int) -> Bool {
        var start = dot
        while start > 0, !characters[start - 1].isWhitespace { start -= 1 }
        let word = String(characters[start..<dot])
        return word.contains(".") || abbreviations.contains(word.lowercased())
    }

    private static func nextWordIsSmall(_ characters: [Character], after index: Int) -> Bool {
        characters[(index + 1)...].first { !$0.isWhitespace }?.isLowercase == true
    }
}

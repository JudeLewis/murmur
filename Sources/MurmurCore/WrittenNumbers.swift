import Foundation

/// Numbers written the British way by fixed rules (SPEC.md 4.3), so the clear cases come out
/// the same every time, with or without the AI tidy-up: money, percentages, years, times after
/// "at", and anything over ten become digits; one to ten in ordinary sentences stay as words.
/// Cases that need the sentence's sense ("after six") are left to the AI tidy-up.
public enum WrittenNumbers {
    private static let numberWords: [String] = Array(SpokenNumbers.units.keys) + Array(SpokenNumbers.tens.keys)
        + Array(SpokenNumbers.scales.keys) + ["second"]
    /// A run of number words, joined by spaces, hyphens or "and" ("two hundred and fifty", "twenty-six").
    nonisolated(unsafe) private static let regex: NSRegularExpression? = {
        let word = "(?:" + numberWords.sorted { $0.count > $1.count }.joined(separator: "|") + ")"
        return try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}'\u{2019}-])\(word)(?:(?:[ -]|,? and )\(word))*(?![\\p{L}\\p{N}'\u{2019}])",
            options: [.caseInsensitive])
    }()

    private static let months: Set<String> = [
        "january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december",
    ]
    /// Words before a year: "in 2019", "since 1998", "June 2026", "summer 2024".
    private static let beforeYear: Set<String> = ["in", "since", "from", "until", "till", "by", "of", "before", "after", "around",
                                                   "spring", "summer", "autumn", "winter", "early", "late", "mid"]
    /// Words before a time: "at 7:45", "from 3:30".
    private static let beforeTime: Set<String> = ["at", "from", "until", "till", "by", "before", "after", "around", "about", "between"]
    /// Before a number of pounds, these make it a weight: "lost ten pounds".
    private static let weighing: Set<String> = ["lost", "lose", "losing", "gained", "gain", "gaining", "weigh", "weighs",
                                                 "weighed", "weighing", "put", "heavier", "lighter", "about"]

    /// Digits already written with the unit as a word: "15 per cent" to "15%", "20 pounds" to "£20".
    nonisolated(unsafe) private static let digitUnits = try? NSRegularExpression(
        pattern: "(?<![\\p{L}\\p{N}£.,])(\\d[\\d,]*) ?(?:per cent|percent)(?![\\p{L}])", options: [.caseInsensitive])
    nonisolated(unsafe) private static let digitPounds = try? NSRegularExpression(
        pattern: "(?<![\\p{L}\\p{N}£.,])(\\d[\\d,]*) (?:pounds|quid)(?! of)(?![\\p{L}])", options: [.caseInsensitive])

    public static func apply(to text: String) -> String {
        guard let regex else { return text }
        var result = text
        let whole = { NSRange(result.startIndex..., in: result) }
        if let digitUnits { result = digitUnits.stringByReplacingMatches(in: result, range: whole(), withTemplate: "$1%") }
        if let digitPounds { result = digitPounds.stringByReplacingMatches(in: result, range: whole(), withTemplate: "£$1") }
        let spelt = result
        for match in regex.matches(in: spelt, range: NSRange(spelt.startIndex..., in: spelt)).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let run = String(result[range])
            let words = run.lowercased().split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "," }).map(String.init)
            let before = word(before: range, in: result)
            let (after, afterRange) = word(after: range, in: result)
            let afterNext = afterRange.map { word(after: $0, in: result).0 } ?? ""
            guard let written = write(words, before: before, after: after, afterNext: afterNext) else { continue }
            var replacing = range
            if written.swallowsNext, let afterRange { replacing = range.lowerBound..<afterRange.upperBound }
            if written.swallowsArticle, let articleRange = article(before: range, in: result) { replacing = articleRange.lowerBound..<replacing.upperBound }
            result.replaceSubrange(replacing, with: written.text)
        }
        return result
    }

    private struct Written {
        var text: String
        var swallowsNext = false
        var swallowsArticle = false
    }

    private static func write(_ words: [String], before: String, after: String, afterNext: String) -> Written? {
        var numbers: [(value: Int, words: [String])] = []
        var index = 0
        while index < words.count {
            if words[index] == "and" {
                // "two hundred and fifty" is one number; "between eleven and twelve" is a range: left as said.
                guard index > 0, SpokenNumbers.scales[words[index - 1]] != nil else { return nil }
                index += 1
                continue
            }
            guard let (value, used) = SpokenNumbers.number(at: index, in: words) else { return nil }
            numbers.append((value, Array(words[index..<(index + used)])))
            index += used
        }
        guard !numbers.isEmpty else { return nil }

        if numbers.count == 2 {
            let (first, second) = (numbers[0], numbers[1])
            // "twenty twenty-six" after "in" or a month is 2026; "nineteen ninety-eight" is 1998.
            // Only 1900 to 2099, so "from eleven thirty" is a time, not the year 1130.
            if [19, 20].contains(first.value), (10...99).contains(second.value), months.contains(before) || beforeYear.contains(before),
               !isOrdinal(second.words) {
                return Written(text: String(first.value * 100 + second.value))
            }
            // "at seven forty-five" is 7:45.
            if (1...12).contains(first.value), (10...59).contains(second.value), beforeTime.contains(before), !isOrdinal(second.words) {
                return Written(text: "\(first.value):\(second.value)")
            }
            return nil
        }
        guard numbers.count == 1, let number = numbers.first else { return nil }
        let value = number.value
        // "a hundred" and "a million" on their own stay as said ("one in a million").
        let bareScale = number.words.allSatisfy { SpokenNumbers.scales[$0] != nil }
        switch after {
        case "pounds" where afterNext == "of" || weighing.contains(before):
            return nil  // "five pounds of flour", "lost ten pounds": a weight
        case "pound":
            return nil  // "a twelve pound turkey" or "a five pound note": can't tell
        case "pounds", "quid":
            return Written(text: "£" + grouped(value), swallowsNext: true, swallowsArticle: bareScale)
        case "pence":
            return Written(text: "\(value)p", swallowsNext: true)
        case "percent":
            return Written(text: grouped(value) + "%", swallowsNext: true, swallowsArticle: bareScale)
        case "pm":
            return (1...12).contains(value) ? Written(text: String(value)) : nil
        case "am":
            // Not the verb: "which one am I" stays.
            return (1...12).contains(value) && beforeTime.contains(before) ? Written(text: String(value)) : nil
        default:
            break
        }
        guard !bareScale, value > 10 else { return nil }
        // A year said as one number ("two thousand and five") after "in" has no comma.
        if (1000...2100).contains(value), months.contains(before) || beforeYear.contains(before) { return Written(text: String(value)) }
        if isOrdinal(number.words) { return Written(text: String(value) + suffix(value)) }
        return Written(text: grouped(value))
    }

    private static func isOrdinal(_ words: [String]) -> Bool {
        guard let last = words.last else { return false }
        return last == "first" || last == "second" || last == "third" || last.hasSuffix("th")
    }

    private static func suffix(_ value: Int) -> String {
        if (11...13).contains(value % 100) { return "th" }
        switch value % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    /// 2,500 and 1,000,000, as British writing groups them; 10 to 999 as they are.
    private static func grouped(_ value: Int) -> String {
        let digits = String(value)
        guard digits.count > 3 else { return digits }
        var result = ""
        for (offset, digit) in digits.reversed().enumerated() {
            if offset > 0, offset % 3 == 0 { result.append(",") }
            result.append(digit)
        }
        return String(result.reversed())
    }

    private static func word(before range: Range<String.Index>, in text: String) -> String {
        let before = text[..<range.lowerBound]
        guard before.last == " " else { return "" }
        return String(before.dropLast().reversed().prefix { $0.isLetter }.reversed()).lowercased()
    }

    private static func word(after range: Range<String.Index>, in text: String) -> (String, Range<String.Index>?) {
        let rest = text[range.upperBound...]
        guard rest.first == " " else { return ("", nil) }
        let start = rest.index(after: rest.startIndex)
        var end = start
        while end < text.endIndex, text[end].isLetter { end = text.index(after: end) }
        var word = String(text[start..<end]).lowercased()
        var wordRange = start..<end
        // "per cent" is one word here.
        if word == "per", text[end...].lowercased().hasPrefix(" cent") {
            let centEnd = text.index(end, offsetBy: 5)
            if centEnd == text.endIndex || !text[centEnd].isLetter { word = "percent"; wordRange = start..<centEnd }
        }
        return (word, wordRange)
    }

    /// "a hundred pounds" is £100: the "a" goes too.
    private static func article(before range: Range<String.Index>, in text: String) -> Range<String.Index>? {
        let before = text[..<range.lowerBound]
        for article in ["a ", "A "] where before.hasSuffix(article) {
            let start = text.index(range.lowerBound, offsetBy: -2)
            if start == text.startIndex || !text[text.index(before: start)].isLetter { return start..<range.lowerBound }
        }
        return nil
    }
}

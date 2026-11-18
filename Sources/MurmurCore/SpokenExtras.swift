import Foundation

/// "Literal" before a spoken command keeps it as words (SPEC.md 4.6): "literal comma" writes
/// "comma", "literal new line" writes "new line". Only before a command, so "a literal
/// translation" stays as said. Idea from FluidVoice (researched 18 Nov 2026).
public enum Literal {
    /// Put inside each protected word, so no rule recognises it; taken out at the very end.
    static let joiner: Character = "\u{2060}"

    private static let commands = [
        "question mark", "exclamation mark", "exclamation point", "full stop", "semicolon", "semi colon", "colon", "comma",
        "ellipsis", "dot dot dot", "new line", "new paragraph", "press enter", "press return", "scratch that",
        "open bracket", "close bracket", "open square bracket", "close square bracket", "open quote", "close quote",
        "end quote", "unquote", "quote", "forward slash", "open paren", "close paren",
    ] + Emoji.names.keys.map { "\($0) emoji" }

    nonisolated(unsafe) private static let regex: NSRegularExpression? = {
        let phrases = commands.sorted { $0.count > $1.count }.map { NSRegularExpression.escapedPattern(for: $0) }
        return try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])literal[,.]? (\(phrases.joined(separator: "|")))(?![\\p{L}\\p{N}])", options: [.caseInsensitive])
    }()

    /// A word with the hidden mark after its first letter: "c\u{2060}omma".
    private static func hide(_ phrase: Substring) -> String {
        phrase.split(separator: " ", omittingEmptySubsequences: false).map { word in
            word.isEmpty ? "" : String(word.prefix(1)) + String(joiner) + word.dropFirst()
        }.joined(separator: " ")
    }

    /// The protected phrases in `text`, as plain words: ["comma", "new line"].
    public static func phrases(in text: String) -> [String] {
        guard text.contains(joiner) else { return [] }
        let pattern = "\\S*\u{2060}\\S*(?: \\S*\u{2060}\\S*)*"
        guard let found = try? NSRegularExpression(pattern: pattern) else { return [] }
        return found.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range, in: text).map { release(String(text[$0])).trimmingCharacters(in: .punctuationCharacters) }
        }
    }

    /// `phrases` protected again in the AI's answer, or nil if one of them is missing from it.
    public static func protectAgain(_ phrases: [String], in answer: String) -> String? {
        var result = answer
        var from = result.startIndex
        for phrase in phrases {
            guard let found = result.range(of: phrase, options: [.caseInsensitive], range: from..<result.endIndex) else { return nil }
            let hidden = hide(result[found])
            result.replaceSubrange(found, with: hidden)
            from = result.index(found.lowerBound, offsetBy: hidden.count)
        }
        return result
    }

    /// "literal comma" to "comma", with a hidden mark inside so the rules after leave it alone.
    public static func protect(_ text: String) -> String {
        guard let regex else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let whole = Range(match.range, in: result), let phrase = Range(match.range(at: 1), in: result) else { continue }
            let hidden = hide(result[phrase])
            // "Literal fire emoji" at the start keeps its capital: "Fire emoji".
            let capital = result[whole].first?.isUppercase == true
            result.replaceSubrange(whole, with: capital ? hidden.prefix(1).uppercased() + hidden.dropFirst() : hidden)
        }
        return result
    }

    /// The hidden marks taken out again.
    public static func release(_ text: String) -> String {
        text.replacingOccurrences(of: String(joiner), with: "")
    }
}

/// Emoji by name (SPEC.md 4.6): "thumbs up emoji" writes 👍. Only with the word "emoji" after
/// the name, so "thumbs up" on its own stays as said. Idea from FluidVoice (researched 18 Nov 2026).
public enum Emoji {
    static let names: [String: String] = [
        "thumbs up": "👍", "thumbs down": "👎", "heart": "❤️", "red heart": "❤️", "smiley": "🙂", "smiley face": "🙂",
        "smiling": "😊", "smile": "😊", "grinning": "😀", "big smile": "😀", "laughing": "😂", "crying laughing": "😂",
        "tears of joy": "😂", "crying": "😢", "sad": "🙁", "sad face": "🙁", "wink": "😉", "winking": "😉",
        "thinking": "🤔", "fire": "🔥", "party": "🎉", "party popper": "🎉", "celebration": "🎉", "clapping": "👏",
        "clap": "👏", "praying hands": "🙏", "pray": "🙏", "thank you": "🙏", "eyes": "👀", "tick": "✅", "check mark": "✅",
        "cross": "❌", "star": "⭐", "rocket": "🚀", "hundred": "💯", "one hundred": "💯", "shrug": "🤷", "shrugging": "🤷",
        "face palm": "🤦", "facepalm": "🤦", "skull": "💀", "sun": "☀️", "ok": "👌", "okay": "👌", "ok hand": "👌",
        "wave": "👋", "waving": "👋", "muscle": "💪", "flexed biceps": "💪", "kiss": "😘", "blowing a kiss": "😘",
        "angry": "😠", "heart eyes": "😍", "sunglasses": "😎", "cool": "😎", "upside down": "🙃", "upside down face": "🙃",
        "raised hands": "🙌", "sparkles": "✨", "coffee": "☕", "cake": "🎂", "birthday cake": "🎂", "gift": "🎁",
        "present": "🎁", "dog": "🐶", "cat": "🐱", "sleeping": "😴", "sweat smile": "😅", "nervous": "😅",
        "grimacing": "😬", "mind blown": "🤯", "exploding head": "🤯", "hug": "🤗", "hugging": "🤗",
    ]

    nonisolated(unsafe) private static let regex: NSRegularExpression? = {
        let phrases = names.keys.sorted { $0.count > $1.count }.map { NSRegularExpression.escapedPattern(for: $0) }
        return try? NSRegularExpression(
            pattern: "(,? )?(?<![\\p{L}\\p{N}])(\(phrases.joined(separator: "|"))) emoji(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive])
    }()

    public static func apply(to text: String) -> String {
        guard let regex else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let whole = Range(match.range, in: result), let name = Range(match.range(at: 2), in: result),
                  let emoji = names[result[name].lowercased()] else { continue }
            // One space before it, and a comma the model guessed there goes: "That's great 👍".
            let spaceBefore = match.range(at: 1).location != NSNotFound
            result.replaceSubrange(whole, with: spaceBefore ? " " + emoji : emoji)
        }
        return result
    }
}

/// Lists said out loud (SPEC.md 4.6): "My plan: one, buy milk. Two, call Sam." becomes a numbered
/// list, one point a line. The points must start at one and go up in order, at the start of the
/// text or after punctuation, with words in each, so "One of them is red" or "one, two, three, go"
/// stay as said. A list of just two said as "one ... two ..." needs a comma or full stop after
/// each number (or "first", "number one"), so "One thing though, two people can't come" stays.
/// Idea from Wispr Flow and VoiceInk (researched 18 Nov 2026).
public enum SpokenLists {
    private static let markers: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9,
        "tenth": 10, "firstly": 1, "secondly": 2, "thirdly": 3, "fourthly": 4, "fifthly": 5,
    ]
    nonisolated(unsafe) private static let regex: NSRegularExpression? = {
        let words = markers.keys.sorted { $0.count > $1.count }.joined(separator: "|")
        return try? NSRegularExpression(
            pattern: "(?:^|(?<=[.!?:;,] )|(?<=\\n))(number )?(\(words)|[1-9]|10)(?![\\p{L}\\p{N}])([,.:)])? *", options: [.caseInsensitive])
    }()

    public static func apply(to text: String) -> String {
        guard let regex else { return text }
        var clear: [Range<String.Index>: Bool] = [:]
        let found = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> (Range<String.Index>, Int)? in
            guard let range = Range(match.range, in: text), let word = Range(match.range(at: 2), in: text) else { return nil }
            let key = text[word].lowercased()
            guard let number = markers[key] ?? Int(key) else { return nil }
            // Clearly a point: "number one", "first", or a mark straight after ("one,").
            clear[range] = match.range(at: 1).location != NSNotFound || match.range(at: 3).location != NSNotFound
                || !["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"].contains(key)
            return (range, number)
        }
        // The first run of markers 1, 2, 3 ... in order.
        guard let start = found.firstIndex(where: { $0.1 == 1 }) else { return text }
        var run = [found[start]]
        for marker in found[(start + 1)...] where marker.1 == run.count + 1 { run.append(marker) }
        guard run.count >= 3 || (run.count == 2 && run.allSatisfy { clear[$0.0] == true }) else { return text }

        var points: [String] = []
        for (index, marker) in run.enumerated() {
            let end = index + 1 < run.count ? run[index + 1].0.lowerBound : text.endIndex
            points.append(String(text[marker.0.upperBound..<end]))
        }
        // The last point ends with its sentence; anything after starts a new line.
        var after = ""
        if let last = points.last, let stop = last.range(of: "[.!?] +\\S", options: .regularExpression) {
            let cut = last.index(before: stop.upperBound)
            after = String(last[cut...])
            points[points.count - 1] = String(last[..<cut])
        }
        let cleaned = points.map { point in
            var item = point.trimmingCharacters(in: .whitespaces)
            while let end = item.last, ",;".contains(end) { item.removeLast() }
            item = item.trimmingCharacters(in: .whitespaces)
            if let first = item.first, first.isLowercase { item = first.uppercased() + item.dropFirst() }
            return item
        }
        guard cleaned.allSatisfy({ !$0.isEmpty && $0.first?.isLetter == true || $0.first?.isNumber == true }) else { return text }

        var intro = String(text[..<run[0].0.lowerBound]).trimmingCharacters(in: .whitespaces)
        if intro.hasSuffix(",") { intro = String(intro.dropLast()) + ":" }
        let list = cleaned.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        var result = intro.isEmpty ? list : intro + "\n" + list
        if !after.isEmpty { result += "\n" + after }
        return result
    }
}

/// "Um", "uh", "erm" and "er" taken out (SPEC.md 3.1), for Parakeet Ultra, which keeps them.
/// Bark 3.0 Clean drops them itself. "Ah", "hmm" and "err" stay: they're often meant.
public enum Fillers {
    static let words: Set<String> = ["um", "umm", "uh", "uhh", "uhm", "erm", "er"]

    /// Whether a word the speech model heard is only a filler ("um", "Uh,").
    public static func isFiller(_ word: String) -> Bool {
        let letters = word.filter(\.isLetter)
        // "ER" and "UM" in capitals are more likely the letters (A and E).
        guard letters.count < 2 || letters != letters.uppercased() else { return false }
        return word.allSatisfy { $0.isLetter || ",.?!".contains($0) } && words.contains(letters.lowercased())
    }

    /// "So, um, I realised" to "So, I realised"; "Um, so I think" to "So I think". A comma
    /// before the filler stays, as it may be meant ("Hi Sam, um, how are you?").
    public static func remove(from text: String) -> String {
        var out: [String] = []
        var capitaliseNext = false
        for token in text.split(separator: " ").map(String.init) {
            guard isFiller(token) else {
                var word = token
                // Not "iPhone", which has its own capital.
                if capitaliseNext, let first = word.first, first.isLowercase, !word.contains(where: \.isUppercase) {
                    word = first.uppercased() + word.dropFirst()
                }
                capitaliseNext = false
                out.append(word)
                continue
            }
            let startsSentence = out.last.map { $0.last.map { ".!?\n".contains($0) } ?? true } ?? true
            if startsSentence { capitaliseNext = true }
            guard var last = out.popLast() else { continue }
            if let end = token.last, ".?!".contains(end) {
                // "It was um." to "It was."
                if last.hasSuffix(",") { last.removeLast() }
                if let mark = last.last, !".?!".contains(mark) { last.append(end) }
                capitaliseNext = true
            }
            out.append(last)
        }
        return out.joined(separator: " ")
    }
}

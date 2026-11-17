import Foundation

/// Things you can say that aren't written as words: "new line",
/// "new paragraph", and "press enter" at the very end.
public enum SpokenCommands {
    /// "press enter" or "press return" at the end: taken off the text, and the
    /// app presses Return after writing it (to send a message, say).
    public static func pressEnter(in text: String) -> (text: String, pressEnter: Bool) {
        let pattern = "[\\s,;:]*(?<![\\p{L}\\p{N}])press (enter|return)[\\s.!?]*$"
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return (text, false)
        }
        return (String(text[..<range.lowerBound]), true)
    }

    /// "new line" becomes a line break and "new paragraph" a blank line. The
    /// punctuation the model put after the command goes; the next word gets a capital.
    /// Only at the edge of a sentence or phrase (punctuation, or the start or end,
    /// on one side), so "a new line of shoes" stays as said.
    public static func lineBreaks(in text: String) -> String {
        let pattern = "[ \\t]*(?<![\\p{L}\\p{N}])new (line|paragraph)(?![\\p{L}\\p{N}])([.,;:!?]*)[ \\t]*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let whole = Range(match.range, in: result), let kind = Range(match.range(at: 1), in: result),
                  let after = Range(match.range(at: 2), in: result) else { continue }
            let before = result[..<whole.lowerBound].last
            let atEdge = before == nil || ".,;:!?\n".contains(before!) || !result[after].isEmpty || whole.upperBound == result.endIndex
            guard atEdge else { continue }
            let isParagraph = result[kind].lowercased() == "paragraph"
            result.replaceSubrange(whole, with: isParagraph ? "\n\n" : "\n")
        }
        return capitaliseAfterBreaks(result)
    }

    /// Words with a capital inside (iPhone, eBay) are left alone, as at the start.
    private static func capitaliseAfterBreaks(_ text: String) -> String {
        var characters = Array(text)
        var index = 0
        while index < characters.count {
            if characters[index].isNewline, index + 1 < characters.count, !characters[index + 1].isNewline {
                let start = index + 1
                var end = start
                while end < characters.count, characters[end].isLetter { end += 1 }
                let word = characters[start..<end]
                if let first = word.first, first.isLowercase, !word.dropFirst().contains(where: \.isUppercase) {
                    characters[start] = Character(first.uppercased())
                }
            }
            index += 1
        }
        return String(characters)
    }
}

/// A finished dictation, ready to write where the cursor is.
public struct Dictation: Equatable, Sendable {
    public var text: String
    /// Press Return after writing the text ("press enter" was said at the end).
    public var pressEnter: Bool

    public init(text: String, pressEnter: Bool = false) {
        self.text = text
        self.pressEnter = pressEnter
    }
}

extension Tidy {
    /// Everything between the model and the cursor, in order: tidying, British
    /// spelling, the word list and spelt-out letters (`finish`), then "press enter",
    /// stray full stops, brackets, spoken punctuation, "scratch that", the AI tidy-up
    /// (async version only), line breaks, the email layout, casual style, and last of
    /// all snippets, so their saved text is never changed.
    public static func dictation(
        _ raw: String, words: [WordEntry], snippets: [Snippet] = [], british: Bool, casual: Bool = false, email: Bool = false
    ) -> Dictation {
        dictation(
            finished: finish(raw, words: words, british: british), words: words, snippets: snippets,
            british: british, casual: casual, email: email)
    }

    /// The same, with the "no wait, I mean" fix (SPEC.md 4.8) after British
    /// spelling and the word list and before everything else. `fix` asks the
    /// on-device AI and returns the fixed text, or nil to keep it as it is.
    public static func dictation(
        _ raw: String, words: [WordEntry], snippets: [Snippet] = [], british: Bool, casual: Bool = false,
        email: Bool = false, fix: @Sendable (String) async -> String?
    ) async -> Dictation {
        await dictation(raw, words: words, snippets: snippets, british: british, casual: casual, email: email, fix: fix) { _ in nil }
    }

    /// The same, with the AI tidy-up too (SPEC.md 4.11), after spoken punctuation and
    /// "scratch that" and before line breaks, emails, casual style and snippets. `tidy`
    /// asks the on-device AI and returns the checked reply, or nil to keep the text.
    /// Its reply gets British spelling, the word list and the doubled-marks check again.
    public static func dictation(
        _ raw: String, words: [WordEntry], snippets: [Snippet] = [], british: Bool, casual: Bool = false,
        email: Bool = false, fix: @Sendable (String) async -> String?, tidy: @Sendable (String) async -> String?
    ) async -> Dictation {
        var finished = finish(raw, words: words, british: british)
        if let fixed = await fix(finished) { finished = fixed }
        var (text, pressEnter) = marks(finished, words: words)
        if !text.isEmpty, let tidied = await tidy(text) {
            // The word list again, but only entries that can't change their own text ("murmur ->
            // Murmur app" would give "Murmur app app"), as the text has already been through it.
            text = DoubledMarks.remove(from: finish(tidied, words: WordList.safeToRepeat(words), british: british))
        }
        return Dictation(
            text: layout(text, words: words, snippets: snippets, british: british, casual: casual, email: email),
            pressEnter: pressEnter)
    }

    /// The same, for text that has already been through `finish`.
    public static func dictation(
        finished: String, words: [WordEntry], snippets: [Snippet] = [], british: Bool, casual: Bool = false,
        email: Bool = false
    ) -> Dictation {
        let (text, pressEnter) = marks(finished, words: words)
        return Dictation(
            text: layout(text, words: words, snippets: snippets, british: british, casual: casual, email: email),
            pressEnter: pressEnter)
    }

    /// "Press enter" taken off the end, then the marks: stray full stops, brackets,
    /// spoken punctuation, doubled marks and "scratch that".
    static func marks(_ finished: String, words: [WordEntry]) -> (text: String, pressEnter: Bool) {
        let (text, pressEnter) = SpokenCommands.pressEnter(in: finished)
        // Stray stops first, so a full stop you said yourself is never taken out.
        // Brackets before the other marks, so the marks they trim are only ever the model's guesses.
        let punctuated = DoubledMarks.remove(
            from: SpokenPunctuation.apply(to: SpokenSymbols.apply(to: StrayStops.remove(from: text, keeping: words))))
        return (ScratchThat.apply(punctuated), pressEnter)
    }

    /// Line breaks, the email layout, casual style, then snippets last so their text is never changed.
    static func layout(
        _ text: String, words: [WordEntry], snippets: [Snippet], british: Bool, casual: Bool, email: Bool
    ) -> String {
        var result = SpokenCommands.lineBreaks(in: text)
        if email { result = EmailLayout.apply(result) }
        if casual { result = Tidy.casual(result, keeping: words) }
        return Snippets.apply(matching(snippets, words: words, british: british), to: result)
    }

    /// Snippets with their phrases spelt as the text will be by then (British spelling
    /// and the word list), so "my favorite color" still matches "my favourite colour".
    public static func matching(_ snippets: [Snippet], words: [WordEntry], british: Bool) -> [Snippet] {
        snippets.map { snippet in
            var changed = snippet
            changed.trigger = WordList.apply(words, to: british ? BritishSpelling.apply(to: snippet.trigger) : snippet.trigger)
            return changed
        }
    }

    /// Casual style for chats: no capital at the start and no full stop at the
    /// end. "I", words with capitals inside (iPhone, NASA) and names from the
    /// word list keep their capitals.
    public static func casual(_ text: String, keeping words: [WordEntry] = []) -> String {
        var result = text
        if result.hasSuffix("."), !result.hasSuffix("..") { result.removeLast() }

        let firstWord = result.prefix(while: { $0.isLetter || $0 == "'" || $0 == "\u{2019}" })
        guard let first = firstWord.first, first.isUppercase else { return result }
        let isI = firstWord == "I" || firstWord.hasPrefix("I'") || firstWord.hasPrefix("I\u{2019}")
        let hasInnerCapital = firstWord.dropFirst().contains(where: \.isUppercase)
        let isListedName = words.contains { entry in
            guard entry.written.first?.isUppercase == true, result.hasPrefix(entry.written) else { return false }
            let next = result.dropFirst(entry.written.count).first
            return next.map { !$0.isLetter && !$0.isNumber } ?? true
        }
        guard !isI, !hasInnerCapital, !isListedName else { return result }
        return first.lowercased() + result.dropFirst()
    }
}

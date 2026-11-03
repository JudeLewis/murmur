import Foundation

// Knowing what you're writing (SPEC.md 4.6, 4.9 and 4.10): emails laid out as emails,
// "scratch that", and other people's voices left out.

/// Emails (SPEC.md 4.9): the greeting and the sign-off on their own lines.
public enum EmailLayout {
    /// Mail apps, by bundle id.
    public static let apps: Set<String> = [
        "com.apple.mail", "com.microsoft.Outlook", "com.readdle.smartemail-Mac", "com.readdle.SparkDesktop",
        "com.superhuman.electron", "it.bloop.airmail2", "com.freron.MailMate", "com.mimestream.Mimestream",
        "ch.protonmail.desktop",
    ]
    /// Webmail, by the end of the browser window's title ("Inbox (3) - jude@gmail.com - Gmail").
    public static let webmail = ["Gmail", "Outlook", "Proton Mail", "Yahoo Mail", "iCloud Mail", "Fastmail"]
    /// Browsers, whose window title is worth reading.
    public static let browsers: Set<String> = [
        "com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "company.thebrowser.Browser",
        "com.brave.Browser", "com.microsoft.edgemac", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        "app.zen-browser.zen", "company.thebrowser.dia",
    ]

    public static func isEmail(app bundleID: String?, windowTitle: String?) -> Bool {
        guard let bundleID else { return false }
        if apps.contains(bundleID) { return true }
        guard browsers.contains(bundleID), let title = windowTitle else { return false }
        // Browsers add their own name or a profile after a dash ("… - Outlook -
        // Personal - Microsoft Edge"; Firefox uses a long dash), so any part will do.
        let parts = title.components(separatedBy: CharacterSet(charactersIn: "-\u{2014}\u{2013}|"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.contains { webmail.contains($0) }
    }

    static let greetings = [
        "good morning", "good afternoon", "good evening", "hi", "hello", "hey", "dear", "morning", "afternoon", "evening",
    ]
    static let signOffs = [
        "many thanks", "thanks so much", "thanks again", "thank you", "thanks", "cheers", "best wishes", "kind regards",
        "warm regards", "all the best", "speak soon", "take care", "yours sincerely", "yours faithfully", "regards",
        "best", "love",
    ]
    /// Capitalised, but never who an email is to: "Hi I wanted to ask".
    static let notNames: Set<String> = ["I", "I'm", "I've", "I'll", "I'd", "I\u{2019}m", "I\u{2019}ve", "I\u{2019}ll", "I\u{2019}d"]
    /// Who a greeting can be to, besides names.
    static let groups: Set<String> = ["everyone", "all", "team", "both", "there", "folks"]
    /// Sign-offs that end an email even without a name after them.
    static let signOffsAlone: Set<String> = [
        "best wishes", "kind regards", "warm regards", "all the best", "yours sincerely", "yours faithfully", "regards",
    ]

    /// "Hi Sam. Thanks for the report. Best, Jude." becomes
    /// "Hi Sam,\n\nThanks for the report.\n\nBest,\nJude". Only line breaks and
    /// the punctuation next to them change, never the words.
    public static func apply(_ text: String) -> String {
        var result = text
        if let laidOut = signOff(result) { result = laidOut }
        if let laidOut = greeting(result) { result = laidOut }
        return result
    }

    /// The greeting at the very start, up to three capitalised names, then a
    /// comma and a blank line. "Hi, how are you?" counts too.
    static func greeting(_ text: String) -> String? {
        let lower = text.lowercased()
        guard let opener = greetings.first(where: { lower.hasPrefix($0) && isBoundary(text, at: $0.count) }) else { return nil }
        var index = text.index(text.startIndex, offsetBy: opener.count)
        var names = 0
        // Names: capitalised words straight after ("Hi Sam", "Dear Mr Smith"), or "everyone", "all".
        while names < 3 {
            let rest = text[index...].drop { $0 == " " }
            let word = rest.prefix { !$0.isWhitespace && !",.!?".contains($0) }
            guard let first = word.first, first.isUppercase || groups.contains(word.lowercased()),
                  !notNames.contains(String(word)) else { break }
            index = word.endIndex
            names += 1
        }
        let afterNames = text[index...]
        let punctuation = afterNames.first.map { ",.!".contains($0) } ?? false
        guard punctuation || names > 0 else { return nil }
        let head = text[..<index]
        var body = afterNames.dropFirst(punctuation ? 1 : 0).drop { $0 == " " || $0.isNewline }
        if body.isEmpty { return head + ",\n\n" }
        // Something else starting with a greeting word is a sentence, not a greeting:
        // "Hey, can you" is a greeting, "Hello world is" isn't. A greeting is followed by a capital.
        let next = String(body.prefix(1)).uppercased()
        body = Substring(next + body.dropFirst())
        return head + ",\n\n" + body
    }

    /// The sign-off at the very end: a phrase, then a name ("Thanks, Jude."),
    /// or a formal one alone ("Kind regards.").
    static func signOff(_ text: String) -> String? {
        var trimmed = Substring(text)
        while let last = trimmed.last, last == "." || last == " " { trimmed = trimmed.dropLast() }
        // Only the last sentence (one search back from the end, as this runs on
        // every reading while typing as you speak).
        let start = trimmed.lastIndex { ".!?\n".contains($0) }.map { trimmed.index(after: $0) } ?? trimmed.startIndex
        let sentence = trimmed[start...].drop { $0 == " " }
        let lower = sentence.lowercased()
        guard let phrase = signOffs.first(where: { lower.hasPrefix($0) && isBoundary(String(sentence), at: $0.count) }) else { return nil }
        let phraseEnd = sentence.index(sentence.startIndex, offsetBy: phrase.count)
        let name = sentence[phraseEnd...].drop { ", ".contains($0) }
        let words = name.split(separator: " ")
        let isName = !words.isEmpty && words.count <= 3
            && words.allSatisfy { $0.first?.isUppercase == true && !$0.contains(where: { ",!?".contains($0) }) }
        guard isName || (name.isEmpty && signOffsAlone.contains(phrase)) else { return nil }
        let before = text[..<sentence.startIndex].trimmingCharacters(in: .whitespaces)
        guard !before.isEmpty else { return nil }
        let signed = sentence[..<phraseEnd] + "," + (name.isEmpty ? "" : "\n" + name)
        return before + "\n\n" + signed
    }

    /// The phrase ends at a word boundary, not inside a longer word ("Hiking", "Bestow").
    private static func isBoundary(_ text: String, at offset: Int) -> Bool {
        guard offset < text.count else { return true }
        let next = text[text.index(text.startIndex, offsetBy: offset)]
        return !next.isLetter && !next.isNumber && next != "'"
    }
}

/// "Scratch that" (SPEC.md 4.6): takes out the sentence before it.
public enum ScratchThat {
    public static func apply(_ text: String) -> String {
        var result = text
        while let restarted = restart(in: result) { result = restarted }
        while let range = nextCommand(in: result) {
            var before = String(result[..<range.lowerBound])
            var after = Substring(result[range.upperBound...])
            // The words since the last sentence end (or line break) go, with the
            // punctuation the model put between them and the command.
            while let last = before.last, ",;:-. ".contains(last) { before.removeLast() }
            if let end = before.lastIndex(where: { ".!?\n".contains($0) }) {
                before = String(before[...end])
            } else {
                before = ""
            }
            after = after.drop { ",.;:!? ".contains($0) }
            var next = String(after)
            if before.isEmpty || before.last.map({ ".!?\n".contains($0) }) == true {
                next = next.prefix(1).uppercased() + next.dropFirst()
            }
            let joiner = before.isEmpty || before.last?.isNewline == true || next.isEmpty ? "" : " "
            result = before + joiner + next
        }
        return result
    }

    /// The model sometimes leaves a correction with no punctuation at all ("send it
    /// to tom no scratch that send it to sarah", seen 3 Nov 2026). Then it counts
    /// only if the words after it start the sentence again: from where those words
    /// first came, up to the command, is taken out. "Scratch that itch" isn't.
    static func restart(in text: String) -> String? {
        var searchFrom = text.startIndex
        while let range = text.range(of: "scratch that", options: .caseInsensitive, range: searchFrom..<text.endIndex) {
            searchFrom = range.upperBound
            let after = text[range.upperBound...]
            guard after.first == " " else { continue }
            let next = after.split(separator: " ").prefix(2).map(plain)
            let sentenceStart = text[..<range.lowerBound].lastIndex { ".!?\n".contains($0) }.map { text.index(after: $0) } ?? text.startIndex
            let before = text[sentenceStart..<range.lowerBound]
            guard next.count == 2, !before.contains(where: { ",;:".contains($0) }) else { continue }
            // Where the same two words began the earlier attempt.
            let words = before.split(separator: " ")
            guard let at = (0..<max(0, words.count - 1)).first(where: { plain(words[$0]) == next[0] && plain(words[$0 + 1]) == next[1] }) else { continue }
            let cut = words[at].startIndex
            let head = text[..<cut]
            var rest = String(after.dropFirst())
            if head.trimmingCharacters(in: .whitespaces).isEmpty || head.trimmingCharacters(in: .whitespaces).last.map({ ".!?\n".contains($0) }) == true {
                rest = rest.prefix(1).uppercased() + rest.dropFirst()
            }
            return head + rest
        }
        return nil
    }

    private static func plain(_ word: Substring) -> String {
        word.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "'" }
    }

    /// "scratch that" standing alone: punctuation, a line break or the edge of
    /// the text on both sides, so "I need to scratch that itch" is left alone.
    static func nextCommand(in text: String) -> Range<String.Index>? {
        var searchFrom = text.startIndex
        while let range = text.range(of: "scratch that", options: .caseInsensitive, range: searchFrom..<text.endIndex) {
            let before = text[..<range.lowerBound].last { $0 != " " }
            let after = text[range.upperBound...].first
            let leftEdge = before.map { ",.;:!?\n".contains($0) } ?? true
            let rightEdge = after.map { ",.;:!?\n".contains($0) } ?? true
            if leftEdge && rightEdge { return range }
            searchFrom = range.upperBound
        }
        return nil
    }
}

/// Other people's voices (SPEC.md 4.10): someone across the room sounds much
/// quieter than you at the Mac, so sentences much quieter than your own are left out.
public enum QuietVoices {
    /// A sentence this much quieter than your speech (about 10 decibels) is someone else's.
    public static let threshold: Float = 0.3

    public static func keep(_ words: [HeardWord]) -> [HeardWord] {
        let sentences = Self.sentences(words)
        guard sentences.count > 1 else { return words }
        let loud = words.compactMap(\.loudness).sorted()
        guard !loud.isEmpty else { return words }
        // Your voice: near the top of what was heard, so a long chat across the room doesn't set it.
        let you = loud[min(loud.count - 1, Int(Double(loud.count) * 0.9))]
        return sentences.filter { sentence in
            let levels = sentence.compactMap(\.loudness)
            guard !levels.isEmpty else { return true }
            return levels.reduce(0, +) / Float(levels.count) >= you * threshold
        }.flatMap { $0 }
    }

    /// Sentences: up to a full stop, question or exclamation mark, or a pause.
    /// A word's timing runs on to the next word, so a pause shows as over 1.5
    /// seconds from one word's start to the next.
    static func sentences(_ words: [HeardWord]) -> [[HeardWord]] {
        var result: [[HeardWord]] = []
        var current: [HeardWord] = []
        for word in words {
            if let last = current.last, word.start - last.start > 1.5 {
                result.append(current)
                current = []
            }
            current.append(word)
            if let end = word.text.last, ".!?".contains(end) {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

import Foundation

/// Say a short phrase and Murmur writes the saved text instead, like
/// Wispr Flow's snippets: "my email" becomes "jude@example.com".
public struct Snippet: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    /// What you say.
    public var trigger: String
    /// What Murmur writes, exactly as saved (capitals, line breaks and all).
    public var text: String

    public init(id: UUID = UUID(), trigger: String, text: String) {
        self.id = id
        self.trigger = trigger
        self.text = text
    }
}

public enum Snippets {
    /// If the whole dictation is a trigger ("My email."), it becomes just the
    /// saved text, with no full stop or space added. Otherwise each trigger
    /// said inside a sentence is swapped for its text, whole words only.
    public static func apply(_ snippets: [Snippet], to text: String, now: Date = .now) -> String {
        let usable = snippets.filter { !plain($0.trigger).isEmpty && !$0.text.isEmpty }
        if let whole = usable.first(where: { plain($0.trigger) == plain(text) }) { return fill(whole.text, now: now) }

        // Find every trigger in the text as it was, longest first, without
        // overlaps; then swap them all at once, so one snippet's saved text is
        // never searched for another's trigger.
        let whole = NSRange(text.startIndex..., in: text)
        var found: [(range: NSRange, text: String)] = []
        for snippet in usable.sorted(by: { $0.trigger.count > $1.trigger.count }) {
            guard let regex = try? NSRegularExpression(pattern: pattern(for: snippet.trigger), options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: whole)
            where !found.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) {
                found.append((match.range, fill(snippet.text, now: now)))
            }
        }
        var result = text
        for (range, saved) in found.sorted(by: { $0.range.location > $1.range.location }) {
            if let swap = Range(range, in: result) { result.replaceSubrange(swap, with: saved) }
        }
        return result
    }

    /// Saved text that fills itself in (SPEC.md 4.5): {date} is "18 November 2026", {day}
    /// "Wednesday", {time} "14:05", {tomorrow} "19 November 2026", {year} "2026".
    public static func fill(_ text: String, now: Date = .now) -> String {
        guard text.contains("{") else { return text }
        func format(_ pattern: String, _ date: Date) -> String {
            // Only for a snippet that was said and has a {...} in it, so making these is rare.
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        var result = text
        for (key, value) in [("{date}", format("d MMMM yyyy", now)), ("{day}", format("EEEE", now)), ("{time}", format("HH:mm", now)),
                             ("{tomorrow}", format("d MMMM yyyy", tomorrow)), ("{year}", format("yyyy", now))] {
            result = result.replacingOccurrences(of: key, with: value, options: .caseInsensitive)
        }
        return result
    }

    /// Whole words, any capitals, a space or hyphen between words, and either
    /// kind of apostrophe. Symbols in the trigger ("c++") are kept.
    private static func pattern(for trigger: String) -> String {
        let words = trigger.split(whereSeparator: { $0.isWhitespace || $0 == "-" }).map { word in
            NSRegularExpression.escapedPattern(for: word.replacingOccurrences(of: "\u{2019}", with: "'"))
                .replacingOccurrences(of: "'", with: "['\u{2019}]")
        }
        return "(?<![\\p{L}\\p{N}])" + words.joined(separator: "[\\s-]+") + "(?![\\p{L}\\p{N}])"
    }

    /// Lower case, letters and numbers only, single spaces: "My e-mail!" is "my e mail".
    static func plain(_ text: String) -> String {
        text.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: " ")
    }

    public static func encode(_ snippets: [Snippet]) -> Data {
        (try? JSONEncoder().encode(snippets)) ?? Data("[]".utf8)
    }

    public static func decode(_ data: Data?) -> [Snippet] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([Snippet].self, from: data)) ?? []
    }
}

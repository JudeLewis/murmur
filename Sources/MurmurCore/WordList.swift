import Foundation

/// One line of the word list: when `heard` turns up in a transcript, write `written`.
public struct WordEntry: Equatable, Sendable {
    public let heard: String
    public let written: String

    public init(heard: String, written: String) {
        self.heard = heard
        self.written = written
    }
}

extension WordEntry {
    /// From the word list screen's two boxes. "Write it as" empty with "When it
    /// hears" filled removes that word. Nil when there's nothing to save, or the
    /// entry wouldn't read back from words.txt (an arrow inside, or a # at the start).
    public static func fromForm(written: String, heard: String) -> WordEntry? {
        let written = written.trimmingCharacters(in: .whitespaces)
        let heard = heard.trimmingCharacters(in: .whitespaces)
        let entry = WordEntry(heard: heard.isEmpty ? written : heard, written: written)
        guard !entry.heard.isEmpty, !entry.heard.hasPrefix("#") else { return nil }
        guard !["->", "=>", "\u{2192}"].contains(where: { entry.heard.contains($0) || entry.written.contains($0) }) else { return nil }
        return entry
    }
}

/// The user's own word list, kept as a plain text file they edit in TextEdit.
///
/// Each line is either a word or name to always write exactly as typed
/// ("Clocked In"), or a fix in the form `heard -> written` ("wisper flow -> Wispr Flow").
/// Lines starting with # are notes.
public enum WordList {
    public static let template = """
        # Murmur word list
        #
        # One entry per line. There are two kinds:
        #
        #   Clocked In
        #       Always write it exactly like this (fixes the capitals).
        #
        #   wisper flow -> Wispr Flow
        #       When Murmur writes the left side, change it to the right side.
        #
        # Lines starting with # are notes and are ignored.
        # Changes work from your next dictation; no need to restart.

        Clocked In

        """

    public static func parse(_ text: String) -> [WordEntry] {
        text.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { return nil }

            for arrow in ["->", "=>", "→"] {
                if let range = line.range(of: arrow) {
                    let heard = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                    let written = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    guard !heard.isEmpty else { return nil }
                    return WordEntry(heard: heard, written: written)
                }
            }
            return WordEntry(heard: line, written: line)
        }
    }

    /// Writes entries back as the file's text, for the word list screens.
    public static func text(for entries: [WordEntry]) -> String {
        let header = """
            # Murmur word list. Edit it from the Murmur menu (Mac) or the Murmur app (iPhone).
            # Each line is a word to always write like this, or "heard -> written".

            """
        let lines = entries.map { $0.heard == $0.written ? $0.written : "\($0.heard) -> \($0.written)" }
        return header + lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
    }

    /// Applies every entry, longest first so "Clocked In app" wins over "Clocked In".
    /// Matching ignores capitals, only matches whole words, and lets a space in the
    /// list match a hyphen in the transcript ("clocked-in").
    public static func apply(_ entries: [WordEntry], to text: String) -> String {
        var result = text
        for entry in entries.sorted(by: { $0.heard.count > $1.heard.count }) {
            let words = entry.heard
                .split(whereSeparator: { $0 == " " || $0 == "-" })
                .map { NSRegularExpression.escapedPattern(for: String($0)) }
            guard !words.isEmpty else { continue }
            let pattern = "(?<![\\p{L}\\p{N}])" + words.joined(separator: "[\\s-]+") + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result, range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: entry.written))
        }
        return result
    }
}

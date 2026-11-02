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

import Foundation

// What Murmur asks Apple's on-device AI model (Apple Intelligence), and the
// checks on what comes back. The model itself is called from the Mac app.

/// Command Mode (SPEC.md 2.7): rewrite the selected text as asked, or write
/// something new when nothing is selected.
public enum CommandMode {
    public static func instructions(british: Bool) -> String {
        """
        You edit or write text for the user, as they ask. Reply with only the finished text: \
        no introduction, no quotation marks around it, no notes.\(british ? " Use British English spelling." : "") \
        Keep names, numbers and facts as they are unless asked to change them. Keep it short and plain \
        unless asked otherwise. Never use placeholders such as [Name]; leave them out.
        """
    }

    /// The reply, ready to paste: extras taken off, British spelling and the
    /// word list, and a space after it when it's new text at the cursor (so the
    /// next dictation doesn't run on). Empty if there's nothing left.
    public static func finish(reply: String, words: [WordEntry], british: Bool, replacingSelection: Bool) -> String {
        var text = clean(reply)
        if british { text = BritishSpelling.apply(to: text) }
        text = WordList.apply(words, to: text)
        return replacingSelection ? text : Tidy.forInsertion(text)
    }

    public static func prompt(instruction: String, selection: String?) -> String {
        guard let selection, !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Write this: \(instruction)"
        }
        return "Instruction: \(instruction)\n\nText:\n\(selection)"
    }

    /// Takes off what small models sometimes add anyway: a "Here is..." line,
    /// or quotation marks or code fences around the whole reply.
    public static func clean(_ reply: String) -> String {
        var text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstBreak = text.firstIndex(of: "\n") {
            let firstLine = text[..<firstBreak].lowercased()
            if (firstLine.hasPrefix("here is") || firstLine.hasPrefix("here's") || firstLine.hasPrefix("sure")), firstLine.hasSuffix(":") {
                text = String(text[firstBreak...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if text.hasPrefix("```"), text.hasSuffix("```"), text.count >= 6 {
            text = String(text.dropFirst(3).dropLast(3))
            if let firstBreak = text.firstIndex(of: "\n"), !text[..<firstBreak].contains(" ") {
                text = String(text[text.index(after: firstBreak)...])
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for (open, close) in [("\"", "\""), ("\u{201C}", "\u{201D}")] where text.hasPrefix(open) && text.hasSuffix(close) && text.count >= 2 {
            let inner = text.dropFirst().dropLast()
            if !inner.contains(open) && !inner.contains(close) { text = String(inner) }
        }
        return withoutPlaceholderLines(text)
    }

    /// Short lines like "Dear [Name]," or "[Your Name]" go, however the model
    /// was told: there's no one to fill them in.
    static func withoutPlaceholderLines(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").filter { line in
            !(line.count <= 30 && line.range(of: "\\[[^\\]]+\\]", options: .regularExpression) != nil)
        }
        var result: [String] = []
        for line in lines where !(line.trimmingCharacters(in: .whitespaces).isEmpty && (result.last?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)) {
            result.append(line)
        }
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Fixing self-corrections (SPEC.md 4.8): "Monday, no wait, I mean Tuesday" to "Tuesday".
public enum SelfCorrection {
    public static let instructions = """
        You clean up dictated text. If the speaker corrects themselves, remove the mistake and the \
        correction words, keeping only what they finally meant. Otherwise return the text unchanged. \
        Reply with only the text.
        Examples:
        Input: Call me at five, sorry, six o'clock.
        Output: Call me at six o'clock.
        Input: The meeting is in London, no, Manchester.
        Output: The meeting is in Manchester.
        Input: I'll bring the cake.
        Output: I'll bring the cake.
        """

    /// Words people use to correct themselves. The model is only asked when
    /// one of these is in the text, so most dictations aren't slowed down.
    static let cues = ["no wait", "wait no", "i mean", "sorry", "actually", "scratch that",
                       "or rather", "rather", "correction", "let me rephrase", "no no", "no,"]

    public static func mightCorrect(_ text: String) -> Bool {
        let plain = " " + text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'") + " "
        return cues.contains { cue in
            cue.hasSuffix(",") ? plain.contains(" " + cue) : plain.range(of: "(?<![\\p{L}])" + cue + "(?![\\p{L}])", options: .regularExpression) != nil
        }
    }

    public static func prompt(_ text: String) -> String {
        "Input: \(text)\nOutput:"
    }

    /// Only a fix that takes words out is used, and only a careful one:
    /// - its words appear in what was said, in the same order, and it isn't longer;
    /// - it ends with the same word (a correction keeps what came last: "five, sorry, six" can't become "five");
    /// - it keeps every "not", "never" and "n't" (so "I don't think" can't become "I think");
    /// - it keeps spoken commands and snippet phrases (`keeping`), such as "press enter".
    /// Anything else is ignored, so what was said is kept.
    public static func accept(original: String, fixed reply: String, keeping phrases: [String] = []) -> String? {
        var fixed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if fixed.lowercased().hasPrefix("output:") { fixed = String(fixed.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
        guard !fixed.isEmpty, fixed.count <= original.count else { return nil }
        let said = words(original)
        let kept = words(fixed)
        guard isInOrder(kept, within: said), kept.last == said.last else { return nil }
        guard negations(kept) >= negations(said) else { return nil }
        let plainSaid = said.joined(separator: " "), plainKept = kept.joined(separator: " ")
        for phrase in commandPhrases + phrases {
            let plainPhrase = words(phrase).joined(separator: " ")
            guard !plainPhrase.isEmpty else { continue }
            if contains(plainSaid, plainPhrase) && !contains(plainKept, plainPhrase) { return nil }
        }
        // "Five, sorry, six o'clock." to "Six o'clock.": keep the capital at the start.
        let firstWord = fixed.prefix(while: { !$0.isWhitespace })
        if original.first?.isUppercase == true, let first = fixed.first, first.isLowercase,
           !firstWord.dropFirst().contains(where: \.isUppercase) {
            fixed = first.uppercased() + fixed.dropFirst()
        }
        return fixed
    }

    static let commandPhrases = ["press enter", "press return", "new line", "new paragraph"]

    private static func isInOrder(_ part: [String], within whole: [String]) -> Bool {
        var index = whole.startIndex
        for word in part {
            guard let found = whole[index...].firstIndex(of: word) else { return false }
            index = whole.index(after: found)
        }
        return true
    }

    private static func negations(_ words: [String]) -> Int {
        words.filter { ["not", "never", "nor", "nothing", "nobody", "none", "cannot"].contains($0) || $0.hasSuffix("n't") }.count
    }

    private static func contains(_ text: String, _ phrase: String) -> Bool {
        (" " + text + " ").contains(" " + phrase + " ")
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" })
            .map(String.init)
    }
}

/// Whisper mode (SPEC.md 3.4): quiet recordings are made louder before the
/// model hears them, up to `maxGain` times, so the loudest moment reaches 0.9.
public enum Loudness {
    public static let whisperGain: Float = 20

    public static func boosted(_ samples: [Float], maxGain: Float) -> [Float] {
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        // Near-total silence stays silent: boosting it would only make hiss.
        guard peak > 0.001 else { return samples }
        let gain = min(maxGain, 0.9 / peak)
        guard gain > 1 else { return samples }
        return samples.map { $0 * gain }
    }
}

/// Keyboard shortcuts Murmur watches for, besides Fn.
public enum Shortcuts {
    /// Control-Command-V pastes the last dictation again (SPEC.md 2.8).
    public static func isPasteAgain(keyCode: Int64, command: Bool, control: Bool, option: Bool, shift: Bool) -> Bool {
        keyCode == 9 && command && control && !option && !shift
    }
}

/// One microphone the Mac can use.
public struct Microphone: Equatable, Sendable {
    /// Core Audio's number for it, while it's plugged in.
    public let id: UInt32
    public let uid: String
    public let name: String
    public let isBuiltIn: Bool
    /// Made by software (Zoom, Teams, BlackHole, aggregate devices), not a real microphone.
    public let isVirtual: Bool

    public init(id: UInt32 = 0, uid: String, name: String, isBuiltIn: Bool, isVirtual: Bool = false) {
        self.id = id
        self.uid = uid
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.isVirtual = isVirtual
    }
}

/// Which microphone to record from (SPEC.md 3.3). Nil means the Mac's own
/// default input, as before.
public enum MicChoice {
    public static func pick(from mics: [Microphone], chosen: String?, lidClosed: Bool, defaultIsBuiltIn: Bool) -> Microphone? {
        if let chosen, let mic = mics.first(where: { $0.uid == chosen }) { return mic }
        // With the lid shut the built-in mic only hears the keyboard: if the
        // Mac's default is that mic, use a real external one instead.
        if lidClosed, defaultIsBuiltIn { return mics.first { !$0.isBuiltIn && !$0.isVirtual } }
        return nil
    }
}

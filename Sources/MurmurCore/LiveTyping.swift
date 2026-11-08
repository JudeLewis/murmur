import Foundation

// Type as I speak (SPEC.md 2.9). While you talk, Murmur reads the whole recording
// so far again about once a second, types each new word once two readings in a
// row agree on it, and corrects what it has typed when a reading says better.

/// A word the speech model heard, with when it was said (seconds from the start of the recording).
public struct HeardWord: Equatable, Sendable {
    public var text: String
    public var start: Double
    public var end: Double
    /// How loud it was said, 0 to about 1 (for leaving out quieter voices, SPEC.md 4.10).
    public var loudness: Float?

    public init(_ text: String, start: Double, end: Double, loudness: Float? = nil) {
        self.text = text
        self.start = start
        self.end = end
        self.loudness = loudness
    }

    var middle: Double { (start + end) / 2 }
}

/// What's on screen. Every reading is of the whole recording so far, which is
/// as accurate as reading it all at the end: there are no joins between short
/// pieces to double a word or guess a sentence's end.
public struct LiveTranscript: Equatable, Sendable {
    /// If nothing new has appeared for this long, the words heard up to `forceGap` ago appear anyway.
    public static let forceAfter: Double = 8
    public static let forceGap: Double = 2
    /// A word ending this close to the end of what's been heard may be cut off
    /// (its timing too), so it waits for the next reading.
    public static let cutOff: Double = 0.3
    /// Silence added after the last reading: without it the model can leave
    /// the last sentence without its full stop or question mark (seen 3 Nov 2026).
    public static let endSilence: Double = 0.6
    /// Words further back than this many characters stay as they are, so a
    /// correction never has to delete much.
    public static let correctable = 250

    /// Too far back to correct, or the cursor may have moved since.
    private var locked: [HeardWord] = []
    /// After the locked words: on screen, and changed by each reading.
    private var shown: [HeardWord] = []
    /// The last reading's words after the locked ones, to compare with the next.
    private var previous: [String] = []
    /// When a new word last appeared.
    private var lastGrew: Double = 0
    /// The last word on screen as the model wrote it, if its punctuation is being held back.
    private var heldBack: String?

    public init() {}

    /// The words on screen, as the model wrote them.
    public var words: [HeardWord] { locked + shown }

    public var text: String { words.map(\.text).joined(separator: " ") }

    /// A reading of the whole recording, `now` seconds long. Returns whether the words on screen changed.
    @discardableResult
    public mutating func heard(_ reading: [HeardWord], now: Double) -> Bool {
        let fresh = unlocked(reading)
        guard isBelievable(fresh) else { return false }
        let before = shown
        let wordsBefore = words.map(\.text)
        // Words already on screen take this reading's version. New ones wait for two readings to agree.
        var count = min(shown.count, fresh.count)
        while count < fresh.count, count < previous.count, fresh[count].text == previous[count], fresh[count].end <= now - Self.cutOff {
            count += 1
        }
        if count > shown.count {
            lastGrew = now
        } else if now - lastGrew > Self.forceAfter {
            let old = fresh.prefix { $0.end <= now - Self.forceGap }.count
            if old > count {
                count = old
                lastGrew = now
            }
        }
        shown = Array(fresh.prefix(count))
        // Commas come and go between readings, and each change would retype everything
        // after it, so the first one typed stays (the last reading can still change the
        // words near the end). The last word shown is left out: its punctuation was held back.
        for index in 0..<max(0, min(count, before.count - 1)) where Self.sameButForCommas(shown[index].text, before[index].text) {
            shown[index].text = before[index].text
        }
        // Punctuation on the very last word is only the model guessing that you've
        // finished. It comes back with the next word if you had (a pause isn't an ending).
        heldBack = nil
        if count == fresh.count, var last = shown.last, let end = last.text.last, ".,?!;:".contains(end) {
            heldBack = last.text
            while let end = last.text.last, ".,?!;:".contains(end) { last.text.removeLast() }
            shown[count - 1] = last
        }
        previous = fresh.map(\.text)
        lockOldWords()
        return words.map(\.text) != wordsBefore
    }

    /// The last reading, once listening has stopped: all of it goes on screen.
    public mutating func finished(_ reading: [HeardWord]) {
        let fresh = unlocked(reading)
        if isBelievable(fresh), !fresh.isEmpty { shown = fresh }
        heldBack = nil
        previous = []
    }

    /// The cursor may have moved: nothing typed so far is corrected any more.
    public mutating func lockEverything() {
        // Punctuation can be added after it without deleting anything.
        if let heldBack, !shown.isEmpty { shown[shown.count - 1].text = heldBack }
        heldBack = nil
        locked += shown
        shown = []
        previous = []
    }

    /// Most of the words vanishing is a bad reading, not a change of mind.
    private func isBelievable(_ fresh: [HeardWord]) -> Bool {
        fresh.count * 2 >= shown.count
    }

    private mutating func lockOldWords() {
        var characters = shown.reduce(0) { $0 + $1.text.count + 1 }
        var old = 0
        while old < shown.count, characters - shown[old].text.count - 1 >= Self.correctable {
            characters -= shown[old].text.count + 1
            old += 1
        }
        guard old > 0 else { return }
        locked += shown.prefix(old)
        shown.removeFirst(old)
        previous.removeFirst(min(old, previous.count))
    }

    /// A word belongs to the locked part if most of it was said before the locked words end.
    private func unlocked(_ reading: [HeardWord]) -> [HeardWord] {
        let lockedUntil = locked.last?.end ?? 0
        var fresh = reading.filter { $0.middle > lockedUntil && !$0.text.isEmpty }
        // The last locked word heard again, timed a little later this time.
        if let first = fresh.first, let last = locked.last, first.start < lockedUntil, Self.same(first.text, last.text) {
            fresh.removeFirst()
        }
        return fresh
    }

    private static func sameButForCommas(_ a: String, _ b: String) -> Bool {
        a.filter { $0 != "," } == b.filter { $0 != "," }
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        let plain = { (word: String) in word.lowercased().filter { $0.isLetter || $0.isNumber } }
        return plain(a) == plain(b)
    }
}

/// How to change what's been typed into what should be there: delete some
/// characters from the end, then type the rest. Tidying can change the end of
/// the text as more words come (a snippet, a word list fix, a full stop).
public struct LiveEdit: Equatable, Sendable {
    public var delete: Int
    public var type: String

    public init(delete: Int, type: String) {
        self.delete = delete
        self.type = type
    }

    /// More than this, and something has gone wrong (the cursor was moved, say):
    /// Murmur stops typing rather than delete text that may not be its own.
    public static let mostToDelete = 300

    public var isNothing: Bool { delete == 0 && type.isEmpty }

    /// Whether this can be done without touching more than it should: never a
    /// lot at once, and never the first `keeping` characters of what's typed.
    public func isSafe(typedCount: Int, keeping: Int = 0) -> Bool {
        delete <= Self.mostToDelete && typedCount - delete >= keeping
    }

    public static func from(_ typed: String, to target: String) -> LiveEdit {
        var same = 0
        for (a, b) in zip(typed, target) {
            guard a == b else { break }
            same += 1
        }
        return LiveEdit(delete: typed.count - same, type: String(target.dropFirst(same)))
    }
}

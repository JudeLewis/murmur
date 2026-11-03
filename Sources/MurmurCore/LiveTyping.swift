import Foundation

// Type as I speak (SPEC.md 2.9). While you talk, Murmur reads the last few
// seconds again about once a second and types each word once two readings in
// a row agree on it, so the text runs a second or two behind your voice.

/// A word the speech model heard, with when it was said (seconds from the start of the recording).
public struct HeardWord: Equatable, Sendable {
    public var text: String
    public var start: Double
    public var end: Double

    public init(_ text: String, start: Double, end: Double) {
        self.text = text
        self.start = start
        self.end = end
    }

    var middle: Double { (start + end) / 2 }
}

/// Which words are settled. Settled words never change; only the text after them is read again.
public struct LiveTranscript: Equatable, Sendable {
    /// Seconds of already settled speech given to the model again, so it hears the new words in context.
    public static let context: Double = 5
    /// If nothing has settled for this long, the words heard up to `forceGap` ago are settled anyway,
    /// so the model never has to read more than a few seconds.
    public static let forceAfter: Double = 8
    public static let forceGap: Double = 2
    /// A word ending this close to the end of what's been heard may be cut off
    /// (its timing too), so it waits for the next reading.
    public static let cutOff: Double = 0.3

    public private(set) var settled: [String] = []
    /// When the settled words end.
    public private(set) var settledUntil: Double = 0
    /// The last reading's unsettled words, to compare with the next one.
    private var previous: [String] = []

    /// Silence added after the last reading: without it the model can leave
    /// the last sentence without its full stop or question mark (seen 3 Nov 2026).
    public static let endSilence: Double = 0.6

    public init() {}

    /// Where the next reading should start.
    public var windowStart: Double { max(0, settledUntil - Self.context) }

    /// The settled words as text, as the model wrote them.
    public var text: String { settled.joined(separator: " ") }

    /// A reading of the audio from `windowStart` to `now` (times already from the
    /// start of the recording). Returns the words it settled.
    public mutating func heard(_ words: [HeardWord], now: Double) -> [String] {
        let fresh = unsettled(words)
        var agreed = 0
        while agreed < min(fresh.count, previous.count), fresh[agreed].text == previous[agreed] { agreed += 1 }
        var settling = Array(fresh.prefix(agreed).prefix { $0.end <= now - Self.cutOff })
        if settling.isEmpty, now - settledUntil > Self.forceAfter {
            settling = Array(fresh.prefix { $0.end <= now - Self.forceGap })
        }
        settle(settling)
        previous = fresh.dropFirst(settling.count).map(\.text)
        // A long pause: move on, so the silence isn't read again every second.
        if settling.isEmpty, now - settledUntil > Self.forceAfter {
            settledUntil = max(settledUntil, min(now - Self.forceGap, (fresh.first?.start ?? .infinity) - 0.01))
        }
        return settling.map(\.text)
    }

    /// The last reading, once listening has stopped: everything in it is settled.
    public mutating func finished(_ words: [HeardWord]) -> [String] {
        let fresh = unsettled(words)
        settle(fresh)
        previous = []
        return fresh.map(\.text)
    }

    /// Words from the context part are dropped: a word belongs to the settled
    /// part if most of it was said before the settled words end.
    private func unsettled(_ words: [HeardWord]) -> [HeardWord] {
        var fresh = words.filter { $0.middle > settledUntil && !$0.text.isEmpty }
        // The last settled word heard again, timed a little later this time.
        if let first = fresh.first, let last = settled.last, first.start < settledUntil, Self.same(first.text, last) {
            fresh.removeFirst()
        }
        return fresh
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        let plain = { (word: String) in word.lowercased().filter { $0.isLetter || $0.isNumber } }
        return plain(a) == plain(b)
    }

    private mutating func settle(_ words: [HeardWord]) {
        guard let last = words.last else { return }
        settled += words.map(\.text)
        settledUntil = max(settledUntil, last.end)
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

    public static func from(_ typed: String, to target: String) -> LiveEdit {
        var same = 0
        for (a, b) in zip(typed, target) {
            guard a == b else { break }
            same += 1
        }
        return LiveEdit(delete: typed.count - same, type: String(target.dropFirst(same)))
    }
}

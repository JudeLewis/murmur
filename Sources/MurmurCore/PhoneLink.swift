import Foundation

// iOS doesn't let a keyboard use the microphone, so on iPhone the Murmur app
// listens and writes, and the Murmur keyboard asks it to and types the result.
// They talk through two small files in their shared folder (see LinkStore).

/// What the keyboard asks the app to do.
public enum KeyboardRequestKind: String, Codable, Sendable {
    case start
    case stop
    case cancel
    /// The keyboard's "turn mic off" button: end the session now.
    case turnOff
}

public struct KeyboardRequest: Codable, Equatable, Sendable {
    /// Unique and rising: when the keyboard sent it, in milliseconds since 1970.
    public var id: Int
    public var kind: KeyboardRequestKind
    /// The keyboard's casual switch (no capital at the start, no full stop at the end).
    public var casual: Bool?

    public init(id: Int, kind: KeyboardRequestKind, casual: Bool? = nil) {
        self.id = id
        self.kind = kind
        self.casual = casual
    }

    public static func newID(at date: Date = .now) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }
}

/// A finished dictation, for the keyboard that asked for it.
public struct PhoneResult: Codable, Equatable, Sendable {
    /// The recording's id: the id of the keyboard's start request, or 0 for the app's own Talk button.
    public var id: Int
    /// The tidied text, ready to type in. Empty if nothing was heard.
    public var text: String
    /// Set when the recording couldn't be turned into text.
    public var problem: String?
    /// "press enter" was said at the end: type a Return after the text.
    public var pressEnter: Bool?

    public init(id: Int, text: String, problem: String? = nil, pressEnter: Bool? = nil) {
        self.id = id
        self.text = text
        self.problem = problem
        self.pressEnter = pressEnter
    }
}

/// What the app tells the keyboard. Only the app writes it.
public struct PhoneStatus: Codable, Equatable, Sendable {
    /// The microphone is on and the keyboard can talk without opening the app.
    public var session = false
    public var phase = DictationPhase.idle
    /// The id of the recording being made or written, 0 if the app's own.
    public var recording = 0
    /// While the speech model gets ready: how far, 0 to 100. Nil once it's ready.
    public var preparing: Int?
    /// Updated every couple of seconds while the session is on. If it goes
    /// quiet, iOS has closed the app and the keyboard must open it again.
    public var heartbeat = Date.distantPast
    public var result: PhoneResult?
    /// How loud the microphone is while listening, 0 to about 1, for the keyboard's bars.
    public var level: Float?

    public init() {}
}

/// What the keyboard shows and what its Talk button does.
public enum KeyboardState: Equatable, Sendable {
    /// iOS only shares the folder with a keyboard that has Full Access.
    case needsFullAccess
    /// No session: Talk opens the Murmur app to turn the microphone on.
    case needsApp
    case ready(preparing: Int?)
    case listening
    case writing(preparing: Int?)
}

public enum KeyboardLink {
    /// How often the app updates its heartbeat during a session.
    public static let heartbeatEvery: TimeInterval = 2
    /// How old a heartbeat can be before the keyboard decides the app has gone.
    public static let aliveFor: TimeInterval = 6
    /// The link the keyboard opens to start a session.
    public static let startURL = URL(string: "murmur://start")!

    public static func isStart(_ url: URL) -> Bool {
        url.scheme == startURL.scheme && url.host == startURL.host
    }

    /// The app answers each request once. Ids come from the clock, so this
    /// checks for a different id rather than a later one, in case the clock goes back.
    public static func isNew(_ request: KeyboardRequest?, lastAnswered: Int) -> Bool {
        guard let request else { return false }
        return request.id != lastAnswered
    }

    public static func state(of status: PhoneStatus?, now: Date, fullAccess: Bool) -> KeyboardState {
        guard fullAccess else { return .needsFullAccess }
        guard let status, status.session, now.timeIntervalSince(status.heartbeat) < aliveFor else { return .needsApp }
        switch status.phase {
        case .idle: return .ready(preparing: status.preparing)
        case .recording: return .listening
        case .transcribing: return .writing(preparing: status.preparing)
        }
    }

    public enum Tap: Equatable, Sendable {
        case openApp
        case send(KeyboardRequestKind)
        case nothing
    }

    /// The "turn mic off" button shows only while a session is on and nothing is
    /// being said or written, so it can't throw a dictation away by accident.
    public static func canTurnOff(in state: KeyboardState) -> Bool {
        if case .ready = state { return true }
        return false
    }

    /// The model can still be getting ready: the recording waits for it, as on the Mac.
    public static func tap(in state: KeyboardState) -> Tap {
        switch state {
        case .needsFullAccess, .writing: .nothing
        case .needsApp: .openApp
        case .ready: .send(.start)
        case .listening: .send(.stop)
        }
    }

    public enum Delivery: Equatable, Sendable {
        case type(String, pressEnter: Bool)
        case note(String)
        case nothing
    }

    /// Only the keyboard that asked for a dictation types it, and only once.
    public static func delivery(of result: PhoneResult?, waitingFor id: Int?) -> Delivery {
        guard let result, let id, result.id == id else { return .nothing }
        if let problem = result.problem { return .note(problem) }
        let pressEnter = result.pressEnter ?? false
        if result.text.isEmpty && !pressEnter { return .note("Didn't catch that.") }
        return .type(result.text, pressEnter: pressEnter)
    }
}

/// Which dictation this keyboard will type when it's ready.
public struct KeyboardWait: Equatable, Sendable {
    public private(set) var id: Int?

    public init() {}

    /// Stop picks up the recording the app is making, so a keyboard that was
    /// closed and opened again while listening still types the text.
    public mutating func sent(_ request: KeyboardRequest, recording: Int?) {
        switch request.kind {
        case .start: id = request.id
        case .stop: if let recording, recording != 0 { id = recording }
        case .cancel, .turnOff: id = nil
        }
    }

    /// The keyboard closed: text that finishes later isn't typed anywhere.
    public mutating func keyboardClosed() { id = nil }

    /// What to do with the app's latest result. Once used, it's not used again.
    public mutating func deliver(_ result: PhoneResult?) -> KeyboardLink.Delivery {
        let delivery = KeyboardLink.delivery(of: result, waitingFor: id)
        if delivery != .nothing { id = nil }
        return delivery
    }
}

/// The keyboard's Undo: takes the last dictation back out, as long as the
/// cursor is still straight after it.
public struct LastTyped: Equatable, Sendable {
    public private(set) var text: String?

    public init() {}

    public mutating func typed(_ text: String) {
        self.text = text.isEmpty ? nil : text
    }

    /// How many characters to delete, or nil if the text before the cursor
    /// doesn't end with the dictation (the cursor moved, or it was edited).
    /// iOS often shows a keyboard only the current line or a short tail, so a
    /// tail of at least a few characters that ends the dictation counts too.
    public mutating func undo(before: String?) -> Int? {
        guard let text, let before else { return nil }
        let fullyVisible = before.hasSuffix(text)
        let tailVisible = before.count >= 4 && !before.contains("\n") && text.hasSuffix(before)
        guard fullyVisible || tailVisible else { return nil }
        self.text = nil
        return text.count
    }
}

/// The keyboard's moving bars: the last few loudness readings, newest last.
public struct LevelHistory: Equatable, Sendable {
    public static let bars = 16
    public private(set) var levels = [Float](repeating: 0, count: bars)

    public init() {}

    public mutating func add(_ level: Float) {
        levels.removeFirst()
        levels.append(min(1, max(0, level)))
    }

    public mutating func clear() {
        levels = [Float](repeating: 0, count: Self.bars)
    }
}

/// A keyboard session: the microphone stays on so Talk works without opening
/// the app each time. It ends after 10 minutes without a dictation.
public struct PhoneSession: Equatable, Sendable {
    public static let idleLimit: TimeInterval = 10 * 60

    public private(set) var lastUsed: Date?

    public init() {}

    public var isOn: Bool { lastUsed != nil }
    public var endsAt: Date? { lastUsed?.addingTimeInterval(Self.idleLimit) }

    public mutating func start(at now: Date) { lastUsed = now }
    public mutating func used(at now: Date) { if isOn { lastUsed = now } }
    public mutating func end() { lastUsed = nil }

    /// Never ends in the middle of listening or writing.
    public func shouldEnd(at now: Date, phase: DictationPhase) -> Bool {
        guard let endsAt, phase == .idle else { return false }
        return now >= endsAt
    }
}

/// Where a dictation is: waiting, listening, or turning speech into text.
public enum DictationPhase: String, Codable, Equatable, Sendable {
    case idle
    case recording
    case transcribing
}

/// What the app should do in response to an event.
public enum DictationAction: Equatable, Sendable {
    case startRecording
    case stopAndTranscribe
    case cancelRecording
    case nothing
}

/// The on/off switch behind the Fn double tap. The app does the work; this
/// only decides what each event means, so it can be tested without a microphone.
public struct DictationFlow: Sendable {
    public private(set) var phase: DictationPhase = .idle
    /// This dictation was started by holding Fn, so letting go finishes it.
    public private(set) var heldOpen = false

    public init() {}

    /// Double tap of Fn, or Start/Stop in the menu.
    public mutating func toggle() -> DictationAction {
        switch phase {
        case .idle:
            phase = .recording
            return .startRecording
        case .recording:
            phase = .transcribing
            return .stopAndTranscribe
        case .transcribing:
            // Text from the last recording is still on its way; ignore until it lands.
            return .nothing
        }
    }

    /// Fn held on its own (SPEC.md 2.5). Ignored in the middle of a dictation.
    public mutating func holdStarted() -> DictationAction {
        guard phase == .idle else { return .nothing }
        heldOpen = true
        return toggle()
    }

    /// Fn let go: finishes only a dictation the hold started.
    public mutating func holdEnded() -> DictationAction {
        guard heldOpen else { return .nothing }
        heldOpen = false
        return phase == .recording ? toggle() : .nothing
    }

    /// Another key pressed during the hold.
    public mutating func holdCancelled() -> DictationAction {
        guard heldOpen else { return .nothing }
        return cancel()
    }

    /// Escape while listening throws the recording away.
    public mutating func cancel() -> DictationAction {
        heldOpen = false
        guard phase == .recording else { return .nothing }
        phase = .idle
        return .cancelRecording
    }

    /// "Try the last recording again" from the menu, after a failed attempt.
    /// Returns false if Murmur is busy listening or writing.
    public mutating func retry() -> Bool {
        guard phase == .idle else { return false }
        phase = .transcribing
        return true
    }

    /// A request from the iPhone keyboard. Start and stop are separate, not a
    /// toggle, so a keyboard showing an old state can't stop what it meant to start.
    public mutating func handle(_ request: KeyboardRequestKind) -> DictationAction {
        switch (request, phase) {
        case (.start, .idle), (.stop, .recording): toggle()
        case (.cancel, _): cancel()
        default: .nothing
        }
    }

    /// The text was pasted, or nothing was heard, or something failed.
    public mutating func finished() {
        phase = .idle
        heldOpen = false
    }
}

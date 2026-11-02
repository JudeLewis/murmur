/// Where a dictation is: waiting, listening, or turning speech into text.
public enum DictationPhase: Equatable, Sendable {
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

    /// Escape while listening throws the recording away.
    public mutating func cancel() -> DictationAction {
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

    /// The text was pasted, or nothing was heard, or something failed.
    public mutating func finished() {
        phase = .idle
    }
}

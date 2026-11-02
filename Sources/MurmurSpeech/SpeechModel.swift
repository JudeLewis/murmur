import FluidAudio

/// Which speech model turns speech into text.
public enum SpeechModel: String, CaseIterable, Sendable {
    /// Bark 3.0 Clean: drops "um", "er", false starts and repeated words.
    case tidy
    /// Bark 3.0: everything exactly as said.
    case exact

    var version: AsrModelVersion {
        switch self {
        case .tidy: .bark3Clean
        case .exact: .bark3
        }
    }
}

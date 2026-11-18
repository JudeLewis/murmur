import FluidAudio
import Foundation
import MurmurCore

/// Which speech model turns speech into text (SPEC.md 3.1).
public enum SpeechModel: String, CaseIterable, Sendable {
    /// Bark 3.0 Clean: drops "um", "er", false starts and repeated words.
    case tidy
    /// Bark 3.0: everything exactly as said.
    case exact
    /// Parakeet Ultra: fewer mistakes in FluidAudio's published tests (3.81% of words wrong
    /// against Bark Clean's 4.66%), but it keeps "um", so Murmur takes those out by fixed rules.
    case ultra

    var version: AsrModelVersion {
        switch self {
        case .tidy: .bark3Clean
        case .exact: .bark3
        case .ultra: .ultra
        }
    }

    /// Whether Murmur takes out "um" and "er" itself (Fillers in MurmurCore).
    public var keepsFillers: Bool { self == .ultra }

    /// The text with "um" and "er" taken out if this model keeps them. Used once on the whole
    /// text, however it was put together (all at once, quieter voices left out, or typed as you
    /// speak), so commas and capitals around a filler are always handled the same way.
    public func withoutFillers(_ text: String) -> String {
        keepsFillers ? Fillers.remove(from: text) : text
    }

    /// Whether this model is already on this device, so choosing it needs no download.
    public var isDownloaded: Bool {
        AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: version), version: version)
    }
}

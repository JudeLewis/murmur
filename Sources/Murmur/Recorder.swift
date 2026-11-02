import AVFoundation
import MurmurSpeech
import os

/// Records the default microphone into memory, as mono samples at the
/// microphone's own rate. Nothing is written to disk.
/// Used from the main thread only; the audio thread touches just `captured`.
final class Recorder {
    enum RecorderError: LocalizedError {
        case noMicrophone
        var errorDescription: String? { "No microphone found." }
    }

    private struct Captured {
        var samples: [Float] = []
        var level: Float = 0
    }

    private let engine = AVAudioEngine()
    private let captured = OSAllocatedUnfairLock(initialState: Captured())
    let sampleRate: Double

    /// Starts listening straight away. A fresh recorder is made for each
    /// dictation, so a microphone plugged in since last time is picked up.
    init() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.noMicrophone }
        sampleRate = format.sampleRate

        captured.withLock { $0.samples.reserveCapacity(Int(format.sampleRate) * 60) }
        input.installTap(onBus: 0, bufferSize: 2048, format: format, block: Self.tapBlock(into: captured))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    /// Loudness of the last few milliseconds, 0 to about 1, for the pill's bars.
    var level: Float { captured.withLock { $0.level } }

    /// Stops the microphone and hands back everything heard.
    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return captured.withLock { $0.samples }
    }

    /// Built outside any actor: the audio thread calls it, not the main thread.
    private static func tapBlock(into captured: OSAllocatedUnfairLock<Captured>) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let (heard, level) = MonoMix.mix(buffer) else { return }
            captured.withLock {
                $0.samples.append(contentsOf: heard)
                $0.level = level
            }
        }
    }
}

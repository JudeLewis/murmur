import AVFoundation
import MurmurSpeech
import os

/// The microphone for a keyboard session. It runs for the whole session, so
/// iOS lets Murmur keep listening in the background, but sound is only kept
/// between `beginCapture` and `endCapture`. Everything else is thrown away
/// as it arrives. Nothing is written to disk.
final class SessionMic {
    enum MicError: LocalizedError {
        case noMicrophone
        var errorDescription: String? { "No microphone found." }
    }

    private struct Captured {
        var capturing = false
        var samples: [Float] = []
        var level: Float = 0
    }

    private let engine = AVAudioEngine()
    private let captured = OSAllocatedUnfairLock(initialState: Captured())
    private(set) var sampleRate: Double = 0

    var isRunning: Bool { engine.isRunning }

    /// Loudness while capturing, 0 to about 1, for the keyboard's bars.
    var level: Float { captured.withLock { $0.level } }

    /// Also used to restart after iOS changes the microphone (AirPods in or out).
    func start() throws {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw MicError.noMicrophone }
        sampleRate = format.sampleRate
        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.tapBlock(into: captured))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        captured.withLock { $0 = Captured() }
    }

    func beginCapture() {
        let reserve = Int(sampleRate) * 60
        captured.withLock {
            $0.samples = []
            $0.samples.reserveCapacity(reserve)
            $0.capturing = true
        }
    }

    /// Stops keeping sound and hands back what was kept.
    func endCapture() -> [Float] {
        captured.withLock {
            let samples = $0.samples
            $0 = Captured()
            return samples
        }
    }

    /// Built outside any actor: the audio thread calls it, not the main thread.
    private static func tapBlock(into captured: OSAllocatedUnfairLock<Captured>) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard captured.withLock({ $0.capturing }), let (heard, level) = MonoMix.mix(buffer) else { return }
            captured.withLock {
                guard $0.capturing else { return }
                $0.samples.append(contentsOf: heard)
                $0.level = level
            }
        }
    }
}

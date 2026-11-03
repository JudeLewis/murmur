import AVFoundation
import MurmurSpeech
import os

/// Records the default microphone into memory, as mono samples at the
/// microphone's own rate. Nothing is written to disk.
/// Used from the main thread only; the audio thread touches just `captured`.
final class Recorder {
    enum RecorderError: LocalizedError {
        case noMicrophone
        case couldNotUseDevice
        var errorDescription: String? {
            switch self {
            case .noMicrophone: "No microphone found."
            case .couldNotUseDevice: "Couldn't use the chosen microphone."
            }
        }
    }

    private struct Captured {
        var samples: [Float] = []
        var level: Float = 0
        var paused = false
    }

    private let engine = AVAudioEngine()
    private let captured = OSAllocatedUnfairLock(initialState: Captured())
    let sampleRate: Double

    /// Starts listening straight away. A fresh recorder is made for each
    /// dictation, so a microphone plugged in since last time is picked up.
    /// `device` is the microphone to use; nil means the Mac's default input.
    init(device: AudioDeviceID? = nil) throws {
        let input = engine.inputNode
        if var device {
            guard let unit = input.audioUnit, AudioUnitSetProperty(
                unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                &device, UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr else { throw RecorderError.couldNotUseDevice }
        }
        // A chosen mic: the tap takes that mic's own format (AirPods run at a different
        // rate from the built-in mic), since a tap whose rate differs from the mic's crashes.
        let format = device == nil ? input.outputFormat(forBus: 0) : input.inputFormat(forBus: 0)
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

    /// Paused (SPEC.md 2.10): what's heard meanwhile isn't kept at all.
    var paused: Bool {
        get { captured.withLock { $0.paused } }
        set { captured.withLock { $0.paused = newValue; $0.level = 0 } }
    }

    /// Loudness of the last few milliseconds, 0 to about 1, for the pill's bars.
    var level: Float { captured.withLock { $0.level } }

    /// For Type as I speak: what's been heard from `second` on (only that part
    /// is copied), and how many seconds have been heard in all.
    func heard(from second: Double) -> (samples: [Float], until: Double) {
        let rate = sampleRate
        return captured.withLock { captured in
            let start = min(captured.samples.count, max(0, Int(second * rate)))
            return (Array(captured.samples[start...]), Double(captured.samples.count) / rate)
        }
    }

    /// Stops the microphone without copying what was heard (Type as I speak
    /// reads only what it needs); hands back how many seconds were heard.
    func stopListening() -> Double {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let rate = sampleRate
        return captured.withLock { Double($0.samples.count) / rate }
    }

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
                guard !$0.paused else { return }
                $0.samples.append(contentsOf: heard)
                $0.level = level
            }
        }
    }
}

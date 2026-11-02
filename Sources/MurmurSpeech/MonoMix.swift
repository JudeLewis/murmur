import AVFoundation

/// Turns one buffer from the microphone into mono samples and a loudness
/// level, 0 to about 1, for the moving bars. Called on the audio thread.
public enum MonoMix {
    public static func mix(_ buffer: AVAudioPCMBuffer) -> (samples: [Float], level: Float)? {
        guard let channels = buffer.floatChannelData else { return nil }
        let frames = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frames > 0, channelCount > 0 else { return nil }

        var mono = [Float](repeating: 0, count: frames)
        for channel in 0..<channelCount {
            let data = channels[channel]
            for frame in 0..<frames { mono[frame] += data[frame] }
        }
        var sumOfSquares: Float = 0
        for frame in 0..<frames {
            mono[frame] /= Float(channelCount)
            sumOfSquares += mono[frame] * mono[frame]
        }
        return (mono, min(1, (sumOfSquares / Float(frames)).squareRoot() * 8))
    }
}

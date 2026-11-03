import FluidAudio
import Foundation
import MurmurCore

/// Turns recorded samples into text with a Parakeet model, on this device.
///
/// The model downloads once (about 400 MB) into Application Support/FluidAudio
/// (in ~/Library on the Mac, in the app's own folder on the iPhone), then loads from there.
public actor Transcriber {
    public init() {}

    private var loaded: (model: SpeechModel, task: Task<AsrManager, Error>)?

    /// Starts loading `model` if it isn't already. Safe to call again; a failed
    /// load is forgotten so the next call tries afresh.
    public func prepare(_ model: SpeechModel, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        _ = try await manager(for: model, progress: progress)
    }

    /// Samples are mono at `sampleRate`; they are resampled to the 16 kHz the model needs.
    public func transcribe(_ samples: [Float], sampleRate: Double, model: SpeechModel) async throws -> String {
        try await result(samples, sampleRate: sampleRate, model: model).text
    }

    /// For Type as I speak: each word heard, with when it was said (seconds from the start of `samples`).
    public func words(_ samples: [Float], sampleRate: Double, model: SpeechModel) async throws -> [HeardWord] {
        let timings = try await result(samples, sampleRate: sampleRate, model: model).tokenTimings ?? []
        return buildWordTimings(from: timings).map { HeardWord($0.word, start: $0.startTime, end: $0.endTime) }
    }

    private func result(_ samples: [Float], sampleRate: Double, model: SpeechModel) async throws -> ASRResult {
        let manager = try await manager(for: model)
        var audio = try AudioConverter().resample(samples, from: sampleRate)

        // The model needs at least a second; pad short clips with silence.
        if audio.count < 16_000 { audio += [Float](repeating: 0, count: 16_000 - audio.count) }

        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(audio, decoderState: &state)
    }

    /// For test mode: reads a sound file as mono 16 kHz samples.
    public static func samples(fromFile url: URL) throws -> [Float] {
        try AudioConverter().resampleAudioFile(url)
    }

    private func manager(
        for model: SpeechModel, progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> AsrManager {
        if loaded?.model != model {
            let task = Task {
                let models = try await AsrModels.downloadAndLoad(
                    version: model.version,
                    progressHandler: { progress($0.fractionCompleted) })
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)
                return manager
            }
            loaded = (model, task)
        }
        guard let task = loaded?.task else { throw CancellationError() }
        do {
            return try await task.value
        } catch {
            if loaded?.model == model { loaded = nil }
            throw error
        }
    }
}

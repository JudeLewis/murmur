import FluidAudio
import Foundation

/// Turns recorded samples into text with a Parakeet model, on this Mac.
///
/// The model downloads once (about 400 MB) into
/// ~/Library/Application Support/FluidAudio, then loads from there.
actor Transcriber {
    private var loaded: (model: SpeechModel, task: Task<AsrManager, Error>)?

    /// Starts loading `model` if it isn't already. Safe to call again; a failed
    /// load is forgotten so the next call tries afresh.
    func prepare(_ model: SpeechModel, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        _ = try await manager(for: model, progress: progress)
    }

    /// Samples are mono at `sampleRate`; they are resampled to the 16 kHz the model needs.
    func transcribe(_ samples: [Float], sampleRate: Double, model: SpeechModel) async throws -> String {
        let manager = try await manager(for: model)
        var audio = try AudioConverter().resample(samples, from: sampleRate)

        // The model needs at least a second; pad short clips with silence.
        if audio.count < 16_000 { audio += [Float](repeating: 0, count: 16_000 - audio.count) }

        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(audio, decoderState: &state).text
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

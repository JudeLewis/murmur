import AppKit
import MurmurCore
import MurmurSpeech

/// Type as I speak (SPEC.md 2.9): while listening, reads the recording again
/// about once a second and types the words that have settled. Which words have
/// settled, and what to delete and type, is decided in MurmurCore (LiveTyping).
@MainActor
final class LiveTyper {
    private let recorder: Recorder
    private let transcriber: Transcriber
    private let model: SpeechModel
    private let whisper: Bool
    /// The settled words as they should look: tidying, spelling, the word list and so on.
    private let shape: (String) -> Dictation
    private var live = LiveTranscript()
    private var loop: Task<Void, Never>?
    /// What Murmur has typed so far in this dictation.
    private(set) var typed = ""
    /// Set if it would have had to delete too much; nothing more is typed.
    private(set) var gaveUp = false
    /// The last reading failed, so the last words may be missing.
    private(set) var lostTheEnd = false
    /// Escape: a reading still under way mustn't type anything.
    private var stopped = false
    /// What was on the clipboard before the first line break was pasted, put back once at the end.
    private var clipboard: (saved: [NSPasteboardItem], ourChange: Int)?

    init(recorder: Recorder, transcriber: Transcriber, model: SpeechModel, whisper: Bool, shape: @escaping (String) -> Dictation) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.model = model
        self.whisper = whisper
        self.shape = shape
    }

    func start() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                await self.readAgain()
            }
        }
    }

    /// Escape: stop reading; what's typed stays.
    func stop() {
        stopped = true
        loop?.cancel()
        loop = nil
        putClipboardBack()
    }

    /// Listening has stopped: reads the rest, types it with a space after
    /// it, and hands back the finished dictation.
    func finish() async -> Dictation {
        loop?.cancel()
        // A reading already under way finishes first, so two never mix.
        await loop?.value
        loop = nil
        let start = live.windowStart
        let silence = [Float](repeating: 0, count: Int(LiveTranscript.endSilence * recorder.sampleRate))
        let rest = recorder.heard(from: start).samples + silence
        // Once more if it fails: otherwise the last words would be lost.
        if let words = await read(rest, from: start), !stopped {
            _ = live.finished(words)
        } else if let words = await read(rest, from: start), !stopped {
            _ = live.finished(words)
        } else {
            lostTheEnd = true
            log.error("Type as I speak couldn't read the last words")
        }
        let dictation = shape(live.text)
        await show(Tidy.forInsertion(dictation.text, pressEnter: dictation.pressEnter), final: true)
        putClipboardBack()
        return dictation
    }

    private func readAgain() async {
        let start = live.windowStart
        let (samples, until) = recorder.heard(from: start)
        guard let words = await read(samples, from: start), !live.heard(words, now: until).isEmpty else { return }
        await show(shape(live.text).text, final: false)
    }

    /// The words in `samples`, with times from the start of the recording.
    private func read(_ samples: [Float], from start: Double) async -> [HeardWord]? {
        let rate = recorder.sampleRate
        let audio = whisper ? await Task.detached { Loudness.boosted(samples, maxGain: Loudness.whisperGain) }.value : samples
        guard let words = try? await transcriber.words(audio, sampleRate: rate, model: model) else { return nil }
        return words.map { HeardWord($0.text, start: $0.start + start, end: $0.end + start) }
    }

    /// Changes what's been typed into `target`.
    private func show(_ target: String, final: Bool) async {
        guard !gaveUp, !stopped else { return }
        let edit = LiveEdit.from(typed, to: target)
        guard !edit.isNothing else { return }
        guard edit.delete <= LiveEdit.mostToDelete else {
            gaveUp = true
            log.error("Type as I speak gave up: it would have deleted \(edit.delete) characters")
            return
        }
        // Fn and Delete deletes forwards, so while Fn is held (Hold Fn to talk)
        // deleting waits for the next reading, or the end.
        if edit.delete > 0, Paster.fnHeld {
            guard final else { return }
            await Paster.waitForKeysUp()
            guard !stopped else { return }
        }
        Paster.deleteBackward(edit.delete)
        // A typed line break would send a message in many apps; a pasted one doesn't.
        if edit.type.contains(where: \.isNewline) {
            let saved = clipboard?.saved ?? Paster.snapshot()
            if let ourChange = Paster.pasteLeavingClipboard(edit.type) { clipboard = (saved, ourChange) }
        } else {
            Paster.type(edit.type)
        }
        typed = target
    }

    private func putClipboardBack() {
        guard let clipboard else { return }
        self.clipboard = nil
        Paster.restore(clipboard.saved, after: clipboard.ourChange)
    }
}

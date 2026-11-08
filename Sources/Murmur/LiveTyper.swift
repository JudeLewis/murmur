import AppKit
import MurmurCore
import MurmurSpeech

/// Type as I speak (SPEC.md 2.9): while listening, reads the whole recording
/// again about once a second, types new words and corrects what's typed. Which
/// words to show, and what to delete and type, is decided in MurmurCore (LiveTyping).
@MainActor
final class LiveTyper {
    private let recorder: Recorder
    private let transcriber: Transcriber
    private let model: SpeechModel
    private let whisper: Bool
    /// The words as they should look: other voices left out, tidying, spelling and so on.
    private let shape: ([HeardWord]) -> Dictation
    private var live = LiveTranscript()
    private var loop: Task<Void, Never>?
    /// The app being typed into: if another comes to the front, the cursor has gone.
    private let app: String?
    /// What Murmur has typed so far in this dictation.
    private(set) var typed = ""
    /// This much of `typed` is never deleted: the cursor may have moved since it was typed.
    private var keeping = 0
    /// Set if it would have had to delete too much; nothing more is typed.
    private(set) var gaveUp = false
    /// The last reading failed, so the last words may be missing.
    private(set) var lostTheEnd = false
    /// Escape: a reading still under way mustn't type anything.
    private var stopped = false
    /// What was on the clipboard before the first line break was pasted, put back once at the end.
    private var clipboard: (saved: [NSPasteboardItem], ourChange: Int)?

    init(
        recorder: Recorder, transcriber: Transcriber, model: SpeechModel, whisper: Bool, app: String?,
        shape: @escaping ([HeardWord]) -> Dictation
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.model = model
        self.whisper = whisper
        self.app = app
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

    /// A click or a key press while listening: the cursor may have moved, so
    /// nothing typed so far is deleted or corrected from here on.
    func cursorMayHaveMoved() {
        guard keeping != typed.count else { return }
        keeping = typed.count
        live.lockEverything()
        log.notice("Cursor may have moved: no more corrections to what's typed")
    }

    /// Listening has stopped: reads the whole recording once more, makes what's
    /// typed match, adds a space, and hands back the finished dictation.
    func finish() async -> Dictation {
        loop?.cancel()
        // A reading already under way finishes first, so two never mix.
        await loop?.value
        loop = nil
        let silence = [Float](repeating: 0, count: Int(LiveTranscript.endSilence * recorder.sampleRate))
        let everything = recorder.heard().samples + silence
        // Once more if it fails: otherwise the last words would be lost.
        if let words = await read(everything), !stopped {
            live.finished(words)
        } else if let words = await read(everything), !stopped {
            live.finished(words)
        } else {
            lostTheEnd = true
            log.error("Type as I speak couldn't read the last words")
        }
        let dictation = shape(live.words)
        await show(Tidy.forInsertion(dictation.text, pressEnter: dictation.pressEnter), final: true)
        putClipboardBack()
        return dictation
    }

    private func readAgain() async {
        let (samples, until) = recorder.heard()
        guard let words = await read(samples), !stopped, live.heard(words, now: until) else { return }
        await show(shape(live.words).text, final: false)
    }

    /// The words in `samples`, which start at the start of the recording.
    private func read(_ samples: [Float]) async -> [HeardWord]? {
        let rate = recorder.sampleRate
        // Each reading gets its own Whisper boost, so loudness is put back to as heard,
        // or other people's voices couldn't be told from yours (SPEC.md 4.10).
        let (audio, gain) = whisper
            ? await Task.detached { () -> ([Float], Float) in
                let gain = Loudness.gain(for: samples, maxGain: Loudness.whisperGain)
                return (gain == 1 ? samples : samples.map { $0 * gain }, gain)
            }.value
            : (samples, 1)
        guard let words = try? await transcriber.words(audio, sampleRate: rate, model: model) else { return nil }
        return words.map { HeardWord($0.text, start: $0.start, end: $0.end, loudness: $0.loudness.map { $0 / gain }) }
    }

    /// Changes what's been typed into `target`.
    private func show(_ target: String, final: Bool) async {
        guard !gaveUp, !stopped else { return }
        if let app, NSWorkspace.shared.frontmostApplication?.bundleIdentifier != app { cursorMayHaveMoved() }
        let edit = LiveEdit.from(typed, to: target)
        guard !edit.isNothing else { return }
        guard edit.isSafe(typedCount: typed.count, keeping: keeping) else {
            gaveUp = true
            log.error("Type as I speak gave up: it would have deleted \(edit.delete) characters, keeping \(self.keeping)")
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

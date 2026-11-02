import AVFoundation
import MurmurCore
import MurmurSpeech
import MurmurUI
import Observation
import UIKit
import os

let log = Logger(subsystem: "com.judelewis.murmur", category: "iphone")

/// Everything the Murmur app does: loads the model, runs keyboard sessions,
/// answers the keyboard, and records from its own Talk button. The rules it
/// follows live in MurmurCore (DictationFlow, PhoneSession, KeyboardLink).
@MainActor
@Observable
final class PhoneMurmur {
    // What the screen shows.
    var phase: DictationPhase { flow.phase }
    var sessionOn: Bool { session.isOn }
    /// 0 to 100 while the model gets ready; nil once it's ready.
    private(set) var preparing: Int? = 0 {
        // The phone mustn't lock mid-way: getting ready can take minutes after an update.
        didSet { UIApplication.shared.isIdleTimerDisabled = preparing != nil }
    }
    /// When getting ready started, for the timer on screen.
    private(set) var preparingSince: Date?
    private(set) var modelProblem: String?
    private(set) var micProblem: String?
    /// The last dictation from the app's own Talk button.
    private(set) var lastText: String?
    private(set) var note: String?
    /// Set when the keyboard opened the app, to show how to go back.
    var openedFromKeyboard = false

    private(set) var recent: RecentList
    var tidy: Bool { didSet { defaults.set(tidy, forKey: "tidy"); loadModel() } }
    var british: Bool { didSet { defaults.set(british, forKey: "british") } }
    /// The word list and snippets screens.
    @ObservationIgnored private(set) lazy var words = WordsModel(
        words: WordList.parse(defaults.string(forKey: "words") ?? WordList.template),
        snippets: Snippets.decode(defaults.data(forKey: "snippets")),
        recent: { [weak self] in self?.recent.items ?? [] },
        saveWords: { [weak self] in self?.defaults.set(WordList.text(for: $0), forKey: "words") },
        saveSnippets: { [weak self] in self?.defaults.set(Snippets.encode($0), forKey: "snippets") })

    private let defaults = UserDefaults.standard
    private let transcriber = Transcriber()
    private let mic = SessionMic()
    private let store = Shared.store
    private var flow = DictationFlow()
    private var session = PhoneSession()
    /// The recording being made: the keyboard's start request, or 0 for the app's own.
    private var recording = 0
    private var lastRequest = 0
    private var result: PhoneResult?
    /// The app's Talk button turned the microphone on just for one dictation.
    private var endAfterDictation = false
    /// The keyboard's casual switch when this recording started.
    private var casual = false
    /// Only the newest model load may say the model is ready.
    private var loadNumber = 0
    @ObservationIgnored private var heartbeat: Timer?
    @ObservationIgnored private var longestRecording: Timer?
    @ObservationIgnored private var levelTimer: Timer?

    private var model: SpeechModel { tidy ? .tidy : .exact }

    init() {
        defaults.register(defaults: ["tidy": true, "british": true, "words": WordList.template])
        tidy = defaults.bool(forKey: "tidy")
        british = defaults.bool(forKey: "british")
        recent = RecentList(items: defaults.stringArray(forKey: "recent") ?? [])

        trace("app opened")
        publish()
        Bell.listen(for: Bell.toApp)
        let center = NotificationCenter.default
        center.addObserver(forName: Bell.toApp, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.answerKeyboard() }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            MainActor.assumeIsolated { if began { self?.micTaken("microphone taken by another app") } }
        }
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.micTaken("iOS reset its sound system") }
        }
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.micChanged() }
        }
        loadModel()
    }

    // MARK: The model

    func loadModel() {
        let model = model
        loadNumber += 1
        let number = loadNumber
        preparing = 0
        preparingSince = .now
        modelProblem = nil
        publish()
        Task {
            do {
                try await transcriber.prepare(model) { fraction in
                    Task { @MainActor [weak self] in self?.showProgress(fraction, load: number) }
                }
                guard number == loadNumber else { return }
                modelReady()
                trace("model ready")
            } catch {
                guard number == loadNumber else { return }
                preparing = nil
                modelProblem = "Couldn't get the speech model. Check the internet, then try again."
                trace("model failed")
            }
            publish()
        }
    }

    private func showProgress(_ fraction: Double, load: Int) {
        guard preparing != nil, load == loadNumber else { return }
        let percent = min(100, max(0, Int(fraction * 100)))
        if percent != preparing {
            preparing = percent
            publish()
        }
    }

    private func modelReady() {
        if let since = preparingSince { trace("model took \(Int(Date.now.timeIntervalSince(since))) seconds") }
        preparing = nil
        preparingSince = nil
        modelProblem = nil
        // 400 MB that can be downloaded again: keep it out of iCloud backups.
        var folder = URL.applicationSupportDirectory.appending(path: "FluidAudio", directoryHint: .isDirectory)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }

    // MARK: Sessions

    /// Turns the microphone on. Only works while the app is on screen, which is
    /// why the keyboard has to open the app to start a session.
    func startSession() async -> Bool {
        if sessionOn && mic.isRunning { return true }
        guard await AVAudioApplication.requestRecordPermission() else {
            micProblem = "Murmur can't use the microphone. Allow it in Settings, then try again."
            trace("microphone not allowed")
            return false
        }
        do {
            try turnMicOn()
        } catch {
            micProblem = "Couldn't turn the microphone on."
            trace("microphone failed to start")
            return false
        }
        micProblem = nil
        if !sessionOn {
            session.start(at: .now)
            startHeartbeat()
            trace("session started")
        } else {
            trace("microphone restarted")
        }
        publish()
        return true
    }

    private func turnMicOn() throws {
        let audio = AVAudioSession.sharedInstance()
        // Music keeps playing, through the speaker or AirPods as before; the iPhone's own microphone listens.
        try audio.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        try audio.setActive(true)
        try mic.start()
    }

    func endSession(_ why: String) {
        guard sessionOn else { return }
        if flow.cancel() == .cancelRecording {
            _ = mic.endCapture()
            longestRecording?.invalidate()
            levelTimer?.invalidate()
        }
        mic.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        session.end()
        endAfterDictation = false
        openedFromKeyboard = false
        heartbeat?.invalidate()
        heartbeat = nil
        trace("session ended: \(why)")
        publish()
    }

    /// The keyboard opened murmur://start.
    func openedByKeyboard() {
        trace("opened by keyboard")
        Task {
            if await startSession() {
                endAfterDictation = false
                openedFromKeyboard = true
            }
        }
    }

    private func startHeartbeat() {
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: KeyboardLink.heartbeatEvery, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.beat() }
        }
    }

    private func beat() {
        if session.shouldEnd(at: .now, phase: flow.phase) {
            endSession("10 minutes unused")
        } else if flow.phase == .idle && !mic.isRunning {
            // The microphone stopped without telling us: start it again, or end
            // the session so the keyboard knows to open the app.
            do { try turnMicOn(); trace("microphone restarted") } catch { endSession("microphone stopped") }
        } else {
            publish(ring: false)
        }
    }

    /// A phone call or Siri took the microphone, or iOS reset its sound system.
    private func micTaken(_ why: String) {
        guard sessionOn else { return }
        if flow.handle(.stop) == .stopAndTranscribe { stopAndWrite() }
        endSession(why)
    }

    /// AirPods in or out: iOS stops the microphone and it has to be started again.
    private func micChanged() {
        guard sessionOn, !mic.isRunning else { return }
        if flow.handle(.stop) == .stopAndTranscribe { stopAndWrite() }
        do {
            try mic.start()
            trace("microphone restarted after a change")
        } catch {
            endSession("microphone changed and couldn't restart")
        }
    }

    // MARK: Dictation

    /// The app's own Talk button. If no keyboard session is on, the microphone
    /// goes off again once the text is written.
    func talk() {
        switch flow.phase {
        case .idle:
            Task {
                let wasOn = sessionOn
                guard await startSession() else { return }
                if !wasOn { endAfterDictation = true }
                if flow.handle(.start) == .startRecording { startRecording(id: 0, casual: false) }
            }
        case .recording:
            if flow.handle(.stop) == .stopAndTranscribe { stopAndWrite() }
        case .transcribing:
            break
        }
    }

    private func answerKeyboard() {
        let request = store?.request()
        guard KeyboardLink.isNew(request, lastAnswered: lastRequest), let request else { return }
        lastRequest = request.id
        trace("keyboard asked to \(request.kind.rawValue)")
        guard sessionOn else { return }
        if request.kind == .turnOff {
            endSession("turned off from the keyboard")
            return
        }
        // A keyboard dictation keeps the session going, even if the app's Talk button started it.
        endAfterDictation = false
        switch flow.handle(request.kind) {
        case .startRecording: startRecording(id: request.id, casual: request.casual ?? false)
        case .stopAndTranscribe: stopAndWrite()
        case .cancelRecording:
            _ = mic.endCapture()
            longestRecording?.invalidate()
            levelTimer?.invalidate()
            trace("recording thrown away")
            publish()
        case .nothing: publish()
        }
    }

    private func startRecording(id: Int, casual: Bool) {
        mic.beginCapture()
        recording = id
        self.casual = casual
        result = nil
        note = nil
        session.used(at: .now)
        longestRecording?.invalidate()
        longestRecording = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.flow.handle(.stop) == .stopAndTranscribe else { return }
                self.trace("15 minute limit")
                self.stopAndWrite()
            }
        }
        // The keyboard's moving bars, ten times a second.
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.publish() }
        }
        trace("listening")
        publish()
    }

    /// Call after `flow` has moved to transcribing.
    private func stopAndWrite() {
        longestRecording?.invalidate()
        levelTimer?.invalidate()
        let samples = mic.endCapture()
        let sampleRate = mic.sampleRate
        let id = recording
        let model = model
        let words = self.words.rows.compactMap(\.entry)
        let snippets = self.words.snippets
        let british = british
        let casual = casual
        trace("writing \(samples.count / max(1, Int(sampleRate))) seconds")
        publish()
        // If the session ends now (a phone call), iOS would pause the app
        // mid-write; this asks for time to finish.
        let background = UIApplication.shared.beginBackgroundTask(withName: "Writing a dictation")
        Task {
            do {
                let raw = try await transcriber.transcribe(samples, sampleRate: sampleRate, model: model)
                if preparing != nil || modelProblem != nil { modelReady() }
                let dictation = Tidy.dictation(raw, words: words, snippets: snippets, british: british, casual: casual)
                finish(PhoneResult(id: id, text: dictation.text, pressEnter: dictation.pressEnter))
            } catch {
                finish(PhoneResult(id: id, text: "", problem: "Couldn't turn that into text."))
            }
            UIApplication.shared.endBackgroundTask(background)
        }
    }

    private func finish(_ finished: PhoneResult) {
        flow.finished()
        session.used(at: .now)
        result = finished
        if !finished.text.isEmpty {
            recent.add(finished.text)
            defaults.set(recent.items, forKey: "recent")
        }
        if finished.id == 0 {
            if finished.text.isEmpty && finished.pressEnter == true {
                lastText = nil
                note = nil
            } else if finished.text.isEmpty {
                lastText = nil
                note = finished.problem ?? "Didn't catch that."
            } else {
                lastText = finished.text
                note = "Copied"
                UIPasteboard.general.string = finished.text
            }
        }
        trace(finished.problem == nil ? "wrote \(finished.text.count) characters" : "couldn't write")
        publish()
        if endAfterDictation { endSession("the app's dictation is done") }
    }

    func copy(_ text: String) {
        UIPasteboard.general.string = text
        note = "Copied"
    }

    // MARK: Telling the keyboard

    private func publish(ring: Bool = true) {
        guard let store else { return }
        var status = PhoneStatus()
        status.session = sessionOn
        status.phase = flow.phase
        status.recording = recording
        status.preparing = preparing
        status.heartbeat = .now
        status.result = result
        status.level = flow.phase == .recording ? mic.level : nil
        store.save(status)
        if ring { Bell.ring(Bell.toKeyboard) }
    }

    private func trace(_ event: String) {
        log.info("\(event, privacy: .public)")
        store?.trace(event, from: "app")
    }
}

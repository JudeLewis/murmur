import Contacts
import AppKit
import CoreAudio
import MurmurCore
import MurmurSpeech
import MurmurUI
import ServiceManagement
import SwiftUI

/// Runs Murmur: the menu bar icon, the Fn double tap and hold, and each
/// dictation from microphone to pasted text.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Loading: Equatable {
        case loading(Double)
        case ready
        case failed
    }

    /// A recording stops by itself after this long, so a forgotten one can't run all day.
    private static let longestRecording: Duration = .seconds(15 * 60)

    private var statusItem: NSStatusItem!
    private let keys = FnKeyMonitor()
    private let transcriber = Transcriber()
    private let pill = Pill()
    private var flow = DictationFlow()
    private var loading: Loading = .loading(0) { didSet { updateIcon() } }
    private var recorder: Recorder?
    private var levelTimer: Timer?
    private var limitTask: Task<Void, Never>?
    private var accessibilityTimer: Timer?
    /// The last recording, kept if it couldn't be turned into text, so it can be tried again.
    private var unsent: (samples: [Float], sampleRate: Double)?
    /// The app in front when listening started: it decides the writing style.
    private var dictatingInto: String?
    /// The volume before Murmur turned it down, what the device then reported,
    /// and which device it was (the output can change mid-dictation).
    private var ducked: (original: Float, lowered: Float, device: AudioDeviceID)?
    private var quitSignal: DispatchSourceSignal?
    private var wordsWindow: NSWindow?
    /// This dictation is a Command Mode instruction, not text to paste.
    private var commandMode = false
    /// Type as I speak (SPEC.md 2.9), while it's typing this dictation.
    private var liveTyper: LiveTyper?
    /// This dictation is going into an email (SPEC.md 4.9).
    private var dictatingEmail = false
    /// The text just before the cursor when listening started (SPEC.md 4.12), read in the
    /// background; nil when the app doesn't say. Never logged or saved.
    private var textBeforeCursor: String?
    private var lastPasteAgain = Date.distantPast
    /// The last dictation as it went in (SPEC.md 2.11, 2.7), and the box it went into, to read
    /// back once for corrections (4.2).
    private var lastDictation: LastDictation?
    private var lastField: Field?
    private var correctionCheck: Task<Void, Never>?
    /// Word list fixes spotted in your corrections, offered at the top of the menu (SPEC.md 4.2).
    private var offeredFixes: [WordEntry] = []
    /// The AI tidy-up was skipped last time, so the pill doesn't say it again and again (SPEC.md 4.11).
    private var aiSkippedLastTime = false
    private var learningNames = false
    private var undoing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        keys.onDoubleTap = { [weak self] in self?.toggle() }
        keys.onEscape = { [weak self] in self?.cancel() }
        keys.onHoldStarted = { [weak self] in self?.holdStarted() }
        keys.onHoldEnded = { [weak self] in self?.holdEnded() }
        keys.onHoldCancelled = { [weak self] in self?.holdCancelled() }
        keys.onSingleTap = { [weak self] in self?.singleTap() }
        keys.onCommandHoldStarted = { [weak self] in self?.commandHoldStarted() }
        keys.onPasteAgain = { [weak self] in self?.pasteAgain() }
        keys.onUndo = { [weak self] in self?.undoLast() }
        keys.onCursorMayMove = { [weak self] in self?.liveTyper?.cursorMayHaveMoved() }
        keys.holdToTalk = Settings.holdToTalk
        keys.commandMode = Settings.commandMode

        turnOnOpenAtLoginOnce()
        putVolumeBackAfterCrash()
        // install.sh replaces Murmur with a quit signal: quit properly, so the volume goes back.
        signal(SIGTERM, SIG_IGN)
        quitSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        quitSignal?.setEventHandler { NSApp.terminate(nil) }
        quitSignal?.resume()
        loadModel()
        Task { await askForPermissions() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        turnMusicBackUp()
    }

    // MARK: Permissions

    private func askForPermissions() async {
        await Permissions.askForMicrophone()
        log.notice("Started. Microphone: \(Permissions.microphoneAllowed), Accessibility: \(AXIsProcessTrusted()), Fn does nothing: \(Permissions.fnKeyDoesNothing)")
        if keys.start() { return }

        if AXIsProcessTrusted() {
            // Allowed, yet the keyboard can't be watched: some macOS versions
            // want Input Monitoring for that as well.
            _ = CGRequestListenEventAccess()
        } else {
            Permissions.askForAccessibility()
        }
        // macOS doesn't say when Accessibility is switched on, so keep checking.
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.retryKeyMonitor() }
        }
    }

    private func retryKeyMonitor() {
        guard keys.start() else { return }
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
        pill.flash("Murmur is ready. Double-tap Fn to talk.", seconds: 4)
    }

    // MARK: Dictation

    private func toggle() {
        perform(flow.toggle())
    }

    private func perform(_ action: DictationAction) {
        log.notice("Action: \(String(describing: action), privacy: .public)")
        switch action {
        case .startRecording: startRecording()
        case .stopAndTranscribe: stopAndTranscribe()
        case .cancelRecording: cancelled()
        case .nothing: break
        }
        updateIcon()
    }

    /// Fn held on its own: listen until it's let go (rules in DictationFlow).
    private func holdStarted() { perform(flow.holdStarted()) }
    private func holdEnded() { perform(flow.holdEnded()) }
    private func holdCancelled() { perform(flow.holdCancelled()) }

    /// Fn and Control held: listen for an instruction (SPEC.md 2.7).
    private func commandHoldStarted() {
        guard flow.phase == .idle else { return }
        guard OnDeviceAI.isAvailable else {
            pill.flash(OnDeviceAI.message(for: OnDeviceAI.Problem.unavailable), seconds: 5)
            return
        }
        commandMode = true
        perform(flow.holdStarted())
        if flow.phase != .recording { commandMode = false }
    }

    private func cancel() { perform(flow.cancel()) }

    /// A single tap of Fn while listening: pause, or carry on (SPEC.md 2.10).
    private func singleTap() {
        guard let recorder, flow.singleTap() else { return }
        recorder.paused = flow.paused
        log.notice("\(self.flow.paused ? "Paused" : "Carrying on", privacy: .public)")
        pill.show(flow.paused ? .message("Paused. Tap Fn to carry on.") : .listening)
        updateIcon()
    }

    private func cancelled() {
        commandMode = false
        stopWatching()
        turnMusicBackUp()
        _ = recorder?.stop()
        recorder = nil
        if let live = liveTyper, !live.typed.isEmpty {
            live.stop()
            liveTyper = nil
            pill.flash("Stopped. What's typed stays.", seconds: 2)
            return
        }
        liveTyper?.stop()
        liveTyper = nil
        pill.flash("Cancelled", seconds: 1.2)
    }

    private func startRecording() {
        guard Permissions.microphoneAllowed else {
            log.notice("Can't record: microphone not allowed")
            commandMode = false
            flow.finished()
            pill.flash("Murmur needs the microphone. Click the Murmur icon in the menu bar.", seconds: 5)
            return
        }
        // Only look at the microphones when there's a choice to make.
        let lidClosed = Microphones.lidClosed
        let mic = Settings.microphoneUID == nil && !lidClosed ? nil : MicChoice.pick(
            from: Microphones.all(), chosen: Settings.microphoneUID, lidClosed: lidClosed,
            defaultIsBuiltIn: Microphones.defaultIsBuiltIn)
        do {
            if let mic {
                // A chosen mic that won't start falls back to the Mac's default.
                if let chosen = try? Recorder(device: mic.id) {
                    log.notice("Using microphone: \(mic.name, privacy: .public)")
                    recorder = chosen
                } else {
                    log.notice("Couldn't use \(mic.name, privacy: .public); using the default microphone")
                    recorder = try Recorder()
                }
            } else {
                recorder = try Recorder()
            }
        } catch {
            log.error("Microphone failed to start: \(error.localizedDescription)")
            commandMode = false
            flow.finished()
            pill.flash("Couldn't start the microphone.", seconds: 4)
            return
        }
        let front = NSWorkspace.shared.frontmostApplication
        dictatingInto = front?.bundleIdentifier
        // Before anything new goes in, look at what happened to the last dictation (SPEC.md 4.2).
        checkForCorrections()
        spotEmail(in: front)
        readTextBeforeCursor()
        playSound("Tink")
        pill.show(.listening)
        if Settings.aiTidy, !commandMode { OnDeviceAI.warmUpTidy(british: Settings.british) }
        // After the Tink, so it isn't turned down too.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, self.flow.phase == .recording else { return }
            self.turnMusicDown()
        }

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let recorder = self.recorder, !self.flow.paused else { return }
                self.pill.push(level: recorder.level)
            }
        }
        limitTask = Task { [weak self] in
            try? await Task.sleep(for: Self.longestRecording)
            guard !Task.isCancelled else { return }
            self?.toggle()
        }
        startTypingLive()
    }

    /// Emails (SPEC.md 4.9): a mail app is known straight away; for a browser the
    /// window title says whether it's Gmail or Outlook, read in the background.
    private func spotEmail(in app: NSRunningApplication?) {
        let bundleID = app?.bundleIdentifier
        dictatingEmail = Settings.layOutEmails && !commandMode && EmailLayout.isEmail(app: bundleID, windowTitle: nil)
        guard Settings.layOutEmails, !commandMode, let app, let bundleID, EmailLayout.browsers.contains(bundleID) else { return }
        let pid = app.processIdentifier
        Task { [weak self] in
            let title = await Task.detached { Selection.windowTitle(of: pid) }.value
            guard let self, self.flow.phase == .recording, self.dictatingInto == bundleID else { return }
            self.dictatingEmail = EmailLayout.isEmail(app: bundleID, windowTitle: title)
            if self.dictatingEmail { log.notice("Writing an email") }
        }
    }

    /// The text before the cursor (SPEC.md 4.12), read off the main thread, as a busy app
    /// can be slow to answer. Not for Command Mode, which works on the selection instead.
    private func readTextBeforeCursor() {
        textBeforeCursor = nil
        guard !commandMode, AXIsProcessTrusted() else { return }
        let app = dictatingInto
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        Task { [weak self] in
            let before = await Task.detached { Selection.textBeforeCursor(in: pid) }.value
            guard let self, self.flow.phase == .recording, self.dictatingInto == app else { return }
            self.textBeforeCursor = before
            // Never the words: only whether it could be read, and where the cursor is.
            let found = before == nil ? "the app didn't say" : BeforeCursor.isMidSentence(before) ? "mid-sentence" : "not mid-sentence"
            log.notice("Text before the cursor: \(found, privacy: .public)")
        }
    }

    /// Type as I speak (SPEC.md 2.9): not for Command Mode, and only once the
    /// model is ready and Murmur may press keys; otherwise it's pasted at the end.
    private func startTypingLive() {
        guard Settings.typeAsISpeak, !commandMode, loading == .ready, AXIsProcessTrusted(), let recorder else { return }
        let style = Settings.appStyles.style(for: dictatingInto)
        let quiet = Settings.ignoreQuieterVoices
        let words = Settings.words()
        let snippets = Settings.snippets
        let british = Settings.british
        let model = Settings.model
        // The text before the cursor as it was at the first words typed, and never changed after:
        // if it came later, the start would be retyped, and it could include Murmur's own typing.
        var before: String??
        // Whether it's an email may only be known a moment after listening starts.
        liveTyper = LiveTyper(recorder: recorder, transcriber: transcriber, model: model, whisper: Settings.whisperMode, app: dictatingInto) {
            [weak self] heard in
            let kept = quiet ? QuietVoices.keep(heard) : heard
            if before == nil { before = .some(self?.textBeforeCursor) }
            let before = before ?? nil
            let dictation = Tidy.dictation(
                model.withoutFillers(kept.map(\.text).joined(separator: " ")), words: words, snippets: snippets, british: british,
                email: self?.dictatingEmail ?? false, style: style, before: before)
            // A space in front in the middle of a sentence, typed with the words (SPEC.md 4.12).
            return Dictation(text: Tidy.spaceInFront(of: dictation.text, after: before) + dictation.text, pressEnter: dictation.pressEnter)
        }
        liveTyper?.start()
    }

    private func stopAndTranscribe() {
        stopWatching()
        // The kind of dictation goes with the recording from here on, not in a loose flag.
        let isCommand = commandMode
        commandMode = false
        guard let recorder else {
            flow.finished()
            return
        }
        self.recorder = nil
        if let live = liveTyper {
            liveTyper = nil
            let seconds = recorder.stopListening()
            if Settings.keepRecordings {
                let samples = recorder.heard().samples, rate = recorder.sampleRate, model = Settings.model, folder = Settings.recordingsFolder
                Task.detached { Self.keep(samples, sampleRate: rate, model: model, heard: "(typed as you spoke)", in: folder) }
            }
            log.notice("Recorded \(seconds, format: .fixed(precision: 1)) s, typing as you spoke")
            turnMusicBackUp()
            playSound("Pop")
            pill.show(.working("Writing"))
            Task { await finishTypingLive(live) }
            return
        }
        let samples = recorder.stop()
        log.notice("Recorded \(Double(samples.count) / recorder.sampleRate, format: .fixed(precision: 1)) s at \(Int(recorder.sampleRate)) Hz")
        turnMusicBackUp()
        playSound("Pop")
        transcribe(samples, sampleRate: recorder.sampleRate, command: isCommand)
    }

    private func finishTypingLive(_ live: LiveTyper) async {
        let dictation = await live.finish()
        flow.finished()
        updateIcon()
        let text = dictation.text.trimmingCharacters(in: .whitespaces)
        log.notice("Typed \(text.count) characters as you spoke\(dictation.pressEnter ? ", then Return" : "", privacy: .public)")
        if !text.isEmpty {
            var recent = Settings.recent
            recent.add(text)
            Settings.recent = recent
        }
        if live.gaveUp {
            // Part of it is typed already, so pasting it all would double that part.
            Paster.copy(Tidy.forInsertion(dictation.text, pressEnter: dictation.pressEnter))
            pill.flash("Typing stopped part way. The whole dictation is copied.", seconds: 5)
        } else if live.lostTheEnd {
            pill.flash("Couldn't write the last few words.", seconds: 4)
        } else if text.isEmpty && !dictation.pressEnter {
            pill.flash("Didn't catch that.", seconds: 1.5)
        } else {
            if dictation.pressEnter { Paster.pressReturn() }
            remember(live.typed)
            pill.hide()
        }
    }

    // MARK: The last dictation (SPEC.md 2.11, 2.7, 4.2)

    /// Keeps what just went in, and the box it went into, to undo it, rewrite it, or spot
    /// corrections to it later (once, at the next dictation or after 30 seconds).
    private func remember(_ inserted: String) {
        guard !inserted.isEmpty else { return }
        lastDictation = LastDictation(text: inserted, app: dictatingInto)
        lastField = nil
        correctionCheck?.cancel()
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        correctionCheck = Task { [weak self] in
            let field = await Task.detached { Selection.focusedField(in: pid) }.value
            guard let self, !Task.isCancelled else { return }
            self.lastField = field
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self.checkForCorrections()
        }
    }

    /// Reads the box the last dictation went into, once, and offers any word you corrected.
    private func checkForCorrections() {
        correctionCheck?.cancel()
        correctionCheck = nil
        guard let last = lastDictation, let field = lastField else { return }
        lastField = nil
        Task { [weak self] in
            // Off the main thread: searching a long box can take a moment.
            let found = await Task.detached { field.text().map(last.corrections(in:)) ?? [] }.value
                .filter { !Settings.words().contains($0) }
            guard let self else { return }
            guard !found.isEmpty else { return }
            // Never the words in the log.
            log.notice("Spotted \(found.count) possible word list fixes")
            self.offeredFixes = found
            if self.flow.phase == .idle, let first = found.first {
                self.pill.flash("Spotted a fix: \(first.heard) \u{2192} \(first.written). Add it from the menu.", seconds: 4)
            }
        }
    }

    @objc private func addOfferedFix(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, offeredFixes.indices.contains(index) else { return }
        var words = Settings.words()
        let entry = offeredFixes.remove(at: index)
        if !words.contains(entry) { words.append(entry) }
        Settings.saveWords(words)
        pill.flash("Added to the word list.", seconds: 1.5)
    }

    @objc private func dismissOfferedFixes() { offeredFixes = [] }

    /// Control-Command-Z or the menu: takes the last dictation out, if the cursor is still
    /// straight after it (SPEC.md 2.11).
    private func undoLast() {
        guard flow.phase == .idle, !undoing else { return }
        guard let last = lastDictation else {
            pill.flash("Nothing to undo.", seconds: 1.5)
            return
        }
        // Only one undo at a time, and only once per dictation.
        undoing = true
        lastDictation = nil
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        Task {
            await Paster.waitForKeysUp()
            let before = await Task.detached { Selection.textBeforeCursor(in: pid, limit: last.text.utf16.count + 20) }.value
            defer { undoing = false }
            guard last.app == app, let count = last.charactersToRemove(before: before) else {
                lastDictation = last
                log.notice("Undo: the cursor isn't after the last dictation")
                pill.flash("Can't undo here: the cursor has moved.", seconds: 2.5)
                return
            }
            Paster.deleteBackward(count)
            lastField = nil
            correctionCheck?.cancel()
            log.notice("Undid the last dictation")
        }
    }

    @objc private func undoFromMenu() { undoLast() }

    // MARK: Names from Contacts (SPEC.md 4.2)

    /// Says each contact's name with the Mac's voice, listens with the speech model, and adds a
    /// fix for each name it writes differently. All on the Mac.
    @objc private func learnNamesFromContacts() {
        guard !learningNames else { return }
        guard loading == .ready else {
            pill.flash("The speech model is still getting ready. Try again in a minute.", seconds: 3)
            return
        }
        learningNames = true
        Task {
            defer { learningNames = false }
            let store = CNContactStore()
            guard (try? await store.requestAccess(for: .contacts)) == true else {
                pill.flash("Murmur isn't allowed to see Contacts. Allow it in System Settings, Privacy & Security, Contacts.", seconds: 5)
                return
            }
            let contacts = await Task.detached { () -> [(given: String, family: String)] in
                var found: [(given: String, family: String)] = []
                let request = CNContactFetchRequest(keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor])
                try? CNContactStore().enumerateContacts(with: request) { contact, _ in found.append((contact.givenName, contact.familyName)) }
                return found
            }.value
            let words = Settings.words()
            let names = NameLearning.names(from: contacts, known: words)
            let allNames = Set(names.map { $0.lowercased() })
            let model = Settings.model
            log.notice("Learning \(names.count) names from Contacts")
            var added = 0
            var learned: [WordEntry] = []
            for (index, name) in names.enumerated() {
                // A dictation goes first: wait until Murmur is free again.
                while flow.phase != .idle { try? await Task.sleep(for: .milliseconds(500)) }
                if index % 10 == 0 { pill.flash("Learning names from Contacts: \(index) of \(names.count)", seconds: 10) }
                guard let samples = await Task.detached(operation: { Self.spoken(name) }).value,
                      let heard = try? await transcriber.transcribe(samples, sampleRate: 16_000, model: model) else { continue }
                let spellChecker = NSSpellChecker.shared
                let isWord: (String) -> Bool = { spellChecker.checkSpelling(of: $0, startingAt: 0).location == NSNotFound }
                if let entry = NameLearning.entry(name: name, heard: heard, isWord: isWord, names: allNames), !words.contains(entry) {
                    learned.append(entry)
                    added += 1
                }
            }
            // Read the list again, so anything added meanwhile is kept.
            if added > 0 {
                var latest = Settings.words()
                latest.append(contentsOf: learned.filter { !latest.contains($0) })
                Settings.saveWords(latest)
            }
            log.notice("Added \(added) names from Contacts")
            pill.flash(added == 0 ? "Checked \(names.count) names: the speech model already gets them right."
                       : "Added \(added) names from Contacts. They're in the word list.", seconds: 4)
        }
    }

    /// `name` said by the Mac's British voice, as 16 kHz samples.
    nonisolated private static func spoken(_ name: String) -> [Float]? {
        let file = FileManager.default.temporaryDirectory.appending(path: "murmur-name-\(UUID().uuidString).aiff")
        defer { try? FileManager.default.removeItem(at: file) }
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-v", "Daniel", "-o", file.path, name]
        guard (try? say.run()) != nil else { return nil }
        say.waitUntilExit()
        return try? Transcriber.samples(fromFile: file)
    }

    private func transcribe(_ samples: [Float], sampleRate: Double, command: Bool = false) {
        pill.show(.working(loading == .ready ? (command ? "Thinking" : "Writing") : "Getting the speech model ready"))
        let model = Settings.model
        let whisper = Settings.whisperMode
        let quiet = Settings.ignoreQuieterVoices && !command
        Task {
            do {
                // Off the main thread: a long recording is millions of samples.
                let audio = whisper ? await Task.detached { Loudness.boosted(samples, maxGain: Loudness.whisperGain) }.value : samples
                let raw: String
                if quiet {
                    // Other people's voices left out (SPEC.md 4.10).
                    let heard = try await transcriber.heard(audio, sampleRate: sampleRate, model: model)
                    let kept = QuietVoices.keep(heard.words)
                    raw = model.withoutFillers(kept.count == heard.words.count ? heard.text : kept.map(\.text).joined(separator: " "))
                    if kept.count < heard.words.count { log.notice("Left out \(heard.words.count - kept.count) quieter words") }
                } else {
                    raw = model.withoutFillers(try await transcriber.transcribe(audio, sampleRate: sampleRate, model: model))
                }
                unsent = nil
                if Settings.model == model { loading = .ready }
                if Settings.keepRecordings, !command {
                    let heard = raw, folder = Settings.recordingsFolder
                    Task.detached { Self.keep(samples, sampleRate: sampleRate, model: model, heard: heard, in: folder) }
                }
                if command {
                    await runCommand(raw)
                } else {
                    await deliver(raw)
                }
            } catch {
                log.error("Transcription failed: \(error.localizedDescription)")
                flow.finished()
                updateIcon()
                if command {
                    // An instruction is short and its selection may have changed: just say it again.
                    pill.flash("Couldn't hear the instruction. Try again.", seconds: 4)
                    return
                }
                unsent = (samples, sampleRate)
                pill.flash("Couldn't turn that into text. Try again from the Murmur menu.", seconds: 5)
            }
        }
    }

    /// Command Mode: the spoken instruction goes to the on-device AI with the
    /// selected text (or none, to write something new), and the reply replaces it.
    private func runCommand(_ raw: String) async {
        let words = Settings.words()
        let instruction = Tidy.finish(raw, words: words, british: Settings.british)
        guard !instruction.isEmpty else {
            finishCommand(problem: "Didn't catch that.")
            return
        }
        pill.show(.working("Thinking"))
        var selection = await Selection.read()
        // Nothing selected, and "make that more formal": the last dictation, if the cursor is
        // still straight after it (SPEC.md 2.7).
        var replacingLast = 0
        if selection == nil, LastDictation.isAboutIt(instruction), let last = lastDictation,
           last.app == NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let before = await Task.detached { Selection.textBeforeCursor(in: pid, limit: last.text.utf16.count + 20) }.value
            if let count = last.charactersToRemove(before: before) {
                selection = last.words
                replacingLast = count
            }
        }
        log.notice("Command Mode: \(replacingLast > 0 ? "rewriting the last dictation" : selection == nil ? "writing new text" : "rewriting \(selection!.count) characters", privacy: .public)")
        do {
            let text = try await OnDeviceAI.command(
                instruction, selection: selection, words: words, british: Settings.british, addSpace: selection == nil || replacingLast > 0)
            finishCommand(problem: nil)
            var recent = Settings.recent
            recent.add(text)
            Settings.recent = recent
            await Paster.waitForKeysUp()
            if replacingLast > 0, let last = lastDictation {
                // The cursor may have moved while the AI thought: check again before deleting.
                let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
                let before = await Task.detached { Selection.textBeforeCursor(in: pid, limit: last.text.utf16.count + 20) }.value
                guard last.charactersToRemove(before: before) == replacingLast else {
                    Paster.copy(text)
                    pill.flash("The cursor moved, so the new version is copied. Press ⌘V to paste.", seconds: 4)
                    return
                }
                Paster.deleteBackward(replacingLast)
            }
            if Paster.paste(text) {
                // New text can be undone or rewritten again like a dictation.
                if selection == nil || replacingLast > 0 { remember(text) }
                pill.hide()
            } else {
                pill.flash("Copied. Press ⌘V to paste.", seconds: 4)
            }
        } catch {
            log.error("Command Mode failed")
            finishCommand(problem: OnDeviceAI.message(for: error))
        }
    }

    private func finishCommand(problem: String?) {
        flow.finished()
        updateIcon()
        if let problem { pill.flash(problem, seconds: 4) }
    }

    /// Control-Command-V or the menu: the last dictation, pasted again (SPEC.md 2.8).
    private func pasteAgain() {
        guard Date.now.timeIntervalSince(lastPasteAgain) > 1 else { return }
        lastPasteAgain = .now
        guard let text = Settings.recent.items.first else {
            pill.flash("Nothing to paste yet.", seconds: 1.5)
            return
        }
        Task {
            // Wait for Control and Command to be let go, so they don't mix with the paste.
            await Paster.waitForKeysUp()
            if !Paster.paste(Tidy.forInsertion(text)) { pill.flash("Copied. Press ⌘V to paste.", seconds: 4) }
        }
    }

    private func deliver(_ raw: String) async {
        let style = Settings.appStyles.style(for: dictatingInto)
        let words = Settings.words()
        let snippets = Settings.snippets
        // "As said" apps get no AI at all (SPEC.md 4.7).
        let fixOn = Settings.fixCorrections && style.usesAI
        let tidyOn = Settings.aiTidy && style.usesAI
        let british = Settings.british
        let triggers = snippets.map(\.trigger)
        let protected = AITidy.protected(snippets: snippets, words: words, british: british)
        let before = textBeforeCursor
        let skipped = SkipNote()
        let dictation = await Tidy.dictation(
            raw, words: words, snippets: snippets, british: british, email: dictatingEmail, style: style, before: before,
            // "Monday, no wait, I mean Tuesday": the on-device AI may only take words out (SPEC.md 4.8).
            fix: { finished in
                guard fixOn, let fixed = try? await OnDeviceAI.fixSelfCorrection(in: finished, keeping: triggers) else { return nil }
                log.notice("Fixed a self-correction")
                return fixed
            },
            // Punctuation, capitals and small slips; a reply that does more is ignored (SPEC.md 4.11).
            tidy: { text in
                guard tidyOn else { return nil }
                let started = Date.now
                do {
                    let tidied = try await OnDeviceAI.tidy(text, keeping: protected, british: british, before: before)
                    let seconds = String(format: "%.1f", Date.now.timeIntervalSince(started))
                    log.notice("AI tidy-up \(tidied == nil ? "left the text as it was" : "used", privacy: .public) after \(seconds, privacy: .public) s")
                    await skipped.set("")
                    return tidied
                } catch {
                    log.notice("AI tidy-up skipped: \(String(describing: error), privacy: .public)")
                    await skipped.set(AITidy.skipNote(slow: (error as? OnDeviceAI.Problem) == .tooSlow))
                    return nil
                }
            })
        let text = dictation.text
        flow.finished()
        updateIcon()

        log.notice("Wrote \(text.count) characters\(dictation.pressEnter ? ", then Return" : "", privacy: .public)")
        if text.isEmpty && dictation.pressEnter {
            pill.hide()
            Paster.pressReturn(after: .zero)
            return
        }
        guard !text.isEmpty else {
            pill.flash("Didn't catch that.", seconds: 1.5)
            return
        }
        var recent = Settings.recent
        recent.add(text)
        Settings.recent = recent

        let inserted = Tidy.forInsertion(text, after: before, pressEnter: dictation.pressEnter)
        if Paster.paste(inserted) {
            log.notice("Pasted")
            if dictation.pressEnter { Paster.pressReturn() }
            remember(inserted)
            // Once, when the AI tidy-up was skipped, so a plain dictation isn't a mystery (SPEC.md 4.11).
            // "" means it worked; nil means it wasn't asked (too short, or off), which changes nothing.
            let note = await skipped.text
            if let note, !note.isEmpty, !aiSkippedLastTime { pill.flash(note, seconds: 3) } else { pill.hide() }
            if let note { aiSkippedLastTime = !note.isEmpty }
        } else {
            log.notice("Not allowed to paste; left on the clipboard")
            pill.flash("Copied. Press ⌘V to paste.", seconds: 4)
        }
    }

    private func stopWatching() {
        levelTimer?.invalidate()
        levelTimer = nil
        limitTask?.cancel()
        limitTask = nil
    }

    /// SPEC.md 2.6: a quarter of the volume while listening.
    private func turnMusicDown() {
        guard Settings.duckMusic, ducked == nil, let device = SystemVolume.outputDevice(),
              let volume = SystemVolume.volume(of: device), volume > 0.01 else { return }
        SystemVolume.set(Ducking.lowered(from: volume), on: device)
        // What the device actually took: some round to their own steps.
        guard let lowered = SystemVolume.volume(of: device) else { return }
        ducked = (volume, lowered, device)
        Settings.duckedVolume = [Double(volume), Double(lowered), Double(device)]
    }

    /// Puts back the device that was turned down, even if the output has changed since.
    private func turnMusicBackUp() {
        guard let ducked else { return }
        self.ducked = nil
        Settings.duckedVolume = nil
        if let current = SystemVolume.volume(of: ducked.device), Ducking.shouldRestore(current: current, lowered: ducked.lowered) {
            SystemVolume.set(ducked.original, on: ducked.device)
        }
    }

    /// Murmur quit or crashed while the volume was down: put it back now.
    private func putVolumeBackAfterCrash() {
        guard let saved = Settings.duckedVolume, saved.count == 3 else { return }
        ducked = (Float(saved[0]), Float(saved[1]), AudioDeviceID(saved[2]))
        turnMusicBackUp()
    }

    private func playSound(_ name: String) {
        guard Settings.sounds, let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = 0.35
        sound.play()
    }

    // MARK: Speech model

    private func loadModel() {
        loading = .loading(0)
        let model = Settings.model
        Task {
            do {
                try await transcriber.prepare(model) { fraction in
                    Task { @MainActor [weak self] in
                        guard let self, case .loading = self.loading else { return }
                        self.loading = .loading(fraction)
                    }
                }
                log.notice("Speech model ready: \(model.rawValue, privacy: .public)")
                if Settings.model == model { loading = .ready }
            } catch {
                log.error("Speech model failed to load: \(error.localizedDescription)")
                if Settings.model == model { loading = .failed }
            }
        }
    }

    // MARK: Menu bar

    private func updateIcon() {
        let symbol: String
        switch (flow.phase, loading) {
        case (.recording, _) where flow.paused: symbol = "pause.circle"
        case (.recording, _): symbol = "waveform.circle.fill"
        case (.transcribing, _): symbol = "ellipsis.circle"
        case (.idle, .loading): symbol = "arrow.down.circle"
        case (.idle, .failed): symbol = "exclamationmark.triangle"
        case (.idle, .ready): symbol = "waveform"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Murmur")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }

    private var statusLine: String {
        switch (flow.phase, loading) {
        case (.recording, _) where flow.heldOpen: "Listening. Let go of Fn to finish, Esc to cancel."
        case (.recording, _) where flow.paused: "Paused. Tap Fn to carry on, double-tap to finish."
        case (.recording, _): "Listening. Double-tap Fn to finish, Esc to cancel."
        case (.transcribing, _): "Writing…"
        case (.idle, .loading(let fraction)) where fraction > 0 && fraction < 1:
            "Getting the speech model ready: \(Int(fraction * 100))%"
        case (.idle, .loading): "Getting the speech model ready…"
        case (.idle, .failed): "Couldn't load the speech model. Check the internet."
        case (.idle, .ready): Settings.holdToTalk ? "Ready. Double-tap or hold Fn to talk." : "Ready. Double-tap Fn to talk."
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        // Items keep the enabled state set here (Paste again is greyed out with nothing to paste).
        menu.autoenablesItems = false

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if loading == .failed {
            menu.addItem(item("Try loading the speech model again", #selector(retryLoad)))
        }
        for (index, fix) in offeredFixes.enumerated() {
            let offer = item("Add to word list: \(fix.heard) \u{2192} \(fix.written)", #selector(addOfferedFix(_:)))
            offer.representedObject = index
            menu.addItem(offer)
        }
        if !offeredFixes.isEmpty { menu.addItem(item("Not now", #selector(dismissOfferedFixes))) }
        menu.addItem(item(flow.phase == .recording ? "Stop dictation" : "Start dictation", #selector(toggleFromMenu)))
        if unsent != nil {
            menu.addItem(item("Try the last recording again", #selector(retryUnsent)))
        }
        menu.addItem(.separator())

        var needsSetUp = false
        if !Permissions.microphoneAllowed {
            menu.addItem(item("⚠️ Allow the microphone…", #selector(openMicrophoneSettings)))
            needsSetUp = true
        }
        if !keys.isRunning {
            menu.addItem(item("⚠️ Allow Accessibility (for Fn and pasting)…", #selector(openAccessibilitySettings)))
            needsSetUp = true
        }
        if !Permissions.fnKeyDoesNothing {
            menu.addItem(item("⚠️ Set “Press 🌐 key to” to Do Nothing…", #selector(openKeyboardSettings)))
            needsSetUp = true
        }
        if needsSetUp { menu.addItem(.separator()) }

        let recentMenu = NSMenu()
        let recent = Settings.recent.items.prefix(10)
        if recent.isEmpty {
            let empty = NSMenuItem(title: "Nothing yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recentMenu.addItem(empty)
        }
        for text in recent {
            let entry = item(text.count > 60 ? String(text.prefix(60)) + "…" : text, #selector(copyRecent(_:)))
            entry.representedObject = text
            recentMenu.addItem(entry)
        }
        let recentItem = NSMenuItem(title: "Recent (click one to copy it)", action: nil, keyEquivalent: "")
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)
        let again = item("Paste last dictation again", #selector(pasteAgainFromMenu), key: "v")
        again.keyEquivalentModifierMask = [.control, .command]
        again.isEnabled = !Settings.recent.items.isEmpty
        menu.addItem(again)
        let undo = item("Undo last dictation", #selector(undoFromMenu), key: "z")
        undo.keyEquivalentModifierMask = [.control, .command]
        undo.isEnabled = lastDictation != nil
        menu.addItem(undo)
        menu.addItem(item("Word list and snippets…", #selector(openWords)))
        menu.addItem(item(learningNames ? "Learning names from Contacts…" : "Learn names from Contacts…", #selector(learnNamesFromContacts)))
        menu.addItem(.separator())

        if let front = NSWorkspace.shared.frontmostApplication, let id = front.bundleIdentifier,
           id != Bundle.main.bundleIdentifier {
            // Style in Messages ▸ Normal, Casual, Very casual, As said (SPEC.md 4.7).
            let chosen = Settings.appStyles.style(for: id)
            let styles = NSMenu()
            for style in WritingStyle.allCases {
                let entry = item(style.title, #selector(chooseStyle(_:)), on: style == chosen)
                entry.representedObject = [id, style.rawValue]
                styles.addItem(entry)
            }
            let styleItem = NSMenuItem(title: "Style in \(front.localizedName ?? "this app"): \(chosen.shortName)", action: nil, keyEquivalent: "")
            styleItem.submenu = styles
            menu.addItem(styleItem)
        }
        menu.addItem(microphoneMenu())
        menu.addItem(settingsMenu())
        menu.addItem(.separator())
        menu.addItem(item("Quit Murmur", #selector(quit), key: "q"))
    }

    /// Automatic, then each microphone the Mac has (SPEC.md 3.3).
    private func microphoneMenu() -> NSMenuItem {
        let submenu = NSMenu()
        let chosen = Settings.microphoneUID
        let mics = Microphones.all()
        let automatic = item("Automatic", #selector(chooseMicrophone(_:)), on: chosen == nil || !mics.contains { $0.uid == chosen })
        submenu.addItem(automatic)
        let hint = NSMenuItem(title: "The Mac's own choice; another mic when the lid is shut", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        submenu.addItem(hint)
        submenu.addItem(.separator())
        for mic in mics {
            let entry = item(mic.name, #selector(chooseMicrophone(_:)), on: mic.uid == chosen)
            entry.representedObject = mic.uid
            submenu.addItem(entry)
        }
        let menuItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        menuItem.submenu = submenu
        return menuItem
    }

    /// Which speech model (SPEC.md 3.1).
    private func speechModelMenu() -> NSMenuItem {
        let submenu = NSMenu()
        let choices: [(SpeechModel, String)] = [
            (.tidy, "Tidy (drops um and er)"),
            (.ultra, "Ultra (fewer mistakes, 600 MB download)"),
            (.exact, "Word for word"),
        ]
        for (model, title) in choices {
            let entry = item(title, #selector(chooseSpeechModel(_:)), on: Settings.model == model)
            entry.representedObject = model.rawValue
            submenu.addItem(entry)
        }
        let menuItem = NSMenuItem(title: "Speech model", action: nil, keyEquivalent: "")
        menuItem.submenu = submenu
        return menuItem
    }

    private func settingsMenu() -> NSMenuItem {
        let submenu = NSMenu()
        // Apple's model can be missing for a while, such as after a macOS update (SPEC.md 4.11).
        let waiting = Settings.aiTidy && !OnDeviceAI.isAvailable
        submenu.addItem(item(waiting ? "AI tidy-up (waiting for Apple Intelligence)" : "AI tidy-up (Apple Intelligence)",
                             #selector(toggleAITidy), on: Settings.aiTidy))
        submenu.addItem(item("Type as I speak (turns AI tidy-up off)", #selector(toggleTypeAsISpeak), on: Settings.typeAsISpeak))
        submenu.addItem(item("Lay out emails", #selector(toggleLayOutEmails), on: Settings.layOutEmails))
        submenu.addItem(item("Ignore quieter voices (people nearby)", #selector(toggleIgnoreQuieterVoices), on: Settings.ignoreQuieterVoices))
        submenu.addItem(speechModelMenu())
        submenu.addItem(item("British spelling", #selector(toggleBritish), on: Settings.british))
        submenu.addItem(item("Fix \u{201C}no wait, I mean\u{201D} (Apple Intelligence)", #selector(toggleFixCorrections), on: Settings.fixCorrections))
        submenu.addItem(item("Whisper mode (for speaking quietly)", #selector(toggleWhisperMode), on: Settings.whisperMode))
        submenu.addItem(item("Keep recordings for testing (7 days)", #selector(toggleKeepRecordings), on: Settings.keepRecordings))
        submenu.addItem(.separator())
        submenu.addItem(item("Hold Fn to talk", #selector(toggleHoldToTalk), on: Settings.holdToTalk))
        submenu.addItem(item("Command Mode: hold Fn and Control", #selector(toggleCommandMode), on: Settings.commandMode))
        submenu.addItem(item("Turn music down while listening", #selector(toggleDuckMusic), on: Settings.duckMusic))
        submenu.addItem(item("Sounds", #selector(toggleSounds), on: Settings.sounds))
        submenu.addItem(item("Open at login", #selector(toggleOpenAtLogin), on: SMAppService.mainApp.status == .enabled))
        let menuItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        menuItem.submenu = submenu
        return menuItem
    }

    private func item(_ title: String, _ action: Selector, on: Bool? = nil, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let on { item.state = on ? .on : .off }
        return item
    }

    @objc private func toggleFromMenu() { toggle() }

    @objc private func retryLoad() { loadModel() }

    @objc private func retryUnsent() {
        guard let unsent, flow.retry() else { return }
        updateIcon()
        transcribe(unsent.samples, sampleRate: unsent.sampleRate)
    }

    @objc private func openMicrophoneSettings() {
        Task {
            await Permissions.askForMicrophone()
            if !Permissions.microphoneAllowed { Permissions.openMicrophoneSettings() }
        }
    }

    @objc private func openAccessibilitySettings() { Permissions.openAccessibilitySettings() }

    @objc private func openKeyboardSettings() { Permissions.openKeyboardSettings() }

    @objc private func copyRecent(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        Paster.copy(text)
        pill.flash("Copied", seconds: 1.2)
    }

    /// The word list and snippets window (SPEC.md 4.2 and 4.5), read fresh each time it opens.
    @objc private func openWords() {
        let model = WordsModel(
            words: Settings.words(), snippets: Settings.snippets, recent: { Settings.recent.items },
            saveWords: { Settings.saveWords($0) }, saveSnippets: { Settings.snippets = $0 })
        let content = NSHostingController(rootView: WordsView(model: model).frame(minWidth: 460, minHeight: 520))
        if let window = wordsWindow {
            window.contentViewController = content
        } else {
            let window = NSWindow(contentViewController: content)
            window.title = "Murmur: word list and snippets"
            window.isReleasedWhenClosed = false
            window.center()
            wordsWindow = window
        }
        NSApp.activate()
        wordsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2,
              let style = WritingStyle(rawValue: pair[1]) else { return }
        var styles = Settings.appStyles
        styles.set(style, for: pair[0])
        Settings.appStyles = styles
    }

    @objc private func toggleHoldToTalk() {
        Settings.holdToTalk.toggle()
        keys.holdToTalk = Settings.holdToTalk
    }

    @objc private func toggleDuckMusic() { Settings.duckMusic.toggle() }

    @objc private func toggleFixCorrections() { Settings.fixCorrections.toggle() }

    @objc private func toggleWhisperMode() { Settings.whisperMode.toggle() }

    @objc private func toggleKeepRecordings() {
        Settings.keepRecordings.toggle()
        // Turning it off deletes what was kept.
        if !Settings.keepRecordings { try? FileManager.default.removeItem(at: Settings.recordingsFolder) }
    }

    /// Saves a recording for testing, if that's on (SPEC.md 3.5), and deletes old ones. Off the
    /// main thread. Not Command Mode instructions.
    nonisolated private static func keep(_ samples: [Float], sampleRate: Double, model: SpeechModel, heard: String, in folder: URL) {
        let files = FileManager.default
        try? files.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = KeptRecordings.name(for: .now)
        try? KeptRecordings.wav(samples, sampleRate: Int(sampleRate)).write(to: folder.appending(path: name + ".wav"))
        let info = ["model": model.rawValue, "heard": heard]
        try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted]).write(to: folder.appending(path: name + ".json"))
        let kept = ((try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .filter { $0.pathExtension == "wav" }
            .map { (name: $0.deletingPathExtension().lastPathComponent,
                    date: (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
        for old in KeptRecordings.toDelete(kept) {
            try? files.removeItem(at: folder.appending(path: old + ".wav"))
            try? files.removeItem(at: folder.appending(path: old + ".json"))
        }
    }
    @objc private func toggleTypeAsISpeak() { Settings.typeAsISpeak.toggle() }
    @objc private func toggleAITidy() { Settings.aiTidy.toggle() }
    @objc private func toggleLayOutEmails() { Settings.layOutEmails.toggle() }
    @objc private func toggleIgnoreQuieterVoices() { Settings.ignoreQuieterVoices.toggle() }

    @objc private func toggleCommandMode() {
        Settings.commandMode.toggle()
        keys.commandMode = Settings.commandMode
    }

    @objc private func chooseMicrophone(_ sender: NSMenuItem) {
        Settings.microphoneUID = sender.representedObject as? String
    }

    @objc private func pasteAgainFromMenu() { pasteAgain() }

    @objc private func chooseSpeechModel(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let model = SpeechModel(rawValue: raw), model != Settings.model else { return }
        // A new download mustn't leave the Mac short of space: below 10 GB macOS removes
        // Apple Intelligence's model (seen 17 Nov 2026).
        if !model.isDownloaded, let free = Self.freeSpace(), free < 11_000_000_000 {
            pill.flash("Not enough free space to download it. Free up a few GB first.", seconds: 5)
            return
        }
        Settings.model = model
        loadModel()
    }

    private static func freeSpace() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }

    @objc private func toggleBritish() { Settings.british.toggle() }

    @objc private func toggleSounds() { Settings.sounds.toggle() }

    @objc private func toggleOpenAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            pill.flash("Couldn't change Open at Login.", seconds: 3)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    /// The first time Murmur runs from Applications it adds itself to Open at Login.
    /// After that the menu's tick is the user's choice.
    private func turnOnOpenAtLoginOnce() {
        guard !Settings.setUpLoginItem, Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        Settings.setUpLoginItem = true
        try? SMAppService.mainApp.register()
    }
}

/// Why the AI tidy-up was skipped for this dictation, if it was (SPEC.md 4.11).
actor SkipNote {
    var text: String?
    func set(_ value: String?) { text = value }
}

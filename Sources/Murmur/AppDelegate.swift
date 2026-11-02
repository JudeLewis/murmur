import AppKit
import MurmurCore
import ServiceManagement

/// Runs Murmur: the menu bar icon, the Fn double tap, and each dictation from
/// microphone to pasted text.
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        keys.onDoubleTap = { [weak self] in self?.toggle() }
        keys.onEscape = { [weak self] in self?.cancel() }

        turnOnOpenAtLoginOnce()
        loadModel()
        Task { await askForPermissions() }
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
        let action = flow.toggle()
        log.notice("Toggle: \(String(describing: action), privacy: .public)")
        switch action {
        case .startRecording: startRecording()
        case .stopAndTranscribe: stopAndTranscribe()
        case .cancelRecording, .nothing: break
        }
        updateIcon()
    }

    private func cancel() {
        guard flow.cancel() == .cancelRecording else { return }
        stopWatching()
        _ = recorder?.stop()
        recorder = nil
        pill.flash("Cancelled", seconds: 1.2)
        updateIcon()
    }

    private func startRecording() {
        guard Permissions.microphoneAllowed else {
            log.notice("Can't record: microphone not allowed")
            flow.finished()
            pill.flash("Murmur needs the microphone. Click the Murmur icon in the menu bar.", seconds: 5)
            return
        }
        do {
            recorder = try Recorder()
        } catch {
            log.error("Microphone failed to start: \(error.localizedDescription)")
            flow.finished()
            pill.flash("Couldn't start the microphone.", seconds: 4)
            return
        }
        playSound("Tink")
        pill.show(.listening)

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let recorder = self.recorder else { return }
                self.pill.push(level: recorder.level)
            }
        }
        limitTask = Task { [weak self] in
            try? await Task.sleep(for: Self.longestRecording)
            guard !Task.isCancelled else { return }
            self?.toggle()
        }
    }

    private func stopAndTranscribe() {
        stopWatching()
        guard let recorder else {
            flow.finished()
            return
        }
        self.recorder = nil
        let samples = recorder.stop()
        log.notice("Recorded \(Double(samples.count) / recorder.sampleRate, format: .fixed(precision: 1)) s at \(Int(recorder.sampleRate)) Hz")
        playSound("Pop")
        transcribe(samples, sampleRate: recorder.sampleRate)
    }

    private func transcribe(_ samples: [Float], sampleRate: Double) {
        pill.show(.working(loading == .ready ? "Writing" : "Getting the speech model ready"))
        let model = Settings.model
        Task {
            do {
                let raw = try await transcriber.transcribe(samples, sampleRate: sampleRate, model: model)
                unsent = nil
                if Settings.model == model { loading = .ready }
                deliver(raw)
            } catch {
                log.error("Transcription failed: \(error.localizedDescription)")
                unsent = (samples, sampleRate)
                flow.finished()
                updateIcon()
                pill.flash("Couldn't turn that into text. Try again from the Murmur menu.", seconds: 5)
            }
        }
    }

    private func deliver(_ raw: String) {
        let text = Tidy.finish(raw, words: Settings.words(), british: Settings.british)
        flow.finished()
        updateIcon()

        log.notice("Wrote \(text.count) characters")
        guard !text.isEmpty else {
            pill.flash("Didn't catch that.", seconds: 1.5)
            return
        }
        var recent = Settings.recent
        recent.add(text)
        Settings.recent = recent

        if Paster.paste(Tidy.forInsertion(text)) {
            log.notice("Pasted")
            pill.hide()
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
        case (.recording, _): "Listening. Double-tap Fn to finish, Esc to cancel."
        case (.transcribing, _): "Writing…"
        case (.idle, .loading(let fraction)) where fraction > 0 && fraction < 1:
            "Getting the speech model ready: \(Int(fraction * 100))%"
        case (.idle, .loading): "Getting the speech model ready…"
        case (.idle, .failed): "Couldn't load the speech model. Check the internet."
        case (.idle, .ready): "Ready. Double-tap Fn to talk."
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if loading == .failed {
            menu.addItem(item("Try loading the speech model again", #selector(retryLoad)))
        }
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
        menu.addItem(item("Edit word list…", #selector(editWordList)))
        menu.addItem(.separator())

        menu.addItem(item("Tidy speech (drops um and er)", #selector(toggleTidy), on: Settings.model == .tidy))
        menu.addItem(item("British spelling", #selector(toggleBritish), on: Settings.british))
        menu.addItem(item("Sounds", #selector(toggleSounds), on: Settings.sounds))
        menu.addItem(item("Open at login", #selector(toggleOpenAtLogin), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())
        menu.addItem(item("Quit Murmur", #selector(quit), key: "q"))
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

    @objc private func editWordList() {
        NSWorkspace.shared.open(
            [Settings.wordListURL],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
            configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func toggleTidy() {
        Settings.model = Settings.model == .tidy ? .exact : .tidy
        loadModel()
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

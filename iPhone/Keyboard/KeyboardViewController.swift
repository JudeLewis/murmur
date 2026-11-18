import MurmurCore
import SwiftUI
import UIKit

/// The Murmur keyboard (SPEC.md 9.2 to 9.4). It can't use the microphone, so
/// it asks the Murmur app to listen and types what comes back.
final class KeyboardViewController: UIInputViewController {
    private lazy var talker = KeyboardTalker(keyboard: self)

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: KeyboardView(talker: talker))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        let height = view.heightAnchor.constraint(equalToConstant: 268)
        height.priority = .defaultHigh + 1
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
        host.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        talker.appeared()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        talker.disappeared()
    }

    /// Keyboards aren't allowed to open apps, but the app object is still in
    /// the responder chain and still answers this message. Wispr Flow's
    /// keyboard relies on the same thing.
    func openMurmur() -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication,
               let method = class_getInstanceMethod(type(of: application), selector) {
                typealias Open = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
                let open = unsafeBitCast(method_getImplementation(method), to: Open.self)
                open(application, selector, KeyboardLink.startURL as NSURL, NSDictionary(), nil)
                return true
            }
            responder = current.next
        }
        return false
    }
}

/// Keeps the keyboard in step with the app, and turns taps into requests.
@MainActor
@Observable
final class KeyboardTalker {
    private(set) var state = KeyboardState.needsApp
    private(set) var note: String?
    private(set) var levels = LevelHistory()
    /// Casual style (SPEC.md 4.7): kept between uses.
    var casual = UserDefaults.standard.bool(forKey: "casual") {
        didSet {
            UserDefaults.standard.set(casual, forKey: "casual")
            show(casual ? "Casual: no capital at the start, no full stop at the end." : "Normal capitals and full stops.")
        }
    }

    @ObservationIgnored private weak var keyboard: KeyboardViewController?
    @ObservationIgnored private var status: PhoneStatus?
    @ObservationIgnored private var wait = KeyboardWait()
    @ObservationIgnored private var lastTyped = LastTyped()
    /// Type as I speak (SPEC.md 9.4): what's been typed for the recording being made, and the
    /// text before the cursor when Talk was tapped.
    @ObservationIgnored private var live = KeyboardLive()
    @ObservationIgnored private var liveBefore: String?
    /// The recording this keyboard started, the only one it types live; nil once it's closed.
    @ObservationIgnored private var liveRecording: Int?
    @ObservationIgnored private var liveStoppedNoted = 0
    /// What was selected when ✨ was tapped, so Undo can put it back.
    @ObservationIgnored private var commandSelection: String?
    @ObservationIgnored private let tapFeel = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private var poll: Timer?
    @ObservationIgnored private var repeatDelete: Timer?
    @ObservationIgnored private var noteTimer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(keyboard: KeyboardViewController) {
        self.keyboard = keyboard
    }

    var showsGlobe: Bool { keyboard?.needsInputModeSwitchKey ?? false }
    /// ✨ for Command Mode (SPEC.md 9.7).
    var showsCommand: Bool { KeyboardLink.showsCommand(in: state, ai: aiOn) }
    private var aiOn = false
    /// The recording being made or written is a Command Mode instruction.
    private(set) var isCommand = false

    func appeared() {
        Bell.listen(for: Bell.toKeyboard)
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: Bell.toKeyboard, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        // Also check every second, to notice when iOS has closed the app.
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func disappeared() {
        poll?.invalidate()
        poll = nil
        stopDeleting()
        // Text finishing after the keyboard has gone isn't typed anywhere (SPEC.md 9.4).
        wait.keyboardClosed()
        liveRecording = nil
    }

    func refresh() {
        let fullAccess = keyboard?.hasFullAccess ?? false
        status = fullAccess ? Shared.store?.status() : nil
        state = KeyboardLink.state(of: status, now: .now, fullAccess: fullAccess)
        // Only set when changed, so the keyboard isn't redrawn every second for nothing.
        if aiOn != (status?.ai ?? false) { aiOn.toggle() }
        if isCommand != (status?.command ?? false) { isCommand.toggle() }
        if state == .listening {
            if let level = status?.level { levels.add(level) }
        } else {
            levels.clear()
        }

        typeLive()

        switch wait.deliver(status?.result) {
        case .type(let text, let pressEnter) where status?.result.map({ live.typedSome(of: $0.id) }) == true:
            // Part of it is typed already: make what's typed match the finished text.
            let proxy = keyboard?.textDocumentProxy
            let target = Tidy.spaceInFront(of: text, after: liveBefore) + Tidy.forInsertion(text, pressEnter: pressEnter)
            if let id = status?.result?.id, let edit = live.show(target, recording: id, before: proxy?.documentContextBeforeInput, final: true) {
                apply(edit)
            }
            if live.stopped {
                show("Typing stopped part way, as the cursor moved. The whole dictation is in Recent in the Murmur app.")
                trace("live typing stopped part way")
            } else {
                if pressEnter { proxy?.insertText("\n") }
                lastTyped.typed(pressEnter ? "" : target)
                trace("typed \(text.count) characters as you spoke\(pressEnter ? ", then Return" : "")")
            }
        case .type where status?.result?.typedLive == true && status?.result?.id != liveRecording:
            // Another keyboard (before it was closed) typed part of it already: typing it all
            // here would double that part.
            show("Part of it was typed as you spoke. The whole dictation is in Recent in the Murmur app.")
            trace("finished text not typed: another keyboard typed part of it")
        case .type(let text, let pressEnter):
            let proxy = keyboard?.textDocumentProxy
            let typed = Tidy.forInsertion(text, after: proxy?.documentContextBeforeInput, pressEnter: pressEnter)
            proxy?.insertText(typed)
            if pressEnter {
                proxy?.insertText("\n")
                lastTyped.typed("")
            } else {
                lastTyped.typed(typed)
            }
            trace("typed \(text.count) characters\(pressEnter ? ", then Return" : "")")
        case .replace(let text):
            // Only over the text that was selected: if the cursor moved meanwhile,
            // the answer would land in the wrong place.
            guard let proxy = keyboard?.textDocumentProxy, proxy.selectedText == commandSelection else {
                show("The selection changed, so the answer wasn't typed. It's in Recent in the Murmur app.")
                trace("answer not typed: the selection changed")
                break
            }
            proxy.insertText(text)
            lastTyped.typed(text, replacing: commandSelection)
            trace("typed \(text.count) characters over the selection")
        case .note(let message):
            show(message)
        case .nothing:
            break
        }
    }

    func talk() {
        refresh()
        switch KeyboardLink.tap(in: state) {
        case .openApp:
            trace("opening the app")
            if keyboard?.openMurmur() != true { show("Open the Murmur app to turn it on.") }
        case .send(let kind):
            tapFeel.impactOccurred()
            // The text before the cursor goes with a start (SPEC.md 4.12), for the capital and names.
            let before = kind == .start ? keyboard?.textDocumentProxy.documentContextBeforeInput : nil
            let request = KeyboardRequest(id: KeyboardRequest.newID(), kind: kind, casual: casual, before: before)
            if kind == .start {
                liveBefore = before
                liveRecording = request.id
            }
            send(request)
        case .nothing:
            break
        }
    }

    /// ✨: listen for an instruction about the selected text (SPEC.md 9.7).
    func command() {
        refresh()
        guard showsCommand else { return }
        tapFeel.impactOccurred()
        let selected = keyboard?.textDocumentProxy.selectedText
        let selection = selected?.isEmpty == false ? selected : nil
        commandSelection = selection
        send(KeyboardRequest(id: KeyboardRequest.newID(), kind: .command, casual: casual, selection: selection))
    }

    /// "again": the last dictation, typed again where the cursor is now (SPEC.md 9.4).
    func typeAgain() {
        tapFeel.impactOccurred()
        guard keyboard?.hasFullAccess == true else {
            show("Murmur needs Full Access: open the Murmur app and follow Setting up.")
            return
        }
        guard let text = Shared.store?.last(), !text.isEmpty, let proxy = keyboard?.textDocumentProxy else {
            show("Nothing to type yet.")
            return
        }
        let typed = Tidy.forInsertion(text, after: proxy.documentContextBeforeInput)
        proxy.insertText(typed)
        lastTyped.typed(typed)
        trace("typed the last dictation again")
    }

    func cancel() {
        tapFeel.impactOccurred()
        send(KeyboardRequest(id: KeyboardRequest.newID(), kind: .cancel))
    }

    /// The "turn mic off" button: ends the session, so the orange dot goes.
    func turnMicOff() {
        tapFeel.impactOccurred()
        send(KeyboardRequest(id: KeyboardRequest.newID(), kind: .turnOff))
        show("Microphone off. Tap the mic to turn Murmur on again.")
    }

    /// Takes the last dictation back out, if the cursor is still straight after it.
    func undo() {
        tapFeel.impactOccurred()
        guard let proxy = keyboard?.textDocumentProxy, let undo = lastTyped.undo(before: proxy.documentContextBeforeInput) else {
            show("Nothing to undo.")
            return
        }
        for _ in 0..<undo.delete { proxy.deleteBackward() }
        if !undo.retype.isEmpty { proxy.insertText(undo.retype) }
        trace(undo.retype.isEmpty ? "undid a dictation" : "undid a command, selected text put back")
    }

    /// Type as I speak (SPEC.md 9.4): the words so far, typed and corrected as the app hears more.
    private func typeLive() {
        // Only the keyboard that started this recording, while it's open (SPEC.md 9.4).
        guard let words = status?.live, words.id == liveRecording, !words.text.isEmpty, let proxy = keyboard?.textDocumentProxy else { return }
        let target = Tidy.spaceInFront(of: words.text, after: liveBefore) + words.text
        if let edit = live.show(target, recording: words.id, before: proxy.documentContextBeforeInput) {
            apply(edit)
        } else if live.stopped, liveStoppedNoted != words.id {
            liveStoppedNoted = words.id
            trace("live typing stopped: the cursor moved")
        }
    }

    private func apply(_ edit: LiveEdit) {
        guard let proxy = keyboard?.textDocumentProxy else { return }
        for _ in 0..<edit.delete { proxy.deleteBackward() }
        if !edit.type.isEmpty { proxy.insertText(edit.type) }
    }

    private func send(_ request: KeyboardRequest) {
        wait.sent(request, recording: status?.recording)
        Shared.store?.save(request)
        Bell.ring(Bell.toApp)
        trace("sent \(request.kind.rawValue)")
    }

    // MARK: The other keys

    func type(_ key: String) {
        tapFeel.impactOccurred()
        keyboard?.textDocumentProxy.insertText(key)
    }

    func space() { type(" ") }
    func newLine() { type("\n") }
    func nextKeyboard() { keyboard?.advanceToNextInputMode() }

    /// Delete once, then again and again while held.
    func startDeleting() {
        guard repeatDelete == nil else { return }
        tapFeel.impactOccurred()
        keyboard?.textDocumentProxy.deleteBackward()
        repeatDelete = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.repeatDelete != nil else { return }
                self.repeatDelete = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.keyboard?.textDocumentProxy.deleteBackward() }
                }
            }
        }
    }

    func stopDeleting() {
        repeatDelete?.invalidate()
        repeatDelete = nil
    }

    private func show(_ message: String) {
        note = message
        noteTimer?.invalidate()
        noteTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.note = nil }
        }
    }

    private func trace(_ event: String) {
        guard keyboard?.hasFullAccess == true else { return }
        Shared.store?.trace(event, from: "keyboard")
    }
}

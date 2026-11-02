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
        let height = view.heightAnchor.constraint(equalToConstant: 250)
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

    @ObservationIgnored private weak var keyboard: KeyboardViewController?
    @ObservationIgnored private var status: PhoneStatus?
    @ObservationIgnored private var wait = KeyboardWait()
    @ObservationIgnored private var poll: Timer?
    @ObservationIgnored private var repeatDelete: Timer?
    @ObservationIgnored private var noteTimer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(keyboard: KeyboardViewController) {
        self.keyboard = keyboard
    }

    var showsGlobe: Bool { keyboard?.needsInputModeSwitchKey ?? false }

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
    }

    func refresh() {
        let fullAccess = keyboard?.hasFullAccess ?? false
        status = fullAccess ? Shared.store?.status() : nil
        state = KeyboardLink.state(of: status, now: .now, fullAccess: fullAccess)

        switch wait.deliver(status?.result) {
        case .type(let text):
            let proxy = keyboard?.textDocumentProxy
            proxy?.insertText(Tidy.forInsertion(text, after: proxy?.documentContextBeforeInput))
            trace("typed \(text.count) characters")
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
            send(KeyboardRequest(id: KeyboardRequest.newID(), kind: kind))
        case .nothing:
            break
        }
    }

    func cancel() {
        send(KeyboardRequest(id: KeyboardRequest.newID(), kind: .cancel))
    }

    private func send(_ request: KeyboardRequest) {
        wait.sent(request, recording: status?.recording)
        Shared.store?.save(request)
        Bell.ring(Bell.toApp)
        trace("sent \(request.kind.rawValue)")
    }

    // MARK: The other keys

    func space() { keyboard?.textDocumentProxy.insertText(" ") }
    func newLine() { keyboard?.textDocumentProxy.insertText("\n") }
    func nextKeyboard() { keyboard?.advanceToNextInputMode() }

    /// Delete once, then again and again while held.
    func startDeleting() {
        guard repeatDelete == nil else { return }
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

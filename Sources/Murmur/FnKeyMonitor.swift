import AppKit
import CoreGraphics
import MurmurCore

/// Watches the keyboard for a double tap of Fn (the globe key), Fn held to
/// talk, and Escape.
///
/// Uses an event tap, which needs Accessibility permission. Every key is passed
/// straight on to the app in front; Murmur only listens.
@MainActor
final class FnKeyMonitor {
    var onDoubleTap: () -> Void = {}
    var onEscape: () -> Void = {}
    var onHoldStarted: () -> Void = {}
    var onCommandHoldStarted: () -> Void = {}
    var onPasteAgain: () -> Void = {}
    var onHoldEnded: () -> Void = {}
    var onHoldCancelled: () -> Void = {}
    var onSingleTap: () -> Void = {}

    var holdToTalk: Bool {
        get { watcher.holdToTalk }
        set { watcher.holdToTalk = newValue }
    }

    var commandMode: Bool {
        get { watcher.commandMode }
        set { watcher.commandMode = newValue }
    }

    private var watcher = FnWatcher()
    private var tap: CFMachPort?

    var isRunning: Bool { tap != nil }

    /// Returns false until Accessibility is allowed.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: fnTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.notice("Keyboard watch not allowed yet (Accessibility: \(AXIsProcessTrusted()))")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        log.notice("Watching the keyboard for Fn")
        return true
    }

    /// Returns true when Murmur used the key itself, so it isn't passed on (Control-Command-V).
    fileprivate func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags, time: TimeInterval) -> Bool {
        let fnHeld = flags.contains(.maskSecondaryFn)
        let event: KeyEvent
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a slow tap off; switch it back on.
            log.notice("macOS switched the keyboard watch off; switching it back on")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .flagsChanged:
            event = .modifiersChanged(keyCode: keyCode, fnHeld: fnHeld, controlHeld: flags.contains(.maskControl))
            log.notice("Modifier key \(keyCode), Fn held: \(fnHeld)")
        case .keyDown:
            if Shortcuts.isPasteAgain(
                keyCode: keyCode, command: flags.contains(.maskCommand), control: flags.contains(.maskControl),
                option: flags.contains(.maskAlternate), shift: flags.contains(.maskShift)) {
                log.notice("Paste again shortcut")
                onPasteAgain()
                return true
            }
            event = .keyDown(keyCode: keyCode)
            // Logged only while Fn is held (Fn's own codes, Fn+arrow), never ordinary typing.
            if fnHeld || FnWatcher.fnKeyCodes.contains(keyCode) { log.notice("Key \(keyCode) pressed with Fn") }
        default:
            return false
        }

        let wasDown = watcher.fnIsDown
        react(to: watcher.handle(event, at: time))
        if watcher.fnIsDown != wasDown {
            // Nothing else happens while Fn is simply held, or after a lone tap, so check
            // back once a hold is long enough, or once a second tap can no longer come.
            let wait = watcher.fnIsDown ? FnWatcher.holdDelay : watcher.tapGap
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(wait + 0.02))
                guard let self else { return }
                self.react(to: self.watcher.tick(at: ProcessInfo.processInfo.systemUptime))
            }
        }
        return false
    }

    private func react(to outcome: FnWatcher.Outcome) {
        switch outcome {
        case .doubleTap:
            log.notice("Double tap")
            onDoubleTap()
        case .escape:
            onEscape()
        case .holdStarted:
            log.notice("Fn held")
            onHoldStarted()
        case .commandHoldStarted:
            log.notice("Fn and Control held: Command Mode")
            onCommandHoldStarted()
        case .holdEnded:
            log.notice("Fn let go")
            onHoldEnded()
        case .holdCancelled:
            log.notice("Fn hold cancelled by another key")
            onHoldCancelled()
        case .singleTap:
            onSingleTap()
        case .nothing:
            break
        }
    }
}

/// The tap's C callback. It runs on the main run loop, where the tap was added.
private func fnTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Murmur's own key presses (Command-V, Command-C, Return) go straight through.
    if event.getIntegerValueField(.eventSourceUserData) == Paster.ownKeyTag { return Unmanaged.passUnretained(event) }
    if let refcon {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        // Not event.timestamp: on Apple silicon it counts clock ticks, not nanoseconds.
        let time = ProcessInfo.processInfo.systemUptime
        let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
        let used = MainActor.assumeIsolated {
            monitor.handle(type: type, keyCode: keyCode, flags: flags, time: time)
        }
        if used { return nil }
    }
    return Unmanaged.passUnretained(event)
}

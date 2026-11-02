import AppKit
import CoreGraphics
import MurmurCore

/// Watches the keyboard for a double tap of Fn (the globe key), and for Escape.
///
/// Uses an event tap, which needs Accessibility permission. Every key is passed
/// straight on to the app in front; Murmur only listens.
@MainActor
final class FnKeyMonitor {
    var onDoubleTap: () -> Void = {}
    var onEscape: () -> Void = {}

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

    fileprivate func handle(type: CGEventType, keyCode: Int64, fnHeld: Bool, time: TimeInterval) {
        let event: KeyEvent
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a slow tap off; switch it back on.
            log.notice("macOS switched the keyboard watch off; switching it back on")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        case .flagsChanged:
            event = .modifiersChanged(keyCode: keyCode, fnHeld: fnHeld)
            log.notice("Modifier key \(keyCode), Fn held: \(fnHeld)")
        case .keyDown:
            event = .keyDown(keyCode: keyCode)
            // Logged only while Fn is held (Fn's own codes, Fn+arrow), never ordinary typing.
            if fnHeld || FnWatcher.fnKeyCodes.contains(keyCode) { log.notice("Key \(keyCode) pressed with Fn") }
        default:
            return
        }

        switch watcher.handle(event, at: time) {
        case .doubleTap:
            log.notice("Double tap")
            onDoubleTap()
        case .escape:
            onEscape()
        case .nothing:
            break
        }
    }
}

/// The tap's C callback. It runs on the main run loop, where the tap was added.
private func fnTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let refcon {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let fnHeld = event.flags.contains(.maskSecondaryFn)
        // Not event.timestamp: on Apple silicon it counts clock ticks, not nanoseconds.
        let time = ProcessInfo.processInfo.systemUptime
        let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
        MainActor.assumeIsolated {
            monitor.handle(type: type, keyCode: keyCode, fnHeld: fnHeld, time: time)
        }
    }
    return Unmanaged.passUnretained(event)
}

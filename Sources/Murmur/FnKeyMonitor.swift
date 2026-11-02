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

    private var detector = DoubleTapDetector()
    private var fnIsDown = false
    private var tap: CFMachPort?

    /// Fn on Mac keyboards; some report the globe key as 179.
    private static let fnKeyCodes: Set<Int64> = [63, 179]
    private static let escapeKeyCode: Int64 = 53

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
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    fileprivate func handle(type: CGEventType, keyCode: Int64, fnHeld: Bool, time: TimeInterval) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a slow tap off; switch it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }

        case .flagsChanged where Self.fnKeyCodes.contains(keyCode):
            if fnHeld, !fnIsDown {
                fnIsDown = true
                detector.keyDown(at: time)
            } else if !fnHeld, fnIsDown {
                fnIsDown = false
                if detector.keyUp(at: time) { onDoubleTap() }
            }

        case .flagsChanged:
            detector.otherKey()  // Shift, Command, Option, Control

        case .keyDown:
            detector.otherKey()
            if keyCode == Self.escapeKeyCode { onEscape() }

        default:
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
        let time = TimeInterval(event.timestamp) / 1_000_000_000
        let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
        MainActor.assumeIsolated {
            monitor.handle(type: type, keyCode: keyCode, fnHeld: fnHeld, time: time)
        }
    }
    return Unmanaged.passUnretained(event)
}

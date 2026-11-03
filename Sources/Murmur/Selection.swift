import AppKit
import ApplicationServices

/// The text selected in the app in front, for Command Mode (SPEC.md 2.7).
@MainActor
enum Selection {
    /// Asks the app through Accessibility first. Apps that don't say (some
    /// browsers and Electron apps) get Command-C instead, with the clipboard
    /// put back straight after.
    static func read() async -> String? {
        await Paster.waitForKeysUp()
        // An app that says "nothing selected" is believed: Command-C there can
        // copy a whole line (some code editors), which would then be rewritten.
        if let text = fromAccessibility() { return text.isEmpty ? nil : text }
        return await byCopying()
    }

    /// The title of an app's window, for spotting webmail (SPEC.md 4.9). Off the
    /// main thread, as a busy browser can take a while to answer.
    nonisolated static func windowTitle(of pid: pid_t) -> String? {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else {
            return nil
        }
        return title as? String
    }

    private static func fromAccessibility() -> String? {
        let system = AXUIElementCreateSystemWide()
        // A busy app mustn't hold up the keyboard for seconds (the key watch shares this thread).
        AXUIElementSetMessagingTimeout(system, 0.25)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        var selected: CFTypeRef?
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success else {
            return nil
        }
        return selected as? String
    }

    /// Some apps take a moment to copy, so this waits up to half a second for
    /// the clipboard to change. The clipboard is only put back if it did.
    private static func byCopying() async -> String? {
        let board = NSPasteboard.general
        let saved = Paster.snapshot()
        let before = board.changeCount
        Paster.pressKey(8, flags: .maskCommand)  // Command-C
        for _ in 0..<20 where board.changeCount == before {
            try? await Task.sleep(for: .milliseconds(25))
        }
        guard board.changeCount != before else { return nil }
        let copied = board.string(forType: .string)
        Paster.restore(saved)
        return copied
    }
}

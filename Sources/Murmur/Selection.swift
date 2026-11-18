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

    /// Up to 300 characters before the cursor in the app in front (SPEC.md 4.12), for the
    /// capital at the start and names. Off the main thread, as a busy app can be slow to
    /// answer; nil when the app doesn't say. Never logged or saved.
    nonisolated static func textBeforeCursor() -> String? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.25)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.25)
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var cursor = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &cursor), cursor.location > 0 else { return cursor.location == 0 ? "" : nil }
        let length = min(300, cursor.location)
        var wanted = CFRange(location: cursor.location - length, length: length)
        guard let wantedValue = AXValueCreate(.cfRange, &wanted) else { return nil }
        var text: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, wantedValue, &text) == .success else { return nil }
        return text as? String
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

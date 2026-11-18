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
    nonisolated static func textBeforeCursor(in pid: pid_t?, limit: Int = 300) -> String? {
        guard let element = focusedElement(in: pid) else { return nil }
        return Field(element: element).textBeforeCursor(limit: limit)
    }

    /// The text box with the cursor in the app, kept to read again later (SPEC.md 4.2).
    nonisolated static func focusedField(in pid: pid_t?) -> Field? {
        focusedElement(in: pid).map(Field.init)
    }


    private static func fromAccessibility() -> String? {
        // A busy app mustn't hold up the keyboard for seconds (the key watch shares this thread):
        // focusedElement waits at most 0.25 seconds per question.
        guard let element = focusedElement(in: NSWorkspace.shared.frontmostApplication?.processIdentifier) else { return nil }
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success else {
            return nil
        }
        return selected as? String
    }

    /// The text box with the cursor in it. The app is asked first: asking the whole system
    /// ("system-wide") failed every time on macOS 27 (error -25204, 18 Nov 2026), in VS Code,
    /// the Claude app and System Settings alike, while asking the app worked.
    nonisolated private static func focusedElement(in pid: pid_t?) -> AXUIElement? {
        let askers = (pid.map { [AXUIElementCreateApplication($0)] } ?? []) + [AXUIElementCreateSystemWide()]
        for asker in askers {
            AXUIElementSetMessagingTimeout(asker, 0.25)
            var focused: CFTypeRef?
            guard AXUIElementCopyAttributeValue(asker, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
                  let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { continue }
            let element = focused as! AXUIElement
            AXUIElementSetMessagingTimeout(element, 0.25)
            return element
        }
        return nil
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

/// One text box in another app, through Accessibility. Its questions wait at most 0.25 seconds.
final class Field: @unchecked Sendable {
    let element: AXUIElement

    init(element: AXUIElement) {
        self.element = element
    }

    /// All its text, if it says and it isn't huge (a long document isn't worth searching).
    func text() -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String, text.utf16.count < 50_000 else { return nil }
        return text
    }

    func textBeforeCursor(limit: Int) -> String? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var cursor = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &cursor), cursor.location > 0 else { return cursor.location == 0 ? "" : nil }
        let length = min(limit, cursor.location)
        var wanted = CFRange(location: cursor.location - length, length: length)
        guard let wantedValue = AXValueCreate(.cfRange, &wanted) else { return nil }
        var text: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, wantedValue, &text) == .success else { return nil }
        return text as? String
    }
}

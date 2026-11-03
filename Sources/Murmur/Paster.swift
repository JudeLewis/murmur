import AppKit
import ApplicationServices

/// Puts text where the cursor is: copies it, presses Command-V for you, then
/// puts back whatever was on the clipboard before.
@MainActor
enum Paster {
    /// Returns false when Murmur isn't allowed to press keys (no Accessibility):
    /// the text is then left on the clipboard for the user to paste.
    static func paste(_ text: String) -> Bool {
        let saved = snapshot()
        guard let ourChange = pasteLeavingClipboard(text) else { return false }
        restore(saved, after: ourChange)
        return true
    }

    /// Pastes without putting the clipboard back: for Type as I speak, which
    /// may paste more than once and puts it back once at the end. Returns the
    /// clipboard's change count, or nil without Accessibility.
    static func pasteLeavingClipboard(_ text: String) -> Int? {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        // Tells clipboard managers (Raycast, Maccy) not to keep this.
        board.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        guard AXIsProcessTrusted() else { return nil }
        pressCommandV()
        return board.changeCount
    }

    /// Gives the app time to read the clipboard, then puts back what was there,
    /// unless something new was copied in the meantime.
    static func restore(_ saved: [NSPasteboardItem], after ourChange: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard NSPasteboard.general.changeCount == ourChange else { return }
            restore(saved)
        }
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// What's on the clipboard now, to put back later with `restore`.
    static func snapshot() -> [NSPasteboardItem] { copyOf(NSPasteboard.general) }

    static func restore(_ items: [NSPasteboardItem]) {
        let board = NSPasteboard.general
        board.clearContents()
        if !items.isEmpty { board.writeObjects(items) }
    }

    /// Marks Murmur's own key presses, so its keyboard watch lets them straight through.
    nonisolated static let ownKeyTag: Int64 = 0x4D75726D  // "Murm"

    static func pressKey(_ key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        for event in [down, up] {
            event?.flags = flags
            event?.setIntegerValueField(.eventSourceUserData, value: ownKeyTag)
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Type as I speak: types text with key presses rather than the clipboard,
    /// a few characters per key press, as macOS allows.
    static func type(_ text: String) {
        // Whole characters per key press, so an emoji or accent is never split in two.
        var chunks: [[UInt16]] = []
        var chunk: [UInt16] = []
        for character in text {
            let units = Array(String(character).utf16)
            if !chunk.isEmpty, chunk.count + units.count > 16 {
                chunks.append(chunk)
                chunk = []
            }
            chunk += units
        }
        if !chunk.isEmpty { chunks.append(chunk) }

        let source = CGEventSource(stateID: .combinedSessionState)
        for chunk in chunks {
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
                event?.flags = []
                chunk.withUnsafeBufferPointer { event?.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress) }
                event?.setIntegerValueField(.eventSourceUserData, value: ownKeyTag)
                event?.post(tap: .cghidEventTap)
            }
        }
    }

    static func deleteBackward(_ count: Int) {
        for _ in 0..<count { pressKey(51, flags: []) }  // Delete
    }

    /// Fn and Delete deletes forwards, so deleting waits while Fn is held.
    static var fnHeld: Bool { CGEventSource.flagsState(.combinedSessionState).contains(.maskSecondaryFn) }

    /// Waits (up to a second) until Control, Command, Option and Fn are let go,
    /// so a key Murmur presses isn't mixed with ones still held down.
    static func waitForKeysUp() async {
        let held: CGEventFlags = [.maskControl, .maskCommand, .maskAlternate, .maskSecondaryFn]
        for _ in 0..<20 where !CGEventSource.flagsState(.combinedSessionState).intersection(held).isEmpty {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func copyOf(_ board: NSPasteboard) -> [NSPasteboardItem] {
        (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    /// For "press enter" at the end of a dictation: Return, a moment after the paste lands.
    static func pressReturn(after delay: Duration = .milliseconds(150)) {
        guard AXIsProcessTrusted() else { return }
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            pressKey(36, flags: [])  // Return
        }
    }

    private static func pressCommandV() {
        pressKey(9, flags: .maskCommand)
    }
}

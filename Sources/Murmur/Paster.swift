import AppKit
import ApplicationServices

/// Puts text where the cursor is: copies it, presses Command-V for you, then
/// puts back whatever was on the clipboard before.
@MainActor
enum Paster {
    /// Returns false when Murmur isn't allowed to press keys (no Accessibility):
    /// the text is then left on the clipboard for the user to paste.
    static func paste(_ text: String) -> Bool {
        let board = NSPasteboard.general
        let saved = copyOf(board)

        board.clearContents()
        board.setString(text, forType: .string)
        // Tells clipboard managers (Raycast, Maccy) not to keep this.
        board.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        guard AXIsProcessTrusted() else { return false }
        pressCommandV()

        // Give the app time to read the clipboard, then restore it, unless
        // something new was copied in the meantime.
        let ourChange = board.changeCount
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard board.changeCount == ourChange else { return }
            board.clearContents()
            if !saved.isEmpty { board.writeObjects(saved) }
        }
        return true
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

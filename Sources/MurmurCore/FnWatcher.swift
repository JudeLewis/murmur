import Foundation

/// One keyboard event, as the app's event tap reports it.
public enum KeyEvent: Equatable, Sendable {
    /// A modifier went down or up (Fn, Shift, Command, Option, Control).
    case modifiersChanged(keyCode: Int64, fnHeld: Bool)
    /// An ordinary key press.
    case keyDown(keyCode: Int64)
}

/// Turns raw keyboard events into "Fn was double-tapped" and "Escape was pressed".
public struct FnWatcher: Sendable {
    public enum Outcome: Equatable, Sendable {
        case nothing
        case doubleTap
        case escape
    }

    /// Fn is 63. On newer Macs the 🌐 key also sends 179, sometimes as an
    /// ordinary key press; that must not count as another key (it did, 2 Nov 2026).
    public static let fnKeyCodes: Set<Int64> = [63, 179]
    public static let escapeKeyCode: Int64 = 53

    private var detector: DoubleTapDetector
    private var fnIsDown = false

    public init(detector: DoubleTapDetector = DoubleTapDetector()) {
        self.detector = detector
    }

    public mutating func handle(_ event: KeyEvent, at time: TimeInterval) -> Outcome {
        switch event {
        case .modifiersChanged(let keyCode, let fnHeld) where Self.fnKeyCodes.contains(keyCode):
            if fnHeld, !fnIsDown {
                fnIsDown = true
                detector.keyDown(at: time)
            } else if !fnHeld, fnIsDown {
                fnIsDown = false
                if detector.keyUp(at: time) { return .doubleTap }
            }
            return .nothing

        case .modifiersChanged:
            detector.otherKey()
            return .nothing

        case .keyDown(let keyCode) where Self.fnKeyCodes.contains(keyCode):
            return .nothing

        case .keyDown(let keyCode):
            detector.otherKey()
            return keyCode == Self.escapeKeyCode ? .escape : .nothing
        }
    }
}

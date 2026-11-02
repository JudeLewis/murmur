import Foundation

/// One keyboard event, as the app's event tap reports it.
public enum KeyEvent: Equatable, Sendable {
    /// A modifier went down or up (Fn, Shift, Command, Option, Control).
    case modifiersChanged(keyCode: Int64, fnHeld: Bool)
    /// An ordinary key press.
    case keyDown(keyCode: Int64)
}

/// Turns raw keyboard events into "Fn was double-tapped", "Fn is being held
/// to talk" and "Escape was pressed".
public struct FnWatcher: Sendable {
    public enum Outcome: Equatable, Sendable {
        case nothing
        case doubleTap
        case escape
        /// Fn has been held on its own for `holdDelay`: start listening.
        case holdStarted
        /// Fn let go after a hold: stop and write.
        case holdEnded
        /// Another key was pressed during a hold (Fn+arrow): throw it away.
        case holdCancelled
    }

    /// How long Fn must be held on its own before a hold starts listening.
    /// Longer than a tap (0.35 seconds), so taps never start a hold.
    public static let holdDelay: TimeInterval = 0.5

    /// Fn is 63. On newer Macs the 🌐 key also sends 179, sometimes as an
    /// ordinary key press; that must not count as another key (it did, 2 Nov 2026).
    public static let fnKeyCodes: Set<Int64> = [63, 179]
    public static let escapeKeyCode: Int64 = 53

    private var detector: DoubleTapDetector
    public private(set) var fnIsDown = false
    /// Hold Fn to talk, from the menu.
    public var holdToTalk = true
    private var pressedAt: TimeInterval?
    private var spoiled = false
    private var holding = false

    public init(detector: DoubleTapDetector = DoubleTapDetector()) {
        self.detector = detector
    }

    /// The app calls this `holdDelay` after Fn goes down, as nothing else would.
    public mutating func tick(at time: TimeInterval) -> Outcome {
        guard holdToTalk, fnIsDown, !spoiled, !holding, let pressedAt, time - pressedAt >= Self.holdDelay else {
            return .nothing
        }
        holding = true
        return .holdStarted
    }

    private mutating func spoil() -> Outcome {
        spoiled = true
        detector.otherKey()
        guard holding else { return .nothing }
        holding = false
        return .holdCancelled
    }

    public mutating func handle(_ event: KeyEvent, at time: TimeInterval) -> Outcome {
        switch event {
        case .modifiersChanged(let keyCode, let fnHeld) where Self.fnKeyCodes.contains(keyCode):
            if fnHeld, !fnIsDown {
                fnIsDown = true
                pressedAt = time
                spoiled = false
                detector.keyDown(at: time)
            } else if !fnHeld, fnIsDown {
                fnIsDown = false
                pressedAt = nil
                let doubleTap = detector.keyUp(at: time)
                if holding {
                    holding = false
                    return .holdEnded
                }
                if doubleTap { return .doubleTap }
            }
            return .nothing

        case .modifiersChanged:
            return spoil()

        case .keyDown(let keyCode) where Self.fnKeyCodes.contains(keyCode):
            return .nothing

        case .keyDown(let keyCode):
            let outcome = spoil()
            // Escape cancels whatever is listening, hold or not.
            return keyCode == Self.escapeKeyCode ? .escape : outcome
        }
    }
}

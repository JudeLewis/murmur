import Foundation

/// Spots a double tap of one key (Fn) from its presses and releases.
///
/// A tap is a quick press and release with no other key in between. Two taps
/// close together make a double tap, reported on the second release.
public struct DoubleTapDetector: Sendable {
    /// Longest a press can be held and still count as a tap, in seconds.
    public var maxHold: TimeInterval
    /// Longest wait from the first release to the second press, in seconds.
    public var maxGap: TimeInterval

    private var pressedAt: TimeInterval?
    private var interrupted = false
    private var lastTapEndedAt: TimeInterval?
    private var lastTapPressedAt: TimeInterval?
    private var doubleTapEndedAt: TimeInterval?

    public init(maxHold: TimeInterval = 0.35, maxGap: TimeInterval = 0.4) {
        self.maxHold = maxHold
        self.maxGap = maxGap
    }

    public mutating func keyDown(at time: TimeInterval) {
        pressedAt = time
        interrupted = false
    }

    /// Returns true when this release completes a double tap.
    public mutating func keyUp(at time: TimeInterval) -> Bool {
        guard let pressed = pressedAt else { return false }
        pressedAt = nil

        guard !interrupted, time - pressed <= maxHold else {
            lastTapEndedAt = nil
            return false
        }
        if let last = lastTapEndedAt, pressed - last <= maxGap {
            lastTapEndedAt = nil
            doubleTapEndedAt = time
            return true
        }
        lastTapEndedAt = time
        lastTapPressedAt = pressed
        return false
    }

    /// A lone tap: one that ended over `maxGap` ago with no second press since.
    /// Reported once (SPEC.md 2.10: a single tap pauses).
    /// A tap straight after a double tap (a bounce, a third tap) isn't one.
    public mutating func singleTap(at time: TimeInterval) -> Bool {
        guard let last = lastTapEndedAt, time - last > maxGap else { return false }
        lastTapEndedAt = nil
        if let double = doubleTapEndedAt, let pressed = lastTapPressedAt, pressed - double <= maxGap { return false }
        return true
    }

    /// Any other key or modifier spoils a tap in progress and the gap between taps,
    /// so Fn used as a modifier (Fn+arrow, Fn+F5) never counts.
    public mutating func otherKey() {
        interrupted = true
        lastTapEndedAt = nil
    }
}

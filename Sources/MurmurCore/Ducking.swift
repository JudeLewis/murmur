/// Turning music down while Murmur listens (Mac): the volume drops to a
/// quarter, and goes back afterwards unless it was changed in the meantime.
public enum Ducking {
    public static let factor: Float = 0.25

    public static func lowered(from volume: Float) -> Float {
        volume * factor
    }

    /// Only put the volume back if nobody moved it while Murmur was listening.
    public static func shouldRestore(current: Float, lowered: Float) -> Bool {
        abs(current - lowered) < 0.02
    }
}

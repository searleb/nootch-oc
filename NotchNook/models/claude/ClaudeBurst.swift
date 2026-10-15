import Foundation

/// The motion of the "Claude is working" mark: eight rays that lengthen and
/// shorten in a wave chasing around the ring while the whole mark turns slowly.
/// Pure maths so the drawing code stays trivial and the motion is testable.
enum ClaudeBurst {
    static let rayCount = 8
    /// The shortest a ray gets, as a fraction of its longest.
    static let minimumLength = 0.35
    /// Seconds for the wave to go once around the ring.
    static let period: TimeInterval = 1.2
    /// Seconds for one slow turn of the whole mark.
    static let turnPeriod: TimeInterval = 8

    /// Each ray's length from `minimumLength` to 1, out of phase with its neighbours.
    static func rayLengths(at time: TimeInterval) -> [Double] {
        (0..<rayCount).map { index in
            let phase = time / period - Double(index) / Double(rayCount)
            let wave = 0.5 + 0.5 * cos(2 * .pi * phase)
            return minimumLength + (1 - minimumLength) * wave
        }
    }

    /// The mark's turn in radians, in 0..<2π.
    static func rotation(at time: TimeInterval) -> Double {
        var turns = (time / turnPeriod).truncatingRemainder(dividingBy: 1)
        if turns < 0 { turns += 1 }
        return 2 * .pi * turns
    }
}

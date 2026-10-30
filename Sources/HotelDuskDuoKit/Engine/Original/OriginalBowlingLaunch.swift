import Foundation

/**
 * Converts the two final bowling drag deltas into the launch velocity used by overlay 11.
 */
public enum OriginalBowlingLaunch {
    public static let minimumForwardDelta: Int32 = -205
    public static let maximumForwardSpeedMagnitude: Int32 = 819

    /**
     * Maps the final forward speed to overlay 11's event result.
     */
    public static func routeResult(for forwardSpeedFixed20_12: Int32) -> Int16 {
        let speed = abs(Int64(forwardSpeedFixed20_12))
        if speed >= 615 { return 2 }
        if speed >= 410 { return 1 }
        return 0
    }

    /**
     * Returns the averaged velocity when the forward delta passes the source launch threshold.
     * Values use the game's 20.12 fixed-point representation.
     */
    public static func velocity(currentDelta: SIMD3<Int32>, previousDelta: SIMD3<Int32>) -> SIMD3<Int32>? {
        var velocity = SIMD3<Int32>(
            average(currentDelta.x, previousDelta.x),
            0,
            average(currentDelta.z, previousDelta.z)
        )
        guard velocity.z < minimumForwardDelta else { return nil }
        velocity.z = max(velocity.z, -maximumForwardSpeedMagnitude)
        return velocity
    }

    private static func average(_ first: Int32, _ second: Int32) -> Int32 {
        Int32(clamping: (Int64(first) + Int64(second)) / 2)
    }
}

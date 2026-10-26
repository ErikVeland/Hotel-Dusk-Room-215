import Foundation

/**
 * Tracks the ten bowling pin rotation states used by overlay 11's score check.
 */
public struct OriginalBowlingPinField: Equatable, Sendable {
    public static let pinCount = 10
    public static let pinSpacing: Float = 0.4
    public static let halfPinRowDepth: Float = 0.3464

    /**
     * Returns the pin centres from overlay 11's initialiser at 0x021FFDFC.
     */
    public static let initialPositions: [SIMD2<Float>] = (0...3).flatMap { row in
        (0...row).map { column in
            SIMD2(
                (Float(column) - Float(row) / 2) * pinSpacing,
                -2.75 - Float(row) * halfPinRowDepth
            )
        }
    }

    public private(set) var rotations: [Int32] = Array(repeating: 0, count: pinCount)

    public init() {}

    /**
     * Returns the number of pins with a non-zero rotation, as counted by 0x021FE9D4.
     */
    public var score: Int32 {
        Int32(rotations.reduce(into: 0) { count, rotation in
            if rotation != 0 { count += 1 }
        })
    }

    /**
     * Stores the rotation state produced by the pin simulation.
     */
    @discardableResult
    public mutating func setRotation(_ rotation: Int32, forPin pin: Int) -> Bool {
        guard rotations.indices.contains(pin) else { return false }
        rotations[pin] = rotation
        return true
    }
}

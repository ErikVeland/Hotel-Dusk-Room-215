import Foundation
import simd

/**
 * Builds the bowling camera basis from the 20.12 vectors stored at process +0x2B4.
 */
public struct OriginalBowlingCameraBasis: Equatable, Sendable {
    public let origin: SIMD3<Float>
    public let right: SIMD3<Float>
    public let up: SIMD3<Float>
    public let forward: SIMD3<Float>

    /**
     * Reads the camera position, target, and two basis hints from the source matrix.
     */
    public init?(matrixFixed20_12 values: [Int32]) {
        guard values.count == 16 else { return nil }
        func vector(at index: Int) -> SIMD3<Float> {
            SIMD3(Float(values[index]), Float(values[index + 1]), Float(values[index + 2])) / 4096
        }

        let origin = vector(at: 0)
        let target = vector(at: 3)
        let rightHint = vector(at: 9)
        let upHint = vector(at: 12)
        let forwardVector = target - origin
        guard simd_length_squared(forwardVector) > 0,
              simd_length_squared(rightHint) > 0,
              simd_length_squared(upHint) > 0 else { return nil }

        let forward = simd_normalize(forwardVector)
        let rightVector = simd_cross(forward, upHint)
        let upVector = simd_cross(forward, rightHint)
        guard simd_length_squared(rightVector) > 0,
              simd_length_squared(upVector) > 0 else { return nil }

        self.origin = origin
        right = simd_normalize(rightVector)
        up = simd_normalize(upVector)
        self.forward = forward
    }
}

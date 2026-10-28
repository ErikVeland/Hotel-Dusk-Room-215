import simd

/**
 * Builds a provisional view matrix from overlay 40's recovered camera parameters.
 */
enum OriginalBrickWallProjection {
    static let width = 192
    static let height = 256
    static let viewProjection = makeViewProjection()

    /**
     * Maps raw DS touch axes to the coordinate order used by overlay 40.
     */
    static func touchViewPoint(fromRawTouch point: SIMD2<Int16>, orientationFlag: Bool) -> SIMD2<Float> {
        if orientationFlag {
            return SIMD2(Float(191 - point.y), Float(point.x))
        }
        return SIMD2(Float(point.y), Float(255 - point.x))
    }

    private static func makeViewProjection() -> simd_float4x4 {
        let eye = SIMD3<Float>(4.5, Float(0x699a) / 4096, Float(0x104cd) / 4096)
        let target = SIMD3<Float>(4.5, Float(0x699a) / 4096, 0)
        let up = SIMD3<Float>(-1, 0, 0)
        let aspect = Float(bitPattern: 0x3faae3da)
        let near: Float = 0.1
        let far: Float = 60
        let yScale = 1 / tan(Float.pi / 9)
        let projection = simd_float4x4(columns: (
            SIMD4(yScale * aspect, 0, 0, 0),
            SIMD4(0, yScale, 0, 0),
            SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, near * far / (near - far), 0)))
        let back = simd_normalize(eye - target)
        let right = simd_normalize(simd_cross(up, back))
        let correctedUp = simd_cross(back, right)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, correctedUp.x, back.x, 0),
            SIMD4(right.y, correctedUp.y, back.y, 0),
            SIMD4(right.z, correctedUp.z, back.z, 0),
            SIMD4(-simd_dot(right, eye), -simd_dot(correctedUp, eye), -simd_dot(back, eye), 1)))
        return projection * view
    }
}

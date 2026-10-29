import simd

/**
 * Projects overlay 40 world coordinates through its recovered stylus-camera mapping.
 */
enum OriginalBrickWallProjection {
    static let width = 192
    static let height = 256

    /**
     * Maps raw DS touch axes to the coordinate order used by overlay 40.
     */
    static func touchViewPoint(fromRawTouch point: SIMD2<Int16>, orientationFlag: Bool) -> SIMD2<Float> {
        if orientationFlag {
            return SIMD2(Float(191 - point.y), Float(point.x))
        }
        return SIMD2(Float(point.y), Float(255 - point.x))
    }

    /**
     * Projects a source-space point into the 192×256 brick view.
     */
    static func screenPoint(_ point: SIMD3<Float>) -> SIMD2<Float>? {
        let eye = SIMD3<Float>(4.5, Float(0x699a) / 4096, Float(0x104cd) / 4096)
        let depth = eye.z - point.z
        guard depth > 0, depth.isFinite else { return nil }
        let aspect = Float(bitPattern: 0x3faa3d71)
        let viewScale = aspect * tan(Float.pi / 9)
        let x = 96 + 128 * (point.x - eye.x) / (depth * viewScale)
        let y = 128 - 128 * (point.y - eye.y) / (depth * viewScale)
        guard x.isFinite, y.isFinite else { return nil }
        return SIMD2(x, y)
    }
}

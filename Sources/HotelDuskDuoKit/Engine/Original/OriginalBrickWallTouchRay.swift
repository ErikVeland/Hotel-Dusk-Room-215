import simd

/**
 * Builds overlay 40's stylus ray from its recovered camera and touch rules.
 */
enum OriginalBrickWallTouchRay {
    struct Ray {
        let origin: SIMD3<Float>
        let direction: SIMD3<Float>
    }

    private static let origin = SIMD3<Float>(4.5, Float(0x699a) / 4096, Float(0x104cd) / 4096)
    private static let viewDirection = SIMD3<Float>(0, 0, -1)
    private static let horizontalAxis = SIMD3<Float>(1, 0, 0)
    private static let verticalAxis = SIMD3<Float>(0, 1, 0)
    private static let tangent = tan(Float.pi / 9)
    private static let aspect = Float(bitPattern: 0x3faa3d71)

    /**
     * Returns the source stylus ray for a point in overlay 40's 192×256 view.
     */
    static func ray(at point: SIMD2<Float>) -> Ray? {
        guard point.x >= 0, point.x < 192, point.y >= 0, point.y < 256,
              point.x.isFinite, point.y.isFinite else { return nil }

        let horizontal = ((point.x - 96) / 128) * aspect * tangent
        let vertical = ((128 - point.y) / 128) * aspect * tangent
        let direction = simd_normalize(viewDirection + horizontalAxis * horizontal + verticalAxis * vertical)
        return Ray(origin: origin, direction: direction)
    }
}

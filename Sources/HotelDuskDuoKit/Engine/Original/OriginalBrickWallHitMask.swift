import Foundation
import simd

/**
 * Approximates overlay 40's brick-face selection with the nearest triangle hit.
 * This native approximation is not source-exact at shared projected edges.
 */
enum OriginalBrickWallHitMask {
    private static let edgeTolerance: Float = 0.016
    private static let depthTolerance: Float = 0.0001

    static let faceVertices: [SIMD3<Float>] = [
        SIMD3(-0.5, -0.5, 0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(-0.5, 0.5, 0.5),
        SIMD3(-0.5, 0.5, 0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(0.5, 0.5, 0.5),
        SIMD3(0.5, -0.5, -0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(0.5, 0.5, -0.5),
        SIMD3(0.5, 0.5, -0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(0.5, 0.5, 0.5)
    ]

    /**
     * Returns the nearest source brick face under a point in overlay coordinates.
     */
    static func object(at point: SIMD2<Float>, objects: [OriginalBrickWallLayout.Object]) -> Int? {
        guard let ray = OriginalBrickWallTouchRay.ray(at: point) else { return nil }
        var nearest: (object: Int, distance: Float)?

        for (objectIndex, object) in objects.enumerated() {
            let vertices = faceVertices.map { object.position + $0 * object.scale }
            for triangle in stride(from: 0, to: vertices.count, by: 3) {
                guard let distance = Self.intersection(
                    ray, vertices[triangle], vertices[triangle + 1], vertices[triangle + 2]) else { continue }
                if nearest == nil || distance < nearest!.distance - depthTolerance ||
                    (abs(distance - nearest!.distance) <= depthTolerance && objectIndex > nearest!.object) {
                    nearest = (objectIndex, distance)
                }
            }
        }
        return nearest?.object
    }

    private static func intersection(_ ray: OriginalBrickWallTouchRay.Ray,
                                     _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float? {
        let edge1 = b - a
        let edge2 = c - a
        let cross = simd_cross(ray.direction, edge2)
        let determinant = simd_dot(edge1, cross)
        guard abs(determinant) > 0.000001 else { return nil }

        let inverse = 1 / determinant
        let offset = ray.origin - a
        let u = simd_dot(offset, cross) * inverse
        guard u >= -edgeTolerance, u <= 1 + edgeTolerance else { return nil }
        let crossOffset = simd_cross(offset, edge1)
        let v = simd_dot(ray.direction, crossOffset) * inverse
        guard v >= -edgeTolerance, u + v <= 1 + edgeTolerance else { return nil }

        let distance = simd_dot(edge2, crossOffset) * inverse
        return distance > 0 ? distance : nil
    }
}

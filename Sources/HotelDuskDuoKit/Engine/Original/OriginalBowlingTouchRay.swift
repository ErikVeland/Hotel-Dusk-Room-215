import Foundation
import simd

/**
 * Builds the normalised touch ray used by overlay 11's bowling hit test.
 */
public enum OriginalBowlingTouchRay {
    public enum TouchOrientation: Sendable {
        case rotated
        case unrotated
    }

    public static let viewportWidth: Float = 192
    public static let viewportHeight: Float = 256
    public static let aspectRatio: Float = 1.33
    public static let projectionAngleDegrees: Float = 30
    private static let planeHalfWidth: Float = 5
    private static let ballPlaneHalfExtent: Float = Float(1229) / 4096

    /**
     * The six lane-plane vertices copied by 0x021FF914 from 0x02204B30.
     */
    public static let lanePlaneVertices: [SIMD3<Float>] = [
        SIMD3(-planeHalfWidth, 0, -planeHalfWidth), SIMD3(planeHalfWidth, 0, -planeHalfWidth),
        SIMD3(-planeHalfWidth, 0, planeHalfWidth), SIMD3(planeHalfWidth, 0, -planeHalfWidth),
        SIMD3(-planeHalfWidth, 0, planeHalfWidth), SIMD3(planeHalfWidth, 0, planeHalfWidth)
    ]

    /**
     * The six ball touch-plane vertices copied by 0x021FF914 from 0x02204B78.
     */
    public static let ballPlaneVertices: [SIMD3<Float>] = [
        SIMD3(-ballPlaneHalfExtent, -ballPlaneHalfExtent, 0), SIMD3(ballPlaneHalfExtent, -ballPlaneHalfExtent, 0),
        SIMD3(-ballPlaneHalfExtent, ballPlaneHalfExtent, 0), SIMD3(ballPlaneHalfExtent, -ballPlaneHalfExtent, 0),
        SIMD3(-ballPlaneHalfExtent, ballPlaneHalfExtent, 0), SIMD3(ballPlaneHalfExtent, ballPlaneHalfExtent, 0)
    ]

    /**
     * Converts the original 256×192 touch coordinates to the portrait page
     * coordinates returned by 0x02009920 and 0x02009960.
     */
    public static func pagePoint(
        touchPoint: SIMD2<Int>,
        orientation: TouchOrientation
    ) -> SIMD2<Float>? {
        guard (0..<256).contains(touchPoint.x), (0..<192).contains(touchPoint.y) else { return nil }
        switch orientation {
        case .rotated:
            return SIMD2(Float(191 - touchPoint.y), Float(touchPoint.x))
        case .unrotated:
            return SIMD2(Float(touchPoint.y), Float(255 - touchPoint.x))
        }
    }

    /**
     * Builds a source-oriented ray directly from the raw DS touch sample.
     */
    public static func direction(
        touchPoint: SIMD2<Int>,
        orientation: TouchOrientation,
        right: SIMD3<Float>,
        up: SIMD3<Float>,
        forward: SIMD3<Float>
    ) -> SIMD3<Float>? {
        guard let pagePoint = pagePoint(touchPoint: touchPoint, orientation: orientation) else { return nil }
        return direction(pagePoint: pagePoint, right: right, up: up, forward: forward)
    }

    /**
     * Builds a ray from the camera basis captured from the current bowling process state.
     */
    public static func ray(
        pagePoint: SIMD2<Float>,
        camera: OriginalBowlingCameraBasis
    ) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)? {
        guard let direction = direction(pagePoint: pagePoint, right: camera.right,
                                        up: camera.up, forward: camera.forward) else { return nil }
        return (camera.origin, direction)
    }

    /**
     * Returns a ray through a page point from the camera basis used by 0x02202D74.
     */
    public static func direction(
        pagePoint: SIMD2<Float>,
        right: SIMD3<Float>,
        up: SIMD3<Float>,
        forward: SIMD3<Float>
    ) -> SIMD3<Float>? {
        guard pagePoint.x.isFinite, pagePoint.y.isFinite,
              pagePoint.x >= 0, pagePoint.x < viewportWidth,
              pagePoint.y >= 0, pagePoint.y < viewportHeight,
              isFinite(right), isFinite(up), isFinite(forward),
              simd_length_squared(right) > 0,
              simd_length_squared(up) > 0,
              simd_length_squared(forward) > 0 else { return nil }

        let tangent = tan(projectionAngleDegrees * .pi / 180)
        let viewportRatio = viewportWidth / viewportHeight
        let horizontal = ((pagePoint.x - viewportWidth / 2) / (viewportWidth / 2)) * viewportRatio * aspectRatio * tangent
        let vertical = ((viewportHeight / 2 - pagePoint.y) / (viewportHeight / 2)) * aspectRatio * tangent
        let direction = simd_normalize(
            simd_normalize(forward) + simd_normalize(right) * horizontal + simd_normalize(up) * vertical
        )
        return isFinite(direction) ? direction : nil
    }

    /**
     * Returns the first forward intersection with two triangles in 0x02202F88 order.
     */
    public static func firstHit(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        vertices: [SIMD3<Float>]
    ) -> SIMD3<Float>? {
        guard vertices.count == 6, isFinite(origin), isFinite(direction),
              simd_length_squared(direction) > 0, vertices.allSatisfy(isFinite) else { return nil }

        for triangle in 0..<2 {
            let base = triangle * 3
            if let distance = intersectionDistance(
                origin: origin, direction: direction,
                first: vertices[base], second: vertices[base + 1], third: vertices[base + 2]) {
                return origin + direction * distance
            }
        }
        return nil
    }

    private static func intersectionDistance(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        first: SIMD3<Float>,
        second: SIMD3<Float>,
        third: SIMD3<Float>
    ) -> Float? {
        let edgeOne = second - first
        let edgeTwo = third - first
        let perpendicular = simd_cross(direction, edgeTwo)
        let determinant = simd_dot(edgeOne, perpendicular)
        guard abs(determinant) > 0.000001 else { return nil }

        let inverseDeterminant = 1 / determinant
        let fromFirst = origin - first
        let firstWeight = simd_dot(fromFirst, perpendicular) * inverseDeterminant
        guard (0...1).contains(firstWeight) else { return nil }

        let across = simd_cross(fromFirst, edgeOne)
        let secondWeight = simd_dot(direction, across) * inverseDeterminant
        guard secondWeight >= 0, firstWeight + secondWeight <= 1 else { return nil }

        let distance = simd_dot(edgeTwo, across) * inverseDeterminant
        return distance >= 0 && distance.isFinite ? distance : nil
    }

    private static func isFinite(_ vector: SIMD3<Float>) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }
}

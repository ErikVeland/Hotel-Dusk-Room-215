import Foundation
import simd

/**
 * Projects overlay 30's cube geometry for depth-ordered input and ground-plane drags.
 */
struct OriginalBagSearchProjection {
    let models: [OriginalModel]
    let nodesByType: [Set<Int>]
    let viewProjection: simd_float4x4

    init(models: [OriginalModel]) throws {
        guard models.count == 1 else { throw OriginalDataError.invalid("Tree-search model set") }
        self.models = models
        nodesByType = [Set([2])]
        viewProjection = Self.projection * Self.view
    }

    /**
     * Returns the front-most object's rendered mesh at a page point.
     */
    func object(at point: SIMD2<Float>, process: OriginalBagSearchProcess) throws -> Int? {
        guard point.x.isFinite, point.y.isFinite, point.x >= 0, point.x < 192,
              point.y >= 0, point.y < 256 else { return nil }
        var nearest: (index: Int, depth: Float)?
        for (index, mask) in try objectMasks(process: process) {
            guard let depth = mask.depth(at: point) else { continue }
            if nearest == nil || depth < nearest!.depth { nearest = (index, depth) }
        }
        return nearest?.index
    }

    func objectMasks(process: OriginalBagSearchProcess) throws -> [(Int, OriginalModelProjectedMask)] {
        var masks = [(Int, OriginalModelProjectedMask)]()
        for (index, object) in process.objects.enumerated() {
            guard object.type != nil else { continue }
            let mask = try OriginalModelProjectedMask(model: models[0],
                viewProjection: viewProjection,
                modelTransform: Self.translation(Self.position(object.positionFixed)) * Self.scale(object.scale),
                width: 192, height: 256, visibleNodes: nodesByType[0])
            masks.append((index, mask))
        }
        return masks
    }

    /**
     * Maps a page point to the source objects' horizontal plane in 20.12 units.
     */
    func planePointFixed(at point: SIMD2<Float>) -> SIMD2<Int32>? {
        guard point.x.isFinite, point.y.isFinite, point.x >= 0, point.x < 192,
              point.y >= 0, point.y < 256 else { return nil }
        let inverse = simd_inverse(viewProjection)
        let near = Self.unproject(point, depth: 0, inverse: inverse)
        let far = Self.unproject(point, depth: 1, inverse: inverse)
        let direction = far - near
        guard direction.y.isFinite, abs(direction.y) > 0.00001 else { return nil }
        let distance = -near.y / direction.y
        guard distance.isFinite, distance >= 0 else { return nil }
        let hit = near + direction * distance
        let x = (hit.x * 4_096).rounded(), z = (hit.z * 4_096).rounded()
        guard x >= Float(Int32.min), x <= Float(Int32.max), z >= Float(Int32.min), z <= Float(Int32.max) else { return nil }
        return SIMD2(Int32(x), Int32(z))
    }

    private static var projection: simd_float4x4 {
        let near: Float = 0.1
        let far: Float = 100
        let focal = 1 / tan(Float.pi / 9)
        let aspect = Float(192) / 256
        return simd_float4x4(columns: (
            SIMD4(focal / aspect, 0, 0, 0),
            SIMD4(0, focal, 0, 0),
            SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, near * far / (near - far), 0)))
    }

    private static var view: simd_float4x4 {
        let eye = SIMD3<Float>(5, 1.5, 7)
        let target = SIMD3<Float>(0, 1, 0)
        let backward = simd_normalize(eye - target)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), backward))
        let up = simd_cross(backward, right)
        return simd_float4x4(columns: (
            SIMD4(right.x, up.x, backward.x, 0),
            SIMD4(right.y, up.y, backward.y, 0),
            SIMD4(right.z, up.z, backward.z, 0),
            SIMD4(-simd_dot(right, eye), -simd_dot(up, eye), -simd_dot(backward, eye), 1)))
    }

    private static func position(_ fixed: SIMD3<Int32>) -> SIMD3<Float> {
        SIMD3(Float(fixed.x), Float(fixed.y), Float(fixed.z)) / 4_096
    }

    private static func translation(_ value: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4(value, 1)
        return matrix
    }

    private static func scale(_ value: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(columns: (SIMD4(value.x, 0, 0, 0), SIMD4(0, value.y, 0, 0),
                                SIMD4(0, 0, value.z, 0), SIMD4(0, 0, 0, 1)))
    }

    private static func unproject(_ point: SIMD2<Float>, depth: Float, inverse: simd_float4x4) -> SIMD3<Float> {
        let clip = SIMD4(point.x / 96 - 1, 1 - point.y / 128, depth, 1)
        let world = inverse * clip
        return SIMD3(world.x, world.y, world.z) / world.w
    }
}

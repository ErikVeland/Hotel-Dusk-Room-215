import CoreGraphics
import Foundation
import Metal
import simd

/**
 * Draws the source search-shed cube at each recovered overlay transform.
 */
@MainActor
final class OriginalSearchShedRenderer {
    private let model: OriginalModelMetalPreview
    private let viewProjection: simd_float4x4

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw OriginalDataError.missing("Metal device")
        }
        let bitmaps = try OriginalBitmapLibrary.bundled()
        model = try OriginalModelMetalPreview(modelPath: "trick/searchshed/soko.mdf",
            models: .bundled(), textures: .bundled(), device: device,
            textureLoader: { name in try bitmaps.loadTexture(path: "trick/searchshed/\(name).bin") })
        viewProjection = Self.projection
    }

    func render(_ process: OriginalSearchShedProcess) throws -> CGImage {
        let instances = process.objects.map { Self.translation($0.position) * Self.scale($0.scale) }
        return try model.render(width: 192, height: 256, viewProjection: viewProjection,
                                visibleNodes: [2], nodeInstances: [2: instances])
    }

    /**
     * Returns the nearest projected box whose recovered hit triangles contain the touch.
     */
    func object(at point: SIMD2<Float>, process: OriginalSearchShedProcess) -> Int? {
        let modelData = model.model
        var closest: (object: Int, distance: Float)?
        for (objectIndex, object) in process.objects.enumerated() {
            let transform = Self.translation(object.position) * Self.scale(object.scale)
            let world = transform * Self.nodeWorld(modelData.nodes[2].worldFixed)
            for group in modelData.groups where group.node == 2 {
                guard let hit = group.hit else { continue }
                for triangle in 0..<hit.triangleCount {
                    let indices = (0..<3).map { Self.index(hit.indexData, triangle * 3 + $0) }
                    let vertices = indices.map { Self.vertex(hit.vertexData, Int($0)) }
                    let projected = vertices.map { Self.project(world * SIMD4($0, 1)) }
                    guard let depth = Self.depth(point, projected[0], projected[1], projected[2]) else { continue }
                    if closest == nil || depth < closest!.distance { closest = (objectIndex, depth) }
                }
            }
        }
        return closest?.object
    }

    /**
     * Maps a screen touch to the horizontal plane of the selected object.
     */
    func planePoint(at point: SIMD2<Float>, height: Float) -> SIMD2<Float>? {
        let inverse = simd_inverse(viewProjection)
        let near = Self.unproject(point, depth: 0, inverse: inverse)
        let far = Self.unproject(point, depth: 1, inverse: inverse)
        let direction = far - near
        guard direction.y.isFinite, abs(direction.y) > 0.00001 else { return nil }
        let amount = (height - near.y) / direction.y
        guard amount.isFinite, amount >= 0 else { return nil }
        let hit = near + direction * amount
        return SIMD2(hit.x, hit.z)
    }

    private static func project(_ world: SIMD4<Float>) -> SIMD3<Float> {
        let clip = projection * world
        guard clip.w > 0 else { return SIMD3(repeating: .infinity) }
        let ndc = SIMD3(clip.x, clip.y, clip.z) / clip.w
        return SIMD3((ndc.x + 1) * 96, (1 - ndc.y) * 128, ndc.z)
    }

    private static func depth(_ point: SIMD2<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float? {
        guard a.x.isFinite, b.x.isFinite, c.x.isFinite else { return nil }
        let v0 = SIMD2(b.x - a.x, b.y - a.y), v1 = SIMD2(c.x - a.x, c.y - a.y)
        let v2 = point - SIMD2(a.x, a.y)
        let denominator = v0.x * v1.y - v1.x * v0.y
        guard abs(denominator) > 0.00001 else { return nil }
        let u = (v2.x * v1.y - v1.x * v2.y) / denominator
        let v = (v0.x * v2.y - v2.x * v0.y) / denominator
        guard u >= 0, v >= 0, u + v <= 1 else { return nil }
        return a.z + u * (b.z - a.z) + v * (c.z - a.z)
    }

    private static func unproject(_ point: SIMD2<Float>, depth: Float, inverse: simd_float4x4) -> SIMD3<Float> {
        let clip = SIMD4(point.x / 96 - 1, 1 - point.y / 128, depth, 1)
        let world = inverse * clip
        return SIMD3(world.x, world.y, world.z) / world.w
    }

    private static func vertex(_ data: Data, _ index: Int) -> SIMD3<Float> {
        let offset = index * 12
        func component(_ component: Int) -> Float {
            let position = offset + component * 2
            let value = Int16(bitPattern: UInt16(data[position]) | UInt16(data[position + 1]) << 8)
            return Float(value) / 4096
        }
        return SIMD3(component(0), component(1), component(2))
    }

    private static func index(_ data: Data, _ index: Int) -> UInt32 {
        let offset = index * 4
        return UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 |
            UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private static func nodeWorld(_ values: [Int32]) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4(Float(values[0]) / 4096, Float(values[1]) / 4096, Float(values[2]) / 4096, Float(values[3]) / 4096),
            SIMD4(Float(values[4]) / 4096, Float(values[5]) / 4096, Float(values[6]) / 4096, Float(values[7]) / 4096),
            SIMD4(Float(values[8]) / 4096, Float(values[9]) / 4096, Float(values[10]) / 4096, Float(values[11]) / 4096),
            SIMD4(Float(values[12]) / 4096, Float(values[13]) / 4096, Float(values[14]) / 4096, Float(values[15]) / 4096)))
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

    private static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let z = simd_normalize(eye - target)
        let x = simd_normalize(simd_cross(up, z))
        let y = simd_cross(z, x)
        return simd_float4x4(columns: (
            SIMD4(x.x, y.x, z.x, 0), SIMD4(x.y, y.y, z.y, 0),
            SIMD4(x.z, y.z, z.z, 0), SIMD4(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1)))
    }

    private static var projection: simd_float4x4 {
        let near: Float = 0.1, far: Float = 100, y = 1 / tan(Float.pi / 9)
        let perspective = simd_float4x4(columns: (
            SIMD4(y / (Float(192) / 256), 0, 0, 0), SIMD4(0, y, 0, 0),
            SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, near * far / (near - far), 0)))
        return perspective * lookAt(eye: SIMD3(5, 1.5, 7), target: SIMD3(0, 1, 0), up: SIMD3(0, 1, 0))
    }
}

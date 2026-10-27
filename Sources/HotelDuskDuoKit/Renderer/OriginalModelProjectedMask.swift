import Foundation
import simd

/**
 * Builds a screen-space hit mask from the triangles used to render an MDF model.
 */
public struct OriginalModelProjectedMask: Sendable {
    private struct Triangle: Sendable {
        let points: [SIMD2<Float>]
        let depths: SIMD3<Float>
    }

    public let width: Int
    public let height: Int
    public let triangleCount: Int
    public let bounds: CGRect
    private let triangles: [Triangle]

    /**
     * Projects visible model geometry through the supplied transforms.
     */
    public init(model: OriginalModel, viewProjection: simd_float4x4,
                modelTransform: simd_float4x4 = matrix_identity_float4x4,
                width: Int, height: Int, visibleNodes: Set<Int>? = nil) throws {
        guard width > 0, height > 0 else { throw OriginalDataError.invalid("Mask dimensions") }
        self.width = width
        self.height = height
        var projected = [Triangle]()
        var minimumX = Float(width), minimumY = Float(height)
        var maximumX: Float = 0, maximumY: Float = 0

        for group in model.groups where visibleNodes?.contains(group.node) ?? true {
            guard let geometry = group.render else { continue }
            let node = model.nodes[group.node]
            let nodeTransform = Self.matrix(node.worldFixed)
            let transform = viewProjection * modelTransform * nodeTransform
            let reader = OriginalBytes(geometry.vertexData)
            let indexReader = OriginalBytes(geometry.indexData)
            var vertices = [SIMD3<Float>?](repeating: nil, count: geometry.vertexCount)
            for index in vertices.indices {
                let offset = index * 12
                let position = SIMD4<Float>(
                    Float(Int16(bitPattern: try reader.u16(offset))) / 4096,
                    Float(Int16(bitPattern: try reader.u16(offset + 2))) / 4096,
                    Float(Int16(bitPattern: try reader.u16(offset + 4))) / 4096,
                    1)
                let clip = transform * position
                guard clip.w > 0.0001 else { continue }
                let ndc = SIMD3(clip.x, clip.y, clip.z) / clip.w
                let point = SIMD2((ndc.x + 1) * Float(width) * 0.5,
                                  (1 - ndc.y) * Float(height) * 0.5)
                guard point.x.isFinite, point.y.isFinite, ndc.z.isFinite else { continue }
                vertices[index] = SIMD3(point.x, point.y, ndc.z)
                minimumX = min(minimumX, point.x)
                minimumY = min(minimumY, point.y)
                maximumX = max(maximumX, point.x)
                maximumY = max(maximumY, point.y)
            }

            for offset in stride(from: 0, to: geometry.triangleCount * 3, by: 3) {
                let indices = try (0..<3).map { Int(try indexReader.u32((offset + $0) * 4)) }
                guard indices.allSatisfy(vertices.indices.contains),
                      let a = vertices[indices[0]], let b = vertices[indices[1]],
                      let c = vertices[indices[2]] else { continue }
                let points = [SIMD2(a.x, a.y), SIMD2(b.x, b.y), SIMD2(c.x, c.y)]
                let area = Self.cross(points[1] - points[0], points[2] - points[0])
                guard abs(area) > 0.0001 else { continue }
                projected.append(Triangle(points: points, depths: SIMD3(a.z, b.z, c.z)))
            }
        }

        triangles = projected
        triangleCount = projected.count
        let clippedMinimumX = min(Float(width), max(0, minimumX))
        let clippedMinimumY = min(Float(height), max(0, minimumY))
        let clippedMaximumX = min(Float(width), max(0, maximumX))
        let clippedMaximumY = min(Float(height), max(0, maximumY))
        bounds = projected.isEmpty ? .null : CGRect(
            x: CGFloat(clippedMinimumX), y: CGFloat(clippedMinimumY),
            width: CGFloat(max(0, clippedMaximumX - clippedMinimumX)),
            height: CGFloat(max(0, clippedMaximumY - clippedMinimumY)))
    }

    /**
     * Returns the nearest rendered depth at a screen point, with optional edge padding.
     */
    public func depth(at point: SIMD2<Float>, padding: Float = 0) -> Float? {
        guard point.x.isFinite, point.y.isFinite, padding.isFinite, padding >= 0,
              point.x >= 0, point.x < Float(width), point.y >= 0, point.y < Float(height) else { return nil }
        var nearest: Float?
        for triangle in triangles {
            let a = triangle.points[0], b = triangle.points[1], c = triangle.points[2]
            let area = Self.cross(b - a, c - a)
            let w0 = Self.cross(b - point, c - point) / area
            let w1 = Self.cross(c - point, a - point) / area
            let w2 = 1 - w0 - w1
            let areaMagnitude = abs(area)
            let tolerances = SIMD3(
                padding * simd_length(c - b) / areaMagnitude,
                padding * simd_length(a - c) / areaMagnitude,
                padding * simd_length(b - a) / areaMagnitude)
            guard w0 >= -tolerances.x, w1 >= -tolerances.y, w2 >= -tolerances.z else { continue }
            let depth = simd_dot(SIMD3(w0, w1, w2), triangle.depths)
            nearest = min(nearest ?? depth, depth)
        }
        return nearest
    }

    /**
     * Returns true when a point touches the projected model silhouette.
     */
    public func contains(_ point: SIMD2<Float>, padding: Float = 0) -> Bool {
        depth(at: point, padding: padding) != nil
    }

    private static func matrix(_ fixed: [Int32]) -> simd_float4x4 {
        let values = fixed.map { Float($0) / 4096 }
        return simd_float4x4(columns: (
            SIMD4(values[0], values[1], values[2], values[3]),
            SIMD4(values[4], values[5], values[6], values[7]),
            SIMD4(values[8], values[9], values[10], values[11]),
            SIMD4(values[12], values[13], values[14], values[15])))
    }

    private static func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        a.x * b.y - a.y * b.x
    }
}

import Foundation
import simd

/**
 * Overlay 12 touch ray (0x02203B08) and horizontal hit rectangles (0x02203CF8).
 * The segment uses fixed-point rounding. Trigonometry still uses a native approximation.
 */
public enum OriginalSuitcaseProjection {
    public static func hit(page: SIMD2<Float>, eye: SIMD3<Int32>, target: SIMD3<Int32>,
                           centre: SIMD3<Int32>, radius: Int32) -> SIMD3<Int32>? {
        guard (1...40960).contains(radius), page.x.isFinite, page.y.isFinite,
              (0...191).contains(page.x), (0...255).contains(page.y) else { return nil }
        let forward = target &- eye
        let right = normalise(cross(forward, SIMD3(0, 4096, 0)))
        let up = normalise(cross(forward, SIMD3(-4096, 0, 0)))
        let tangent: Float = Float(divide(2048, 3547))
        let horizontal = Int32(((page.x - 96) / 128 * 1.33) * tangent)
        let vertical = Int32(((128 - min(223, max(31, page.y))) / 128 * 1.33) * tangent)
        let direction = normalise(normalise(forward) &+ scale(right, horizontal) &+ scale(up, vertical))
        let end = eye &+ direction &* SIMD3<Int32>(repeating: 1000)
        let line = eye &- end
        // 0x01FF8218 forms the triangle plane without normalising its cross product.
        let edge = radius * 2
        let normalY = -Int32((Int64(edge) * Int64(edge) + 2048) >> 12)
        let denominator = (Int64(normalY) * Int64(line.y) + 2048) >> 12
        guard denominator != 0 else { return nil }
        let plane = -((Int64(normalY) * Int64(centre.y) + 2048) >> 12)
        let numerator = plane + ((Int64(normalY) * Int64(end.y) + 2048) >> 12)
        let fraction = -divide(numerator, denominator)
        guard (0...4096).contains(fraction) else { return nil }
        let point = end &+ scale(line, Int32(fraction))
        guard abs(point.x - centre.x) <= radius, abs(point.z - centre.z) <= radius else { return nil }
        return point
    }

    public static func viewProjection(eye: SIMD3<Int32>, target: SIMD3<Int32>) -> simd_float4x4 {
        let position = SIMD3<Float>(eye) / 4096
        let back = simd_normalize(position - SIMD3<Float>(target) / 4096)
        // The DS camera uses negative X as up, then the book rotates its framebuffer.
        let up = simd_normalize(simd_cross(SIMD3<Float>(-1, 0, 0), back))
        let right = simd_cross(up, back)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, back.x, 0), SIMD4(right.y, up.y, back.y, 0),
            SIMD4(right.z, up.z, back.z, 0), SIMD4(-simd_dot(right, position), -simd_dot(up, position), -simd_dot(back, position), 1)))
        let sx: Float = 1 / tan(.pi / 6), sy = sx / 1.3350785
        let near: Float = 0.1, far: Float = 60
        return simd_float4x4(columns: (
            SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0), SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, near * far / (near - far), 0))) * view
    }

    private static func divide(_ a: Int64, _ b: Int64) -> Int64 {
        ((a << 32) / b + 0x80000) >> 20
    }

    private static func scale(_ value: SIMD3<Int32>, _ amount: Int32) -> SIMD3<Int32> {
        SIMD3((0..<3).map { Int32((Int64(value[$0]) * Int64(amount) + 2048) >> 12) })
    }

    private static func cross(_ a: SIMD3<Int32>, _ b: SIMD3<Int32>) -> SIMD3<Int32> {
        SIMD3((0..<3).map { axis in
            let j = (axis + 1) % 3, k = (axis + 2) % 3
            return Int32((Int64(a[j]) * Int64(b[k]) - Int64(a[k]) * Int64(b[j]) + 2048) >> 12)
        })
    }

    private static func normalise(_ value: SIMD3<Int32>) -> SIMD3<Int32> {
        let square = (0..<3).reduce(Int64(0)) { $0 + Int64(value[$1]) * Int64(value[$1]) }
        guard square > 0 else { return .zero }
        let factor = Int64(Double(square * 4).squareRoot()) * ((1 << 56) / square)
        return SIMD3((0..<3).map { Int32((((factor * Int64(value[$0])) >> 32) + 4096) >> 13) })
    }
}

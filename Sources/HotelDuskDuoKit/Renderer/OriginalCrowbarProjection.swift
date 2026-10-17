import Foundation

/**
 * Overlay 5 fixed-point ray and translated crowbar handle rectangles.
 */
public enum OriginalCrowbarProjection {
    public static let eye = SIMD3<Int32>(-42, 7332, -2608)
    public static let target = SIMD3<Int32>(0, -294, -2621)

    public static func touch(page: SIMD2<Float>, process: OriginalCrowbarProcess) -> OriginalCrowbarProcess.Touch? {
        guard page.x.isFinite, page.y.isFinite, (0...191).contains(page.x),
              (0...255).contains(page.y) else { return nil }
        let forward = target &- eye
        let right = normalise(cross(forward, SIMD3(0, 0, -4096)))
        let up = normalise(cross(forward, SIMD3(-4096, 4096, 0)))
        let tangent = Float(divide(2046, 3548))
        let horizontal = Int32(((Float(0.75) * (page.x - 96)) / 96 * Float(1.33)) * tangent)
        let vertical = Int32(((128 - page.y) / 128 * Float(1.33)) * tangent)
        let direction = normalise(normalise(forward) &+ scale(right, horizontal) &+ scale(up, vertical))
        let end = eye &+ direction &* SIMD3<Int32>(repeating: 1000)
        let plane = intersect(end: end, centre: SIMD3(0, 532, 0),
            minimum: SIMD2(-20480, -20480), maximum: SIMD2(20480, 20480))
        let minimum = process.placed ? SIMD2<Int32>(-1638, -1638) : SIMD2(-2048, -6554)
        let maximum = process.placed ? SIMD2<Int32>(1638, 1638) : SIMD2(2048, 1638)
        let hit = intersect(end: end, centre: process.handle, minimum: minimum, maximum: maximum)
        return .init(handle: hit, plane: plane)
    }

    private static func intersect(end: SIMD3<Int32>, centre: SIMD3<Int32>,
                                  minimum: SIMD2<Int32>, maximum: SIMD2<Int32>) -> SIMD3<Int32>? {
        let a = centre &+ SIMD3(minimum.x, 0, minimum.y)
        let b = centre &+ SIMD3(maximum.x, 0, minimum.y)
        let c = centre &+ SIMD3(minimum.x, 0, maximum.y)
        let d = centre &+ SIMD3(maximum.x, 0, maximum.y)
        return triangle(a, b, c, end: end) ?? triangle(b, c, d, end: end)
    }

    /**
     * 0x01FF82DC checks normalised edge-cross products in three dimensions after fixed-point interpolation.
     */
    private static func triangle(_ a: SIMD3<Int32>, _ b: SIMD3<Int32>, _ c: SIMD3<Int32>,
                                 end: SIMD3<Int32>) -> SIMD3<Int32>? {
        let line = eye &- end, normal = cross(b &- a, c &- a)
        let denominator = dot(normal, line)
        guard denominator != 0 else { return nil }
        let fraction = -divide(dot(normal, end) - dot(normal, a), denominator)
        guard (0...4096).contains(fraction) else { return nil }
        let point = end &+ scale(line, Int32(fraction))
        let vectors = [a &- point, b &- point, c &- point]
        if vectors.contains(.zero) { return point }
        let unit = vectors.map(normalise)
        let edges = (0..<3).map { cross(unit[$0], unit[($0 + 1) % 3]) }
        for i in 0..<3 where edges[i] == .zero {
            let start = [a, b, c][i], finish = [a, b, c][(i + 1) % 3]
            return (0..<3).allSatisfy { (min(start[$0], finish[$0])...max(start[$0], finish[$0])).contains(point[$0]) } ? point : nil
        }
        let normals = edges.map(normalise)
        guard (0..<3).allSatisfy({ dot(normals[$0], normals[($0 + 1) % 3]) >= 0 }) else { return nil }
        return point
    }

    private static func dot(_ a: SIMD3<Int32>, _ b: SIMD3<Int32>) -> Int64 {
        ((0..<3).reduce(Int64(0)) { $0 + Int64(a[$1]) * Int64(b[$1]) } + 2048) >> 12
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

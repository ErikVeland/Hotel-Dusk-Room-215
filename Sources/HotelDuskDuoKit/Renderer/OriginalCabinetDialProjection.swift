import Foundation

/**
 * Overlay 10 fixed-point ray and translated wheel rectangles.
 */
public enum OriginalCabinetDialProjection {
    public static let eye = SIMD3<Int32>(0, 0, 204800)

    public static func touch(page: SIMD2<Float>, process: OriginalCabinetDialProcess) -> OriginalCabinetDialProcess.Touch? {
        guard page.x.isFinite, page.y.isFinite, (0...191).contains(page.x),
              (0...255).contains(page.y) else { return nil }
        let y = min(223, max(31, page.y))
        let tangent = Float(divide(138, 4094))
        let horizontal = Int32(((Float(0.75) * (page.x - 96)) / 96 * Float(1.33)) * tangent)
        let vertical = Int32(((128 - y) / 128 * Float(1.33)) * tangent)
        let direction = normalise(SIMD3(horizontal, vertical, -4096))
        let end = eye &+ direction &* SIMD3<Int32>(repeating: 1000)
        let hits = (0..<3).map { index in
            intersect(end: end, centre: SIMD3(process.wheelCentres[index], process.wheelY[index], 4751),
                halfSize: SIMD2(2007, 2048))
        }
        let plane = intersect(end: end,
            centre: SIMD3(process.wheelCentres[process.selected], process.wheelY[process.selected], 4751),
            halfSize: SIMD2(20480, 20480))
        return .init(hits: hits, plane: plane)
    }

    private static func intersect(end: SIMD3<Int32>, centre: SIMD3<Int32>, halfSize: SIMD2<Int32>) -> SIMD3<Int32>? {
        let a = centre &+ SIMD3(-halfSize.x, -halfSize.y, 0)
        let b = centre &+ SIMD3(halfSize.x, -halfSize.y, 0)
        let c = centre &+ SIMD3(-halfSize.x, halfSize.y, 0)
        let d = centre &+ SIMD3(halfSize.x, halfSize.y, 0)
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
